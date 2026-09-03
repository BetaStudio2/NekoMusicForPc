/**
 * neko_core.h
 * NekoMusic Qt 核心桥 C FFI API。
 *
 * 线程模型：内部维护一个 QCoreApplication 工作线程（无 GUI），
 * 承载 ApiClient / UserManager / PlaylistDatabase / PlaylistManager。
 * Flutter 主线程通过 neko_core_cmd_* 异步投递命令（返回 seq），
 * 结果经回调写回有界队列，由 neko_core_poll 定时取走。
 *
 * 初始化复刻原 Qt 主程序（main.cpp）：应用元信息（保证 playlists.db
 * 路径一致）+ NoProxy 直连 + PlaylistDatabase::init()。
 */

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(NEKO_CORE_BUILD)
#    define NEKO_CORE_API __declspec(dllexport)
#  else
#    define NEKO_CORE_API __declspec(dllimport)
#  endif
#else
#  define NEKO_CORE_API __attribute__((visibility("default")))
#endif

/** 单行音乐信息的扁平化表示（UTF-8） */
typedef struct neko_core_music {
    int64_t id;
    char    title[256];
    char    artist[256];
    char    album[256];
    int64_t duration;       /* 秒，0 表示未知 */
    char    cover_url[1024];
    char    local_path[1024];
    int64_t play_count;     /* -1 表示未设置 */
    int64_t uploaded_at_ms; /* 0 表示未设置 */
    int32_t lrc;            /* 1 = 搜索命中且有歌词 */
    int64_t progress_received; /* 下载状态（DownloadsStatus 行）：已接收字节 */
    int64_t progress_total;    /* 下载状态：总字节 */
} neko_core_music;

#define NEKO_CORE_MAX_ROWS 64

/** 本地歌单信息的扁平化表示（UTF-8） */
typedef struct neko_core_playlist {
    int64_t local_id;        /* playlists.local_id */
    char    name[256];
    char    description[512];
    int64_t cover_music_id;  /* 封面曲 id，0 表示未设置 */
    int64_t music_count;     /* 歌单内歌曲数 */
    char    created_at[32];
    char    updated_at[32];
} neko_core_playlist;

#define NEKO_CORE_MAX_PLAYLISTS 64

/** 命令结果；nrows 行有效时逐行填 rows */
typedef struct neko_core_result {
    int64_t seq;
    int32_t ok;             /* 1 = 成功 */
    int32_t nrows;          /* rows 有效行数 */
    int32_t current_index;  /* 队列命令：当前播放索引 */
    char    play_mode[16];  /* 队列命令：播放模式 */
    neko_core_music rows[NEKO_CORE_MAX_ROWS];
    int32_t nplaylists;     /* playlists 有效行数（歌单列表命令） */
    neko_core_playlist playlists[NEKO_CORE_MAX_PLAYLISTS];
    char    message[256];   /* 错误信息/提示 */
    char    token[256];     /* 登录 token */
    char    str[4096];      /* 歌词 / 音乐详情 JSON / 登录用户 JSON */
    int64_t i64;            /* 搜索总数 / 新建歌单 id 等 */
    int64_t progress_received; /* 下载进度事件（seq=-1）：已接收字节 */
    int64_t progress_total;    /* 下载进度事件：总字节 */
} neko_core_result;

/* ---- 生命周期 ---- */

/** 启动 Qt 核心工作线程并初始化；已启动返回 1，失败返回 0 */
NEKO_CORE_API int neko_core_start(int verbose);

/** 停止工作线程并释放资源 */
NEKO_CORE_API int neko_core_stop(void);

/* ---- 异步命令（返回 seq，结果经 neko_core_poll 取回；返回 0 表示核心未启动） ---- */

/* 用户认证 */
NEKO_CORE_API int64_t neko_core_cmd_login(const char *username, const char *password);
NEKO_CORE_API int64_t neko_core_cmd_register(const char *username, const char *password,
                                             const char *email, const char *code);
NEKO_CORE_API int64_t neko_core_cmd_logout(void);
/** 修改密码；结果 ok + message */
NEKO_CORE_API int64_t neko_core_cmd_change_password(const char *old_password, const char *new_password);
/** 注册发邮箱验证码（需先完成滑块并取得 captchaPassToken）；结果 ok + message */
NEKO_CORE_API int64_t neko_core_cmd_send_verification(const char *email, const char *username,
                                                      const char *captcha_pass_token);
