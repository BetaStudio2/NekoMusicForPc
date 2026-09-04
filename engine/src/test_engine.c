/**
 * test_engine.c — 引擎自检 CLI。
 *
 * 用法：
 *   neko_engine_test --check                 静默自检（供 ctest）
 *   neko_engine_test --verbose <file/url>    打印事件与 ao 后端
 *
 * 生成测试音频：ffmpeg -f lavfi -i "sine=frequency=440:duration=3" -c:a pcm_s16le tone.wav
 */

#include "neko_engine.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int g_verbose = 0;
static int g_fail = 0;
static int g_playing_seen = 0;
static int g_end_seen = 0;
static int g_pos_advanced = 0;
static int g_ao_printed = 0;
static double g_last_pos = -1;

static void sleep_ms(long ms)
{
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

static void drain_events(neko_engine *e, int ms)
{
    long waited = 0;
    while (waited < ms) {
        neko_event ev;
        while (neko_poll_event(e, &ev)) {
            switch (ev.type) {
            case NEKO_EV_STATE:
                if (g_verbose)
                    printf("[ev] state=%d\n", (int)ev.f64);
                if ((int)ev.f64 == NEKO_STATE_PLAYING) {
                    g_playing_seen = 1;
                    if (!g_ao_printed) {
                        char ao[64];
                        neko_get_audio_output(e, ao, sizeof(ao));
                        printf("[main] ACTIVE ao=%s (during playback)\n", ao);
                        g_ao_printed = 1;
                    }
                }
                break;
            case NEKO_EV_POSITION:
                if (g_verbose && (long)(ev.f64 * 10) % 5 == 0)
                    printf("[ev] pos=%.2fs\n", ev.f64);
                if (ev.f64 > 0.5)
                    g_pos_advanced = 1;
                if (g_last_pos >= 0 && ev.f64 > g_last_pos + 0.3)
                    g_pos_advanced = 1;
                g_last_pos = ev.f64;
                break;
            case NEKO_EV_DURATION:
                if (g_verbose)
                    printf("[ev] duration=%.2fs\n", ev.f64);
                break;
            case NEKO_EV_AUDIO_META:
                if (g_verbose)
                    printf("[ev] bitrate=%lld\n", (long long)ev.i64);
                break;
            case NEKO_EV_TITLE:
                if (g_verbose)
                    printf("[ev] title=%s\n", ev.str);
                break;
            case NEKO_EV_READY:
                if (g_verbose)
                    printf("[ev] ready\n");
                break;
            case NEKO_EV_END_FILE:
                if (g_verbose)
                    printf("[ev] end_file reason=%lld\n", (long long)ev.i64);
                g_end_seen = 1;
                break;
            case NEKO_EV_ERROR:
                printf("[ev] ERROR: %s\n", ev.str);
                g_fail = 1;
                break;
            default:
                break;
            }
        }
        sleep_ms(20);
        waited += 20;
    }
}

int main(int argc, char **argv)
{
    const char *media = NULL;
    const char *ao_override = NULL;
    int verbose = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--verbose") == 0)
            verbose = 1;
        else if (strcmp(argv[i], "--check") == 0)
            verbose = 0;
        else if (strncmp(argv[i], "--ao=", 5) == 0)
            ao_override = argv[i] + 5;
        else
            media = argv[i];
    }
    g_verbose = verbose;

    neko_engine *e = neko_create();
    if (!e) {
        printf("FAIL: neko_create\n");
        return 1;
    }
    if (ao_override)
        neko_set_option(e, "ao", ao_override);
    if (neko_initialize(e, verbose) != 0) {
        printf("FAIL: neko_initialize\n");
        return 1;
    }

    /* 播放媒体（默认 5s，播放到 EOF 以覆盖 END_FILE 路径） */
    const char *url = media ? media : "tone.wav";
    if (verbose)
        printf("[main] loading %s\n", url);
    if (neko_load(e, url) != 0) {
        printf("FAIL: neko_load\n");
        return 1;
    }
    neko_play(e);
    neko_set_volume(e, 0.6);

    drain_events(e, media ? 5000 : 6000);

    char ao[64];
    neko_get_audio_output(e, ao, sizeof(ao));
    int64_t br = neko_get_audio_bitrate(e);
    printf("ao backend: %s  | bitrate: %lld bps  | state: %d  | dur: %.2fs\n",
           ao, (long long)br, (int)neko_get_state(e), neko_get_duration(e));

    if (!media || strcmp(media, "tone.wav") == 0) {
        /* 自检：必须真实出声（PipeWire 或回退后端） */
        if (strlen(ao) == 0) {
            printf("FAIL: no audio output backend\n");
            g_fail = 1;
        }
        if (!g_playing_seen) {
            printf("FAIL: never reached PLAYING\n");
            g_fail = 1;
        }
        if (!g_pos_advanced) {
            printf("FAIL: position did not advance\n");
            g_fail = 1;
        }
    }

    neko_destroy(e);
    if (g_fail) {
        printf("RESULT: FAIL\n");
        return 1;
    }
    printf("RESULT: OK (ao=%s)\n", ao);
    return 0;
}
