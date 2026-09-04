/* neko_engine.c — libmpv 封装实现。
 * 事件线程：mpv_wait_event + 属性变化 → 写入有界队列；宿主轮询取走。
 */

#define _GNU_SOURCE /* dladdr / Dl_info（glibc） */

#include "neko_engine.h"

#include <mpv/client.h>

#include <errno.h>
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_WIN32)
#  include <dlfcn.h>
#endif

#if defined(_WIN32)
#  include <windows.h>
#  define NEKO_THREAD HANDLE
#  define neko_sleep_ms(ms) Sleep(ms)
#else
#  include <pthread.h>
#  include <unistd.h>
#  define NEKO_THREAD pthread_t
#  define neko_sleep_ms(ms) usleep((ms) * 1000)
#endif

#define NEKO_QUEUE_CAP 256

/* 全局错误诊断：创建/初始化失败时记录原因，供宿主通过 neko_last_error 读取 */
static char g_last_error[512];

static void set_last_error(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_last_error, sizeof(g_last_error), fmt, ap);
    va_end(ap);
}

NEKO_API void neko_last_error(char *buf, int buf_size)
{
    if (!buf || buf_size <= 0)
        return;
    snprintf(buf, buf_size, "%s", g_last_error);
}

/* 单调时钟（秒），用于事件节流 */
static double neko_mono_clock(void)
{
#if defined(_WIN32)
    return (double)GetTickCount64() / 1000.0;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

typedef struct neko_engine {
    mpv_handle *mpv;

    /* 事件队列 */
    neko_event queue[NEKO_QUEUE_CAP];
    int q_head, q_tail, q_count;
#if defined(_WIN32)
    CRITICAL_SECTION lock;
#else
    pthread_mutex_t lock;
#endif

    /* 事件线程 */
    NEKO_THREAD thread;
    volatile int exit_flag;
    volatile int inited;

    /* 节流/去重状态 */
    double last_pos_emit;
    double last_pos_val;
    double last_dur_val;
    int64_t last_bitrate;
    char last_title[256];

    /* 待恢复位置（一次性） */
    int pending_resume_valid;
    double pending_resume_sec;

    /* ao 是否被显式覆盖（初始化时不再套用平台默认链） */
    int ao_override_set;

    /* 事件回调（推送模式，替代宿主轮询）；回调在入队后触发 */
    neko_event_cb ev_cb;
    void *ev_user;
} neko_engine;

/* ---------------- 队列 ---------------- */

static void q_push(neko_engine *e, const neko_event *ev)
{
#if defined(_WIN32)
    EnterCriticalSection(&e->lock);
#else
    pthread_mutex_lock(&e->lock);
#endif
    if (e->q_count == NEKO_QUEUE_CAP) {
        /* 队满：丢最旧 */
        e->q_head = (e->q_head + 1) % NEKO_QUEUE_CAP;
        e->q_count--;
    }
    e->queue[(e->q_head + e->q_count) % NEKO_QUEUE_CAP] = *ev;
    e->q_count++;
#if defined(_WIN32)
    LeaveCriticalSection(&e->lock);
#else
    pthread_mutex_unlock(&e->lock);
#endif
    /* 解锁后触发回调（推送模式）；回调线程安全，宿主须尽快取事件 */
    if (e->ev_cb)
        e->ev_cb(e->ev_user);
}

static void q_push_state(neko_engine *e, neko_play_state st)
{
    neko_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = NEKO_EV_STATE;
    ev.f64 = (double)st;
    q_push(e, &ev);
}

static void q_push_err(neko_engine *e, const char *msg)
{
    neko_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = NEKO_EV_ERROR;
    snprintf(ev.str, sizeof(ev.str), "%s", msg);
    q_push(e, &ev);
}

/* ---------------- 状态读取 ---------------- */

static int prop_flag(neko_engine *e, const char *name)
{
    int v = 0;
    if (mpv_get_property(e->mpv, name, MPV_FORMAT_FLAG, &v) < 0)
        return -1;
    return v;
}

static neko_play_state read_state(neko_engine *e)
{
    /* core-idle 无法区分「暂停」与「无文件」（两者均为 1），
     * 必须用 idle-active（mpv 0.36+，仅无文件时为真）或 filename 区分，
     * 否则暂停会被误报为 STOPPED，导致 UI 无法恢复播放。 */
    int idle_active = prop_flag(e, "idle-active");
    if (idle_active >= 0) {
        if (idle_active == 1)
            return NEKO_STATE_STOPPED;
        int pause = prop_flag(e, "pause");
        if (pause == 1)
            return NEKO_STATE_PAUSED;
        return NEKO_STATE_PLAYING;
    }
    /* 旧版 mpv 回退：filename 非空说明存在已加载文件 */
    char *fn = NULL;
    int has_file = mpv_get_property(e->mpv, "filename", MPV_FORMAT_STRING,
                                    &fn) >= 0 && fn && fn[0];
    if (fn)
        mpv_free(fn);
    if (!has_file)
        return NEKO_STATE_STOPPED;
    int pause = prop_flag(e, "pause");
    if (pause == 1)
        return NEKO_STATE_PAUSED;
    return NEKO_STATE_PLAYING;
}

/* ---------------- 事件泵 ---------------- */

static void on_property_change(neko_engine *e, mpv_event_property *prop)
{
    const char *name = prop->name;

    /* idle-active 决定 read_state 的首选判据，必须一并观察 */
    if (strcmp(name, "pause") == 0 || strcmp(name, "core-idle") == 0 ||
        strcmp(name, "idle-active") == 0) {
        neko_play_state st = read_state(e);
        q_push_state(e, st);
        return;
    }

    if (strcmp(name, "time-pos") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
        double pos = *(double *)prop->data;
        double t = neko_mono_clock();
        /* 节流：至少 100ms 间隔且位移 >= 50ms */
        if (t - e->last_pos_emit >= 0.1 &&
            (pos - e->last_pos_val > 0.05 || pos - e->last_pos_val < -0.05)) {
            neko_event ev;
            memset(&ev, 0, sizeof(ev));
            ev.type = NEKO_EV_POSITION;
            ev.f64 = pos;
            q_push(e, &ev);
            e->last_pos_val = pos;
            e->last_pos_emit = t;
        }
        return;
    }

    if (strcmp(name, "duration") == 0 && prop->format == MPV_FORMAT_DOUBLE) {
        double dur = *(double *)prop->data;
        if (dur > 0 && (dur - e->last_dur_val > 0.5 || dur - e->last_dur_val < -0.5)) {
            neko_event ev;
            memset(&ev, 0, sizeof(ev));
            ev.type = NEKO_EV_DURATION;
            ev.f64 = dur;
            q_push(e, &ev);
            e->last_dur_val = dur;
        }
        return;
    }

    if (strcmp(name, "audio-bitrate") == 0 && prop->format == MPV_FORMAT_INT64) {
        int64_t br = *(int64_t *)prop->data;
        if (br > 0 && br != e->last_bitrate) {
            e->last_bitrate = br;
            neko_event ev;
            memset(&ev, 0, sizeof(ev));
            ev.type = NEKO_EV_AUDIO_META;
            ev.i64 = br;
            q_push(e, &ev);
        }
        return;
    }

    if (strcmp(name, "media-title") == 0 && prop->format == MPV_FORMAT_STRING) {
        const char *title = prop->data ? *(char **)prop->data : "";
        if (strcmp(title, e->last_title) != 0) {
            snprintf(e->last_title, sizeof(e->last_title), "%s", title);
            neko_event ev;
            memset(&ev, 0, sizeof(ev));
            ev.type = NEKO_EV_TITLE;
            snprintf(ev.str, sizeof(ev.str), "%s", title);
            q_push(e, &ev);
        }
        return;
    }
}

static void on_end_file(neko_engine *e, mpv_event_end_file *ef)
{
    neko_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = NEKO_EV_END_FILE;
    ev.i64 = ef->reason;

    if (ef->reason == MPV_END_FILE_REASON_ERROR && ef->error < 0) {
        q_push_err(e, mpv_error_string(ef->error));
    }
    q_push(e, &ev);

    /* 文件真正结束（EOF/出错）才主动回到待命状态；
     * 切歌（replace/redirect，及用户 stop/quit）不在此推 STOPPED——
     * 新文件加载期间的状态由 idle-active/pause 事件自然上报，
     * 避免在线流加载慢时播放按钮短暂误报禁用。 */
    if (ef->reason == MPV_END_FILE_REASON_EOF ||
        ef->reason == MPV_END_FILE_REASON_ERROR)
        q_push_state(e, NEKO_STATE_STOPPED);
}

#if defined(_WIN32)
static DWORD WINAPI event_thread_fn(LPVOID arg)
#else
static void *event_thread_fn(void *arg)
#endif
{
    neko_engine *e = (neko_engine *)arg;
    mpv_handle *mpv = e->mpv;

    while (!e->exit_flag) {
        mpv_event *ev = mpv_wait_event(mpv, 0.1);
        if (ev->event_id == MPV_EVENT_NONE)
            continue;

        switch (ev->event_id) {
        case MPV_EVENT_SHUTDOWN:
            e->exit_flag = 1;
            break;
        case MPV_EVENT_START_FILE:
            /* 新文件开始：清掉旧的恢复标记由 load 后显式设置 */
            break;
        case MPV_EVENT_PLAYBACK_RESTART: {
            if (e->pending_resume_valid) {
                double sec = e->pending_resume_sec;
                e->pending_resume_valid = 0;
                mpv_set_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &sec);
            }
            neko_event nev;
            memset(&nev, 0, sizeof(nev));
            nev.type = NEKO_EV_READY;
            q_push(e, &nev);
            break;
        }
        case MPV_EVENT_END_FILE:
            on_end_file(e, (mpv_event_end_file *)ev->data);
            break;
        case MPV_EVENT_PROPERTY_CHANGE:
            on_property_change(e, (mpv_event_property *)ev->data);
            break;
        default:
            break;
        }
    }
#if defined(_WIN32)
    return 0;
#else
    return NULL;
#endif
}