/** 获取滑块验证码 challenge；JSON 写入 r.str（captchaToken/bgImage/sliderImage/bgWidth/bgHeight/puzzleY/sliderWidth/sliderHeight） */
NEKO_CORE_API int64_t neko_core_cmd_slider_challenge(void);
/** 校验滑块（offset 为缺口偏移像素）；成功 r.ok=1 且 r.str = captchaPassToken */
NEKO_CORE_API int64_t neko_core_cmd_slider_verify(const char *captcha_token, int offset_x);
/** 忘记密码：发送重置验证码到邮箱；结果 ok + message */
NEKO_CORE_API int64_t neko_core_cmd_send_reset_code(const char *email);
/** 忘记密码：校验验证码并重置密码；结果 ok + message */
NEKO_CORE_API int64_t neko_core_cmd_reset_password(const char *email, const char *code,
                                                   const char *new_password);

/* 音乐数据 */
NEKO_CORE_API int64_t neko_core_cmd_fetch_ranking(void);
NEKO_CORE_API int64_t neko_core_cmd_fetch_latest(int limit);
NEKO_CORE_API int64_t neko_core_cmd_fetch_daily(void);
NEKO_CORE_API int64_t neko_core_cmd_search_music(const char *query, int page, int page_size);
NEKO_CORE_API int64_t neko_core_cmd_fetch_music_info(int music_id);
NEKO_CORE_API int64_t neko_core_cmd_fetch_lyrics(int music_id);
NEKO_CORE_API int64_t neko_core_cmd_fetch_favorites(void);
NEKO_CORE_API int64_t neko_core_cmd_toggle_favorite(int music_id);

/* 播放队列 / 本地记录（PlaylistManager + PlaylistDatabase） */
NEKO_CORE_API int64_t neko_core_cmd_queue_load(void);
NEKO_CORE_API int64_t neko_core_cmd_queue_clear(void);
NEKO_CORE_API int64_t neko_core_cmd_queue_add_all(const neko_core_music *list, int n);
NEKO_CORE_API int64_t neko_core_cmd_queue_set_index(int index);
NEKO_CORE_API int64_t neko_core_cmd_queue_set_mode(const char *mode);
NEKO_CORE_API int64_t neko_core_cmd_recent_load(void);
NEKO_CORE_API int64_t neko_core_cmd_record_recent(const neko_core_music *m);
NEKO_CORE_API int64_t neko_core_cmd_downloads_load(void);
NEKO_CORE_API int64_t neko_core_cmd_record_download(const neko_core_music *m, const char *file_path);

/* 本地歌单（PlaylistDatabase） */
/** 新建歌单；成功返回 id（r.i64），失败 r.ok = 0 */
NEKO_CORE_API int64_t neko_core_cmd_playlist_create(const char *name, const char *description);
NEKO_CORE_API int64_t neko_core_cmd_playlist_delete(int local_id);
NEKO_CORE_API int64_t neko_core_cmd_playlist_update(int local_id, const char *name, const char *description);
/** 歌单列表（含歌曲数，按更新时间倒序） */
NEKO_CORE_API int64_t neko_core_cmd_playlist_list(void);
/** 歌单内歌曲列表 */
NEKO_CORE_API int64_t neko_core_cmd_playlist_detail(int local_id);
NEKO_CORE_API int64_t neko_core_cmd_playlist_add_music(int local_id, const neko_core_music *m);
NEKO_CORE_API int64_t neko_core_cmd_playlist_remove_music(int local_id, int music_id);

/* 云端歌单 / 歌手 / 导入（结果复用 playlists[] 与 rows[]，JSON 承载用 str） */
/** 搜索/推荐歌单；query 为空串返回推荐列表（原版首页 {"query":""}） */
NEKO_CORE_API int64_t neko_core_cmd_fetch_playlists(const char *query);
/** 搜索歌手；结果 JSON 写入 r.str（{"name","musicCount",...}），无匹配 ok=0 */
NEKO_CORE_API int64_t neko_core_cmd_search_artists(const char *query);
/** 我的云端歌单列表 → playlists[] */
NEKO_CORE_API int64_t neko_core_cmd_fetch_user_playlists(void);
/** 收藏的云端歌单列表 → playlists[] */
NEKO_CORE_API int64_t neko_core_cmd_fetch_favorite_playlists(void);
/** 云端歌单内歌曲列表 → rows[] */
NEKO_CORE_API int64_t neko_core_cmd_fetch_playlist_music(int playlist_id);
/** 收藏 / 取消收藏云端歌单（需登录） */
NEKO_CORE_API int64_t neko_core_cmd_favorite_playlist(int playlist_id);
NEKO_CORE_API int64_t neko_core_cmd_unfavorite_playlist(int playlist_id);
/** 新建云端歌单；成功 id 写入 r.i64 */
NEKO_CORE_API int64_t neko_core_cmd_cloud_playlist_create(const char *name, const char *description);
NEKO_CORE_API int64_t neko_core_cmd_cloud_playlist_delete(int playlist_id);
/** 网易云歌单导入：ID 以字符串传（可能超 int32）；歌单信息 JSON 写入 r.str
 *  {"name":...,"tracks":[{"name","artist"},...]}（最多 60 首） */
