/**
 * neko_engine.h
 * NekoMusic 播放引擎 C FFI API。
 *
 * 基于 libmpv：
 *  - Linux:   ao=pipewire,pulse,alsa（PipeWire 原生优先，失败自动回退）
 *  - Windows: ao=wasapi
 *  - macOS:   ao=coreaudio
 *
 * 线程模型：引擎内部维护一个事件线程，负责 mpv_wait_event 与属性轮询，
 * 事件写入内部有界队列，宿主（Flutter）通过 neko_poll_event 定时取走。
 */

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(NEKO_ENGINE_BUILD)
#    define NEKO_API __declspec(dllexport)
#  else
#    define NEKO_API __declspec(dllimport)
#  endif
#else
#  define NEKO_API __attribute__((visibility("default")))
#endif

/** 播放状态，与 Qt 侧 PlayerEngine::PlaybackState 对齐 */
typedef enum neko_play_state {
    NEKO_STATE_STOPPED = 0,
    NEKO_STATE_PLAYING,
    NEKO_STATE_PAUSED
} neko_play_state;

/** 事件类型 */
typedef enum neko_event_type {
    NEKO_EV_NONE = 0,
    NEKO_EV_STATE,      /* f64 = (double)neko_play_state */
    NEKO_EV_POSITION,   /* f64 = 秒 */
    NEKO_EV_DURATION,   /* f64 = 秒，-1 表示未知 */
    NEKO_EV_END_FILE,   /* i64 = 原因: 0=EOF 1=stop 2=error 3=replace */
    NEKO_EV_AUDIO_META, /* 码率就绪（bitrate 可用） */
    NEKO_EV_TITLE,      /* str = 媒体标题（可能为空） */
    NEKO_EV_ERROR,      /* str = 错误信息 */
    NEKO_EV_SEEK,       /* 跳转完成 */
    NEKO_EV_READY       /* 首帧/音频就绪，可安全应用恢复位置 */
} neko_event_type;

/** 事件结构；str 字段仅在对应事件类型下有效 */
typedef struct neko_event {
    int32_t type;      /* neko_event_type */
    double  f64;
    int64_t i64;
    char    str[256];
} neko_event;

/** 引擎句柄（不透明） */
typedef struct neko_engine neko_engine;

/* ---- 生命周期 ---- */

/** 创建引擎实例；失败返回 NULL */
NEKO_API neko_engine *neko_create(void);

/**
 * 初始化：设置音频输出链并启动事件线程。
 * @param verbose 1 时透传 mpv 日志（供调试 ao 选择）
 */
NEKO_API int neko_initialize(neko_engine *e, int verbose);

/** 销毁引擎并释放资源 */
NEKO_API int neko_destroy(neko_engine *e);

/**
 * 最近一次错误的诊断信息（含 neko_create/neko_initialize 失败原因）。
 * 不依赖句柄，创建失败后仍可调用。无错误时 buf 为空串。
 */
NEKO_API void neko_last_error(char *buf, int buf_size);

/* ---- 通用选项 ---- */

/**
 * 设置 mpv 选项（须在 neko_load 之前调用）。
 * 例：neko_set_option(e, "http-header-fields", "User-Agent: xxx");
 */
NEKO_API int neko_set_option(neko_engine *e, const char *name, const char *value);

/* ---- 播放控制 ---- */

/** 异步加载 URL/本地路径并开始播放（replace 模式） */
NEKO_API int neko_load(neko_engine *e, const char *url);

/** 加载后待播放就绪时恢复位置（须在 load 后调用，会自动一次性生效） */
NEKO_API int neko_set_resume_position(neko_engine *e, double seconds);

NEKO_API int neko_play(neko_engine *e);
NEKO_API int neko_pause(neko_engine *e);
NEKO_API int neko_stop(neko_engine *e);
NEKO_API int neko_seek(neko_engine *e, double seconds, int absolute);

/** volume: 0.0 ~ 1.0 */
NEKO_API int neko_set_volume(neko_engine *e, double volume);
NEKO_API double neko_get_volume(neko_engine *e);

/* ---- 查询 ---- */

NEKO_API neko_play_state neko_get_state(neko_engine *e);
NEKO_API double neko_get_position(neko_engine *e);
NEKO_API double neko_get_duration(neko_engine *e);
/** 当前音频输出后端名称（如 "pipewire"/"pulseaudio"/"alsa"/"wasapi"/"coreaudio"），失败返回空串 */
NEKO_API void neko_get_audio_output(neko_engine *e, char *buf, int buf_size);
/** 音频码率 bps，未知为 0 */
NEKO_API int64_t neko_get_audio_bitrate(neko_engine *e);

/* ---- 事件 ---- */

/**
 * 从内部队列取出一条事件；无事件返回 0，ev 内容无效。
 * 队列满时旧事件被丢弃。
 */
NEKO_API int neko_poll_event(neko_engine *e, neko_event *ev);

/** 事件回调：结果入队后由 C 侧事件线程触发（替代宿主轮询取事件）。
 *  回调可能从任意线程调用，宿主应尽快调用 neko_poll_event 取走队列。 */
typedef void (*neko_event_cb)(void *user);

/**
 * 注册事件回调（推送模式）。传 NULL 取消。
 * 需在 neko_initialize 之前注册，以便捕获初始化期事件。
 */
NEKO_API void neko_engine_set_event_cb(neko_engine *e, neko_event_cb cb, void *user);

#ifdef __cplusplus
}
#endif