/* ---------------- 公开 API ---------------- */

neko_engine *neko_create(void)
{
    g_last_error[0] = '\0';

    /* GTK/Qt 初始化会调用 setlocale(LC_ALL, "")，使 LC_NUMERIC 变为非 C，
     * 导致 libmpv 的 mpv_create() 返回 NULL（见 mpv#7102）。按要求恢复 C。 */
    setlocale(LC_NUMERIC, "C");

    neko_engine *e = (neko_engine *)calloc(1, sizeof(neko_engine));
    if (!e) {
        set_last_error("neko_engine alloc failed (errno=%d: %s)",
                       errno, strerror(errno));
        return NULL;
    }

    /* 诊断：确认进程内实际加载的 libmpv 与 ABI 版本是否匹配 */
    unsigned long api = mpv_client_api_version();
    const char *libpath = "?";
#if !defined(_WIN32)
    Dl_info di;
    if (dladdr((void *)mpv_client_api_version, &di) && di.dli_fname)
        libpath = di.dli_fname;
#endif
    fprintf(stderr,
            "[neko_engine] mpv client api=%lu expect=%lu lib=%s\n",
            api, (unsigned long)MPV_CLIENT_API_VERSION, libpath);

    e->mpv = mpv_create();
    if (!e->mpv) {
        set_last_error(
            "mpv_create() failed (errno=%d: %s, api=%lu, expect=%lu, lib=%s)",
            errno, strerror(errno), api,
            (unsigned long)MPV_CLIENT_API_VERSION, libpath);
        fprintf(stderr, "[neko_engine] FATAL: %s\n", g_last_error);
        free(e);
        return NULL;
    }
    e->last_dur_val = -1.0;
#if defined(_WIN32)
    InitializeCriticalSection(&e->lock);
#else
    pthread_mutex_init(&e->lock, NULL);
#endif
    return e;
}

