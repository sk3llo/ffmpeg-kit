/*
 * Tests libffmpegkit's callback thread, the thread that hands log lines and
 * statistics to the registered callbacks. It loads the library at run time, as
 * the Flutter plugin does, and checks that:
 *
 *  - log lines reach the log callback at once: the median delay over LINES lines
 *    must stay under MAX_MEDIAN_MS. A thread that misses its wake-ups delivers
 *    them only on its 100 ms poll, up to 100 ms late;
 *  - on Linux, the process exits cleanly with log lines still queued: the
 *    library's exit work must take under MAX_EXIT_MS, and the process then stays
 *    alive for HOLD_MS, so a callback thread that outlives the library's static
 *    objects crashes it.
 *
 * Linux:
 *   clang -O2 -I<bundle>/include callback_thread_test.c -L<bundle>/lib -lavutil -ldl -o callback_thread_test
 *   LD_LIBRARY_PATH=<bundle>/lib ./callback_thread_test <bundle>/lib/libffmpegkit.so
 * Windows, in an MSYS2 UCRT64 shell, from the bundle's folder. The .exe stays out of
 * bin, which is what gets zipped; run from bin, it finds the DLLs there:
 *   gcc -O2 -Iinclude <this file> bin/avutil-*.dll -o /tmp/callback_thread_test.exe
 *   cd bin && /tmp/callback_thread_test.exe libffmpegkit.dll
 *
 * Exits 0 when every check passes.
 */
#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include <stdio.h>
#include <stdlib.h>

#include <libavutil/log.h>

#include "ffmpegkit_c_api.h"

#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#include <time.h>
#include <unistd.h>
#endif

#define LINES 20
#define LINE_GAP_MS 10
#define QUEUED_LINES 200
#define HOLD_MS 300
#ifndef MAX_MEDIAN_MS
#define MAX_MEDIAN_MS 20.0
#endif
#ifndef MAX_EXIT_MS
#define MAX_EXIT_MS 50.0
#endif

typedef void (*enable_log_callback_fn)(ffmpegkit_log_callback_t callback);

static double sent[LINES];
static volatile double received[LINES];

static double now_ms(void) {
#ifdef _WIN32
    LARGE_INTEGER count, frequency;
    QueryPerformanceCounter(&count);
    QueryPerformanceFrequency(&frequency);
    return count.QuadPart * 1000.0 / frequency.QuadPart;
#else
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
#endif
}

static void sleep_ms(int ms) {
#ifdef _WIN32
    Sleep(ms);
#else
    const struct timespec t = {ms / 1000, (ms % 1000) * 1000000L};
    nanosleep(&t, NULL);
#endif
}

static void on_log(long session_id, int level, const char *message) {
    int i;
    (void)session_id;
    (void)level;
    if (sscanf(message, "callback test %d", &i) == 1 && i >= 0 && i < LINES && received[i] == 0) {
        received[i] = now_ms();
    }
}

static int compare_doubles(const void *a, const void *b) {
    const double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

#ifndef _WIN32
static int checks_passed;
static double main_returned_ms;

/* Registered before the library is loaded, so exit() runs it after the
 * library's own exit handlers and static destructors. */
static void after_library_exit(void) {
    if (!checks_passed) {
        return;
    }
    const double exit_ms = now_ms() - main_returned_ms;
    if (exit_ms > MAX_EXIT_MS) {
        printf("FAIL: the library's exit work took %.1f ms, over %.0f ms\n", exit_ms, (double)MAX_EXIT_MS);
        fflush(stdout);
        _exit(1);
    }
    sleep_ms(HOLD_MS);
    printf("exit: the library's exit work took %.2f ms, and nothing crashed in the %d ms after it\n", exit_ms, HOLD_MS);
}
#endif

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <path to libffmpegkit>\n", argv[0]);
        return 2;
    }

    enable_log_callback_fn enable_log_callback = NULL;
#ifdef _WIN32
    HMODULE library = LoadLibraryA(argv[1]);
    if (library != NULL) {
        enable_log_callback =
            (enable_log_callback_fn)(void (*)(void))GetProcAddress(library, "ffmpegkit_enable_log_callback");
    }
#else
    atexit(after_library_exit);
    void *library = dlopen(argv[1], RTLD_NOW);
    if (library != NULL) {
        *(void **)&enable_log_callback = dlsym(library, "ffmpegkit_enable_log_callback");
    }
#endif
    if (enable_log_callback == NULL) {
        printf("FAIL: can't load ffmpegkit_enable_log_callback from %s\n", argv[1]);
        return 1;
    }

    enable_log_callback(on_log);
    av_log_set_level(AV_LOG_INFO);
    for (int i = 0; i < LINES; i++) {
        sent[i] = now_ms();
        av_log(NULL, AV_LOG_INFO, "callback test %d\n", i);
        sleep_ms(LINE_GAP_MS);
    }
    // Longer than the thread's 100 ms poll, so every line has arrived even if it polls.
    sleep_ms(200);

    double delay[LINES];
    int count = 0;
    for (int i = 0; i < LINES; i++) {
        if (received[i] > 0) {
            delay[count++] = received[i] - sent[i];
        }
    }
    if (count < LINES) {
        printf("FAIL: %d of %d log lines reached the log callback\n", count, LINES);
        return 1;
    }
    qsort(delay, LINES, sizeof delay[0], compare_doubles);
    printf("log callback: median delay %.2f ms, longest %.2f ms\n", delay[LINES / 2], delay[LINES - 1]);
    if (delay[LINES / 2] > MAX_MEDIAN_MS) {
        printf("FAIL: the median delay is over %.0f ms\n", (double)MAX_MEDIAN_MS);
        return 1;
    }

    for (int i = 0; i < QUEUED_LINES; i++) {
        av_log(NULL, AV_LOG_INFO, "queued at exit %d\n", i);
    }
#ifndef _WIN32
    checks_passed = 1;
    main_returned_ms = now_ms();
#endif
    return 0;
}
