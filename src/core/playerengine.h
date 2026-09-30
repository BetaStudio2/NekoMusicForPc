#pragma once

#include <QObject>
#include <QUrl>
#include <QAudioDevice>

#include "core/musicinfo.h"

#if defined(NEKO_HAS_AUDIO_ENGINE)
class AudioEngine;
#else
#include <QMediaPlayer>
#include <QAudioOutput>
#endif

class QTimer;

/**
 * PlayerEngine — 播放引擎门面，对外 API/信号保持稳定，内部实现按构建二选一：
 *   - 定义 NEKO_HAS_AUDIO_ENGINE：NativePlayerEngine（ArchoeraMusic 原生引擎，
 *     支持音质无缝切换与曲间无缝续播），实现见 playerengine_native.cpp；
 *   - 未定义（如 Windows/无 FFmpeg 开发库）：沿用 QMediaPlayer 实现，见
 *     playerengine_qtmedia.cpp。
 * 两条实现共享本头文件的公共接口，UI/系统媒体/麦克风同步无需改动。
 */
class PlayerEngine : public QObject
{
    Q_OBJECT

public:
    enum PlaybackState {
        Stopped,
        Playing,
        Paused
    };
    Q_ENUM(PlaybackState)

    explicit PlayerEngine(QObject *parent = nullptr);
    ~PlayerEngine() override;

    void play(const QUrl &url);
    /** 切换本地文件并尽量从 resumeMs 继续（用于 .part 缓冲播完后切到正式缓存文件）。 */
    void playLocalResuming(const QString &localPath, qint64 resumeMs);
    /** 切换远程/任意 URL 并尽量从 resumeMs 继续（用于音质切换断点续传）。 */
    void playResuming(const QUrl &url, qint64 resumeMs);
    /** 在当前播放不中断的情况下切换媒体源（音质无缝切换）。 */
    void switchSourceWithoutRestart(const QUrl &url);
    /** 曲间无缝：预加载下一首（当前曲临近结束时调用；引擎暂存解码）。 */
    void prepareNextSource(const QUrl &url, const MusicInfo &music);
    /** 曲间无缝：在旧源解码游标/曲尾排空处接管已预加载的下一首。 */
    void commitPreparedNext();
    bool hasPreparedNext() const;
    /** 预加载的下一首是否已预解码就绪（就绪后 commit 才无损）。 */
    bool isPreparedNextReady() const;
    void play();
    void pause();
    void stop();
    void setVolume(float volume);
    /** 当前音频输出设备（麦克风同步会临时切到虚拟声卡，关闭时还原）。 */
    QAudioDevice outputDevice() const;
    void setOutputDevice(const QAudioDevice &device);
    float volume() const;
    void setPosition(qint64 position);
    void fadeIn();
    void fadeOut();
    void setCurrentMusic(const MusicInfo& music);
    const MusicInfo &currentMusic() const { return m_currentMusic; }

    PlaybackState playbackState() const;
    /** 与底层一致；淡出过程中 m_state 可能已为 Paused 但底层仍在 Playing 时为 true。 */
    bool isActuallyPlaying() const;
    bool isFadingOut() const { return m_fadingOut; }
    /** 对齐底层，供 MPRIS / 系统媒体用；淡出过程中底层仍在播时仍视为 Paused。 */
    PlaybackState transportStateForOs() const;
    QUrl currentMediaUrl() const;
    qint64 duration() const;
    qint64 position() const;
    /** 音频码率（bps），未就绪时为 0 */
    int audioBitRateBps() const;

signals:
    void stateChanged(PlaybackState state);
    /** 底层播放状态每次变化时发出（与 m_state 是否被淡出逻辑屏蔽无关）。 */
    void mediaPlaybackStateChanged();
    void positionChanged(qint64 position);
    void durationChanged(qint64 duration);
    void fadeComplete();
    void musicStarted(const MusicInfo& music);
    void mediaError(const QString &error);
    void playbackFinished();
    /** 曲间无缝切换完成：底层已从上一首无缝续播到 next。 */
    void transitionedToNext(const MusicInfo &next);
    /** 播放器元数据就绪时发出（含可用码率） */
    void audioMetaReady();

private:
#if defined(NEKO_HAS_AUDIO_ENGINE)
    // ── 原生引擎实现（playerengine_native.cpp）──
    void cancelFade();
    void onFadeTick();
    void teardownEngine();
    void beginSession(const QUrl &url, qint64 resumeMs);
    void applyEngineVolume();
    float effectiveVolume() const;
    static QString mapDeviceToSinkId(const QAudioDevice &device);