int neko_initialize(neko_engine *e, int verbose)
{
    if (!e || e->inited)
        return -1;

    /* 与 neko_create 同理：Qt 等宿主可能已改 locale，初始化前恢复 C 数字区域 */
    setlocale(LC_NUMERIC, "C");

    /* 不读用户 mpv 配置，行为可复现 */
    mpv_set_option_string(e->mpv, "config", "no");
    mpv_set_option_string(e->mpv, "terminal", "no");
    mpv_set_option_string(e->mpv, "osc", "no");
    mpv_set_option_string(e->mpv, "vo", "null");
    mpv_set_option_string(e->mpv, "video", "no");
    mpv_set_option_string(e->mpv, "audio-display", "no");
    mpv_set_option_string(e->mpv, "audio-fallback-to-null", "no");
    mpv_set_option_string(e->mpv, "gapless-audio", "yes");
    /* 0.36+ 缓存默认开启，勿再用已弃用的 cache/cache-default 旧选项；
     * 仅限制 demuxer 缓存上限，避免在线流缓冲抖动。 */
    mpv_set_option_string(e->mpv, "demuxer-max-bytes", "64MiB");

#if defined(_WIN32)
    if (!e->ao_override_set)
        mpv_set_option_string(e->mpv, "ao", "wasapi");
#elif defined(__APPLE__)
    if (!e->ao_override_set)
        mpv_set_option_string(e->mpv, "ao", "coreaudio");
#else
    /* Linux：PipeWire 原生优先，失败按链回退 pulseaudio → alsa */
    if (!e->ao_override_set)
        mpv_set_option_string(e->mpv, "ao", "pipewire,pulse,alsa");
#endif
    /* 显式 ao 或默认链：初始化失败时都允许回退（满足「失败时主动回退」） */
    mpv_set_option_string(e->mpv, "ao-fallback", "yes");

    mpv_set_option_string(e->mpv, "msg-level",
                          verbose ? "all=info" : "all=warn");

    /* 诊断辅助：设 NEKO_ENGINE_LOG_FILE 可将 mpv 全部日志落盘 */
    const char *logfile = getenv("NEKO_ENGINE_LOG_FILE");
    if (logfile && logfile[0])
        mpv_set_option_string(e->mpv, "log-file", logfile);

    if (mpv_initialize(e->mpv) < 0) {
        set_last_error("mpv_initialize failed");
        fprintf(stderr, "[neko_engine] FATAL: %s\n", g_last_error);
        mpv_destroy(e->mpv);
        e->mpv = NULL;
        return -1;
    }

    /* 观察属性 */
    mpv_observe_property(e->mpv, 0, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(e->mpv, 0, "core-idle", MPV_FORMAT_FLAG);
    mpv_observe_property(e->mpv, 0, "idle-active", MPV_FORMAT_FLAG);
    mpv_observe_property(e->mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(e->mpv, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(e->mpv, 0, "audio-bitrate", MPV_FORMAT_INT64);
    mpv_observe_property(e->mpv, 0, "media-title", MPV_FORMAT_STRING);

    e->inited = 1;

#if defined(_WIN32)
    e->thread = CreateThread(NULL, 0, event_thread_fn, e, 0, NULL);
#else
    pthread_create(&e->thread, NULL, event_thread_fn, e);
#endif

    /* 初始状态上报 */
    q_push_state(e, read_state(e));
    return 0;
}

int neko_destroy(neko_engine *e)
{
    if (!e)
        return -1;
    if (e->inited) {
        e->exit_flag = 1;
        mpv_wakeup(e->mpv);
#if defined(_WIN32)
        WaitForSingleObject(e->thread, 2000);
        CloseHandle(e->thread);
#else
        pthread_join(e->thread, NULL);
#endif
    }
    if (e->mpv)
        mpv_destroy(e->mpv);
#if defined(_WIN32)
    DeleteCriticalSection(&e->lock);
#else
    pthread_mutex_destroy(&e->lock);
#endif
    free(e);
    return 0;
}

int neko_set_option(neko_engine *e, const char *name, const char *value)
{
    if (!e || !e->mpv || !name || !value)
        return -1;
    if (strcmp(name, "ao") == 0)
        e->ao_override_set = 1;
    if (mpv_set_option_string(e->mpv, name, value) < 0)
        return -1;
    return 0;
}

int neko_load(neko_engine *e, const char *url)
{
    if (!e || !e->mpv || !url)
        return -1;
    e->pending_resume_valid = 0;
    e->last_bitrate = 0;
    /* loadfile 不清除 pause（暂停态切歌会保持暂停）；宿主须在 load 后调用
     * neko_play 显式置 pause=0（对齐原版 Qt applyPendingOpen 的 play()）。
     * 注意：勿给 loadfile 传 options 参数——实测 mpv 0.41 返回 invalid parameter。 */
    const char *cmd[] = { "loadfile", url, "replace", NULL };
    int r = mpv_command(e->mpv, cmd);
    return r < 0 ? r : 0;
}

int neko_set_resume_position(neko_engine *e, double seconds)
{
    if (!e || seconds < 0)
        return -1;
    e->pending_resume_sec = seconds;
    e->pending_resume_valid = 1;
    return 0;
}

int neko_play(neko_engine *e)
{
    if (!e || !e->mpv)
        return -1;
    int v = 0;
    mpv_set_property(e->mpv, "pause", MPV_FORMAT_FLAG, &v);
    return 0;
}

int neko_pause(neko_engine *e)
{
    if (!e || !e->mpv)
        return -1;
    int v = 1;
    mpv_set_property(e->mpv, "pause", MPV_FORMAT_FLAG, &v);
    return 0;
}

int neko_stop(neko_engine *e)
{
    if (!e || !e->mpv)
        return -1;
    const char *cmd[] = { "stop", NULL };
    mpv_command(e->mpv, cmd);
    return 0;
}

int neko_seek(neko_engine *e, double seconds, int absolute)
{
    if (!e || !e->mpv)
        return -1;
    char val[64];
    snprintf(val, sizeof(val), "%.3f", seconds);
    const char *cmd[] = { "seek", val, absolute ? "absolute" : "relative", NULL };
    int r = mpv_command(e->mpv, cmd);
    return r < 0 ? r : 0;
}

int neko_set_volume(neko_engine *e, double volume)
{
    if (!e || !e->mpv)
        return -1;
    if (volume < 0)
        volume = 0;
    if (volume > 1)
        volume = 1;
    double v = volume * 100.0;
    mpv_set_property(e->mpv, "volume", MPV_FORMAT_DOUBLE, &v);
    return 0;
}

double neko_get_volume(neko_engine *e)
{
    if (!e || !e->mpv)
        return 0.0;
    double v = 100.0;
    if (mpv_get_property(e->mpv, "volume", MPV_FORMAT_DOUBLE, &v) < 0)
        return 0.0;
    if (v < 0)
        v = 0;
    if (v > 100)
        v = 100;
    return v / 100.0;
}

neko_play_state neko_get_state(neko_engine *e)
{
    if (!e || !e->mpv)
        return NEKO_STATE_STOPPED;
    return read_state(e);
}

double neko_get_position(neko_engine *e)
{
    if (!e || !e->mpv)
        return 0.0;
    double pos = 0.0;
    if (mpv_get_property(e->mpv, "time-pos", MPV_FORMAT_DOUBLE, &pos) < 0)
        return 0.0;
    return pos < 0 ? 0.0 : pos;
}

double neko_get_duration(neko_engine *e)
{
    if (!e || !e->mpv)
        return 0.0;
    double dur = 0.0;
    if (mpv_get_property(e->mpv, "duration", MPV_FORMAT_DOUBLE, &dur) < 0)
        return 0.0;
    return dur < 0 ? 0.0 : dur;
}

void neko_get_audio_output(neko_engine *e, char *buf, int buf_size)
{
    if (buf && buf_size > 0)
        buf[0] = '\0';
    if (!e || !e->mpv || !buf || buf_size <= 0)
        return;
    char *ao = NULL;
    /* current-ao 才是实际生效的后端（mpv 0.36+）；ao 是配置值 */
    if (mpv_get_property(e->mpv, "current-ao", MPV_FORMAT_STRING, &ao) >= 0 && ao) {
        snprintf(buf, buf_size, "%s", ao);
        mpv_free(ao);
        return;
    }
    if (mpv_get_property(e->mpv, "ao", MPV_FORMAT_STRING, &ao) >= 0 && ao) {
        snprintf(buf, buf_size, "%s", ao);
        mpv_free(ao);
    }
}

int64_t neko_get_audio_bitrate(neko_engine *e)
{
    if (!e || !e->mpv)
        return 0;
    int64_t br = 0;
    if (mpv_get_property(e->mpv, "audio-bitrate", MPV_FORMAT_INT64, &br) < 0)
        return 0;
    return br;
}

int neko_poll_event(neko_engine *e, neko_event *ev)
{
    if (!e || !ev)
        return 0;
#if defined(_WIN32)
    EnterCriticalSection(&e->lock);
#else
    pthread_mutex_lock(&e->lock);
#endif
    if (e->q_count == 0) {
#if defined(_WIN32)
        LeaveCriticalSection(&e->lock);
#else
        pthread_mutex_unlock(&e->lock);
#endif
        return 0;
    }
    *ev = e->queue[e->q_head];
    e->q_head = (e->q_head + 1) % NEKO_QUEUE_CAP;
    e->q_count--;
#if defined(_WIN32)
    LeaveCriticalSection(&e->lock);
#else
    pthread_mutex_unlock(&e->lock);
#endif
    return 1;
}

void neko_engine_set_event_cb(neko_engine *e, neko_event_cb cb, void *user)
{
    if (!e)
        return;
    /* 事件线程仅在 q_push 解锁后读取；写入发生在宿主线程，入队时序已天然同步 */
    e->ev_cb = cb;
    e->ev_user = user;
}
