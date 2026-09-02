/**
 * test_core.c
 * neko_core 桥 CLI 自检：启动工作线程 → 拉取热门榜/最新/搜索 → 打印结果。
 */

#include "neko_core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static int g_failures = 0;

static void sleep_ms(int ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

/* 轮询直到拿到指定 seq 的结果 */
static int wait_result(int64_t seq, neko_core_result *out, int timeout_ms)
{
    const int step = 20;
    int waited = 0;
    while (waited < timeout_ms) {
        neko_core_result r;
        while (neko_core_poll(&r)) {
            if (r.seq == seq) {
                *out = r;
                return 1;
            }
        }
        sleep_ms(step);
        waited += step;
    }
    return 0;
}

static void check(const char *name, int cond)
{
    printf("[%s] %s\n", cond ? "PASS" : "FAIL", name);
    if (!cond)
        ++g_failures;
}

static void print_music(const neko_core_music *m)
{
    printf("    id=%lld title=%s artist=%s duration=%lld cover=%s\n",
           (long long)m->id, m->title, m->artist,
           (long long)m->duration, m->cover_url);
}

int main(void)
{
    printf("== neko_core CLI self-test ==\n");

    if (!neko_core_start(0)) {
        printf("FAIL: neko_core_start\n");
        return 1;
    }
    check("core start", 1);

    /* 登录态应为未登录 */
    check("login state initially 0", neko_core_get_login_state() == 0);

    /* 热门榜 */
    {
        int64_t seq = neko_core_cmd_fetch_ranking();
        check("ranking seq != 0", seq != 0);
        neko_core_result r;
        check("ranking result", wait_result(seq, &r, 15000));
        if (r.ok) {
            printf("  ranking: %d rows\n", r.nrows);
            check("ranking has rows", r.nrows > 0);
            if (r.nrows > 0)
                print_music(&r.rows[0]);
        } else {
            printf("  ranking failed: %s\n", r.message);
        }
    }

    /* 最新 */
    {
        int64_t seq = neko_core_cmd_fetch_latest(5);
        check("latest seq != 0", seq != 0);
        neko_core_result r;
        check("latest result", wait_result(seq, &r, 15000));
        if (r.ok) {
            printf("  latest: %d rows\n", r.nrows);
            check("latest has rows", r.nrows > 0);
        } else {
            printf("  latest failed: %s\n", r.message);
        }
    }

    /* 搜索 */
    {
        int64_t seq = neko_core_cmd_search_music("a", 1, 5);
        check("search seq != 0", seq != 0);
        neko_core_result r;
        check("search result", wait_result(seq, &r, 15000));
        if (r.ok) {
            printf("  search: total=%lld rows=%d\n", (long long)r.i64, r.nrows);
            check("search total >= 0", r.i64 >= 0);
        } else {
            printf("  search failed: %s\n", r.message);
        }
    }

    /* 队列：设置模式并读取 */
    {
        int64_t seq = neko_core_cmd_queue_set_mode("random");
        neko_core_result r;
        check("queue set mode", wait_result(seq, &r, 5000) && r.ok);
        seq = neko_core_cmd_queue_load();
        check("queue load", wait_result(seq, &r, 5000) && r.ok);
        printf("  queue: mode=%s current=%d rows=%d\n",
               r.play_mode, r.current_index, r.nrows);
        check("queue mode == random", strcmp(r.play_mode, "random") == 0);
    }

    /* 音频头：未登录应为 0 */
    {
        char buf[1024];
        check("audio headers empty when logged out",
              neko_core_audio_headers(buf, sizeof(buf)) == 0);
    }

    neko_core_stop();
    check("core stop", 1);

    printf("== %s (%d failures) ==\n", g_failures == 0 ? "ALL PASS" : "FAILED",
           g_failures);
    return g_failures == 0 ? 0 : 1;
}