    AudioEngine *m_audio = nullptr;
    PlaybackState m_state = Stopped;
    float m_targetVolume = 1.0f;
    QTimer *m_fadeTimer = nullptr;
    bool m_fadingIn = false;
    bool m_fadingOut = false;
    MusicInfo m_currentMusic;
    qint64 m_seekLimitMs = -1;
    QUrl m_pendingUrl;
    qint64 m_pendingResumeMs = -1;
    quint64 m_openGen = 0;
    QUrl m_currentUrl;
    qint64 m_durationMs = 0;
    qint64 m_positionMs = 0;
    float m_fadeValue = 0.0f;
    QAudioDevice m_outputDevice;
    QUrl m_preparedUrl;
    MusicInfo m_preparedMusic;
    bool m_hasPrepared = false;
    bool m_preparedReady = false;
    bool m_switching = false;
    /** 期望播放态：pause() 可能早于引擎就绪（pauseWhenReady），就绪时据此决定起播/暂停。 */
    bool m_desiredPlaying = false;
    /** 引擎会话已就绪（收到 ready）；用于区分首次起播与恢复播放的乐观状态。 */
    bool m_engineReady = false;
#else
    // ── QMediaPlayer 实现（playerengine_qtmedia.cpp）──
    void onPlayerMetaDataChanged();
    void connectPlayerSignals(QMediaPlayer *player);
    void cancelFade();
    void onMediaStateChanged(QMediaPlayer::PlaybackState state);
    void onFadeTick();
    /** 等底层 Stopped 后再 setSource，避免切歌/重试时 FFmpeg demuxer 竞态。 */
    void openMedia(const QUrl &url, qint64 resumeMs = -1);
    void applyPendingOpen(quint64 gen);
    void scheduleResumeAfterOpen(qint64 resumeMs);
    /** 新媒体可 seek 且时长就绪后执行断点 seek；未命中则后续信号继续重试。 */
    void applyPendingResume();
    /** 时长就绪且 mediaStatus 至少 LoadedMedia 时，setPosition 才不会被后端丢弃。 */
    bool resumeMediaReady() const;
    void clearPendingResume();
    void cancelQualitySwitch();

    QMediaPlayer *m_player;
    QAudioOutput *m_audioOutput;
    PlaybackState m_state = Stopped;
    float m_targetVolume = 1.0f;
    QTimer *m_fadeTimer = nullptr;
    bool m_fadingIn = false;
    bool m_fadingOut = false;
    MusicInfo m_currentMusic;
    qint64 m_seekLimitMs = -1; // -1 means no limit
    QUrl m_pendingUrl;
    qint64 m_pendingResumeMs = -1;
    qint64 m_resumeTargetMs = -1;
    QMetaObject::Connection m_resumeStatusConn;
    QMetaObject::Connection m_resumeDurationConn;
    QMetaObject::Connection m_resumeSeekableConn;
    QMetaObject::Connection m_resumePositionConn;
    QTimer *m_resumeTimeoutTimer = nullptr;
    quint64 m_openGen = 0;
    QMetaObject::Connection m_stopForOpenConn;
    QMediaPlayer *m_qualitySwitchPlayer = nullptr;
    QAudioOutput *m_qualitySwitchOutput = nullptr;
    quint64 m_qualitySwitchGen = 0;
#endif

public:
    void setSeekLimitMs(qint64 limitMs) { m_seekLimitMs = limitMs; }
    qint64 seekLimitMs() const { return m_seekLimitMs; }
};
