#pragma once

// AudioEngine — ArchoeraMusic 原生音频引擎的 Qt 封装（移植自
// app/lib/services/playback/audio_engine_process.dart + archoera_mediaengine.h）。
//
// 设计要点（对齐 Dart 侧 AudioEngineProcess）：
//   - 引擎在**独立工作线程**创建（pipeline_create 打开文件/网络可能耗时），
//     并在同一线程阻塞 `wait_event` 排空事件 FIFO；
//   - 事件经 QMetaObject::invokeMethod 回到主线程（QObject 亲和线程）解析；
//   - 命令（play/pause/seek/.../prepare_source/commit_source）由主线程直接
//     下发（C 侧命令 FIFO 线程安全）；
//   - 会话目录由本类创建/清理（引擎文件模式落 stream.wav/.pcm，均属临时产物，
//     与 App 的歌曲缓存无关）。
//
// 仅编译进启用原生引擎的目标（NEKO_HAS_AUDIO_ENGINE），见 CMakeLists。

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <atomic>
#include <thread>

struct ArchoeraMediaEngine;

class AudioEngine : public QObject
{
    Q_OBJECT

public:
    /** 引擎配置（仅暴露 Qt 侧需要的字段）。engine_mode 由 audioengine.cpp 按
     *  构建期是否链接 EraAudio 内核 + 运行时 NEKO_ERAUDIO 决定（默认原生优先）。 */
    struct Config {
        qint64 startOffsetMs = 0;   // 起播偏移（断点续播）
        int outputSampleRate = 0;   // 0 = 跟随源（passthrough）
        int outputChannels = 2;
        int bitrate = 128000;
        bool skipEncoder = true;    // player 模式：仅 PCM 落盘 + 设备自播
        int noDiskCache = 0;        // 保持文件模式（不改动缓存策略）
        qint64 pcmMemCapKb = 0;
    };

    /** 系统输出设备（引擎视角）。 */
    struct Sink {
        QString id;
        QString name;
        bool isDefault = false;
    };

    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    /** 异步创建会话并启动事件泵；就绪以 started() 通知，失败以 startFailed()。
     *  调用前须确保该实例未被 start（一个实例对应一个会话）。 */
    void start(const QString &source, const Config &cfg);

    /** 请求停止：置退出标志，工作线程在 wait_event 超时后自行 destroy 并
     *  发 stopped()。非阻塞，可在槽中安全调用；随后应 deleteLater()。 */
    void stop();

    bool isRunning() const { return m_running.load(); }
    bool isPlaying() const { return m_playing; }

    // ── 控制命令（主线程短调用；句柄为空时静默忽略）──
    void play();
    void pause();
    void seek(qint64 positionMs);
    void setVolume(float gain);
    void setSink(const QString &sinkId);
    void setEventInterval(int intervalMs);
    void requestStatus();

    /** 无缝切换：预打开/预解码新源到暂存缓冲（当前源不受影响）。
     *  nextTrack=true 表示暂存的是**下一首新曲**（从 0 起，commit 不裁剪）；
     *  false（默认）表示同一首歌换音质（从当前解码游标续起，样本级对齐）。 */
    void prepareSource(const QString &url, bool nextTrack = false);
    /** 无缝切换：在旧源解码游标处接管暂存源。 */
    void commitSource();

    /** 枚举系统输出设备（阻塞；内部自建 pulse/alsa context）。 */
    static QVector<Sink> listSinks();

signals:
    /** 会话就绪（引擎 ready 事件；管线建立、开始解码/出声）。 */
    void started(qint64 durationMs, int sampleRate, int channels,
                 int outSampleRate, const QString &backend);
    /** 创建失败 / ready 之前出错。 */
    void startFailed(const QString &message);
    void playingChanged(bool playing, qint64 durationMs);
    void positionChanged(qint64 positionMs);
    void durationChanged(qint64 durationMs);
    /** 曲目自然播放结束（miniaudio EOF）。 */
    void playerEnded();
    /** 内容完整解码到 EOF。 */
    void contentDone();
    void errorOccurred(const QString &message);
    /** 引擎线程退出（正常/异常）。 */
    void exited(int code);

    void sourceReady();
    void sourceSwitched(qint64 positionMs);
    void sourceError(const QString &message);
    void sinkChanged(bool ok, const QString &err);
    void sinkStall(const QString &message);

    /** 工作线程已收尾（destroy 完成），对象可安全销毁。 */
    void stopped();

private:
    void handleEventLine(const QString &line);
    void cleanupSessionDir();

    std::thread m_thread;
    std::atomic<ArchoeraMediaEngine *> m_handle{nullptr};
    std::atomic<bool> m_quit{false};
    std::atomic<bool> m_running{false};

    bool m_playing = false;
    bool m_startedEmitted = false;
    qint64 m_durationMs = 0;
    QString m_sessionDir;
};