NEKO_CORE_API int64_t neko_core_cmd_fetch_netease_playlist(const char *playlist_id);
/** QQ 音乐歌单导入：disstid；同上 */
NEKO_CORE_API int64_t neko_core_cmd_fetch_qq_playlist(const char *disstid);
/** 批量搜索匹配：items_json = [{"title","artist"},...]（最多 60 项）；
 *  结果 JSON 写入 r.str：{"matchedMusicIds":[...],"successCount":n,"failCount":m} */
NEKO_CORE_API int64_t neko_core_cmd_batch_search_music(const char *items_json);
/** 批量把歌曲加入云端歌单：ids_json = [1,2,3]；
 *  结果 JSON 写入 r.str：{"addedCount":n,"message":...} */
NEKO_CORE_API int64_t neko_core_cmd_batch_add_music_to_playlist(int playlist_id, const char *ids_json);

/* 会员中心 */
/** 获取 VIP 套餐列表；JSON 数组写入 r.str */
NEKO_CORE_API int64_t neko_core_cmd_vip_pricing(void);
/** 创建支付订单；订单 JSON 写入 r.str（qrUrl / qrContent / orderId 等） */
NEKO_CORE_API int64_t neko_core_cmd_vip_pay_create(int pricing_id, const char *pay_type);
/** 同步会话 VIP 状态；JSON 写入 r.str：{"isVip":bool,"vipExpiresAt":"..."} */
NEKO_CORE_API int64_t neko_core_cmd_vip_sync_status(void);

/* 下载（串行队列；进度经 seq=-1 结果推送，完成推原始 seq） */
/** 加入下载队列；完成/失败经结果队列推送（ok + message + i64=musicId + str=文件路径） */
NEKO_CORE_API int64_t neko_core_cmd_download_music(const neko_core_music *m);
/** 取消下载（队列中或进行中） */
NEKO_CORE_API int64_t neko_core_cmd_download_cancel(int music_id);
/** 下载队列状态 → rows[]（含 progress_received/progress_total；message 放本地文件路径，空=未完成） */
NEKO_CORE_API int64_t neko_core_cmd_downloads_status(void);

/* ---- LAN 设备同步 ---- */

/** 启动/停止局域网设备发现与队列同步（需先 set_account；登录后自动启） */
NEKO_CORE_API int64_t neko_core_cmd_lan_start(void);
NEKO_CORE_API int64_t neko_core_cmd_lan_stop(void);
/** 选择订阅的设备（空串=取消）；结果 str=JSON{connected, remoteQueue} */
NEKO_CORE_API int64_t neko_core_cmd_lan_select_device(const char *device_id);
/** 设置账号 userId（<=0=未登录：不广播） */
NEKO_CORE_API int64_t neko_core_cmd_lan_set_account(int user_id);
/** 上报播放状态镜像（曲目 id + 是否播放） */
NEKO_CORE_API int64_t neko_core_cmd_lan_set_player_state(int music_id, int playing);
/** 轮询状态；r.str = JSON{devices:[...],remoteQueue:{...},connected:bool,selectedDeviceId} */
NEKO_CORE_API int64_t neko_core_cmd_lan_poll(void);

/* ---- 同步查询（阻塞至 worker 线程返回；仅主线程调用） ---- */
/** 1 = 已登录 */
NEKO_CORE_API int neko_core_get_login_state(void);
/** 登录用户信息（JSON 字符串，未登录返回空串） */
NEKO_CORE_API int neko_core_get_login_info(char *buf, int buf_size);
/** 流媒体请求头（"Key: Value" 多行）；未登录返回 0 */
NEKO_CORE_API int neko_core_audio_headers(char *buf, int buf_size);

/* ---- 事件 ---- */

/** 从结果队列取出一条；无结果返回 0 */
NEKO_CORE_API int neko_core_poll(neko_core_result *out);

/** 结果入队回调（推送模式，替代宿主轮询）：worker 线程 push 结果后触发。
 *  回调可能从 worker 线程调用，宿主应尽快调用 neko_core_poll 取走。 */
typedef void (*neko_core_event_cb)(void *user);

/** 注册结果回调（推送模式）。传 NULL 取消。 */
NEKO_CORE_API void neko_core_set_event_cb(neko_core_event_cb cb, void *user);

#ifdef __cplusplus
}
#endif
