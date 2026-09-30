// PlayerEngine 原生引擎实现（NEKO_HAS_AUDIO_ENGINE）。
//
// 移植自 ArchoeraMusic 的「单会话暂存源」无缝播放：
//   - 音质无缝切换：switchSourceWithoutRestart → prepare_source → source_ready
//     → commit_source → source_switched（同一会话内接管，样本级对齐）；
//   - 曲间无缝：prepareNextSource（临近曲尾预加载）→ commitPreparedNext
//     （旧源排空处接管，环形缓冲续喂，无静音间隙）。
//
// 对外 API/信号与 QMediaPlayer 实现一致，UI 无需感知底层差异。

#include "playerengine.h"

#include <QDebug>
#include <QMediaDevices>
#include <QTimer>

#include "core/audioengine.h"

PlayerEngine::PlayerEngine(QObject *parent)
    : QObject(parent)
{
    m_outputDevice = QMediaDevices::defaultAudioOutput();
}

PlayerEngine::~PlayerEngine()
{
    if (m_audio) {
        m_audio->disconnect(this);
        m_audio->stop();
    }
}

// ── 会话生命周期 ─────────────────────────────────────────────────────

void PlayerEngine::teardownEngine()
{
    if (!m_audio)
        return;
    m_audio->disconnect(this);
    m_audio->stop();
    m_audio->deleteLater();
    m_audio = nullptr;
}

float PlayerEngine::effectiveVolume() const
{
    return (m_fadingIn || m_fadingOut) ? m_fadeValue : m_targetVolume;
}

void PlayerEngine::applyEngineVolume()
{
    if (m_audio)
        m_audio->setVolume(effectiveVolume());
}

void PlayerEngine::beginSession(const QUrl &url, qint64 resumeMs)
{
    cancelFade();
    teardownEngine();

    m_pendingUrl = url;
    m_pendingResumeMs = resumeMs;
    m_durationMs = 0;
    m_positionMs = 0;
    m_hasPrepared = false;
    m_preparedReady = false;
    m_switching = false;
    m_desiredPlaying = true; // 起播默认播放（pauseWhenReady 会在此后 pause()）
    m_engineReady = false;
    m_preparedUrl = QUrl();
    m_preparedMusic = MusicInfo();

    if (url.isEmpty())
        return;

    const quint64 gen = ++m_openGen;
    m_currentUrl = url;

    auto *eng = new AudioEngine(this);
    m_audio = eng;

    connect(eng, &AudioEngine::started, this,
            [this, eng, gen](qint64 durationMs, int sampleRate, int channels,
                             int outSampleRate, const QString &backend) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                Q_UNUSED(sampleRate);
                Q_UNUSED(channels);
                Q_UNUSED(outSampleRate);
                Q_UNUSED(backend);
                m_durationMs = durationMs;
                m_engineReady = true;
                emit durationChanged(m_durationMs);
                // 恢复输出设备选择（非默认时下发引擎 sink）
                const QString sinkId = mapDeviceToSinkId(m_outputDevice);
                if (!sinkId.isNull())
                    eng->setSink(sinkId);
                applyEngineVolume();
                if (m_desiredPlaying)
                    eng->play();
                else
                    eng->pause();
            });

    connect(eng, &AudioEngine::startFailed, this,
            [this, eng, gen](const QString &msg) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                qWarning() << "[PlayerEngine] 引擎启动失败:" << msg;
                emit mediaError(msg);
                m_state = Stopped;
                emit stateChanged(m_state);
                emit mediaPlaybackStateChanged();
            });

    connect(eng, &AudioEngine::playingChanged, this,
            [this, eng, gen](bool playing, qint64 durationMs) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                if (!playing)
                    return;
                // 就绪后若用户已请求暂停（pauseWhenReady 早于起播），立即暂停并保持。
                if (!m_desiredPlaying) {
                    eng->pause();
                    return;
                }
                if (durationMs > 0 && durationMs != m_durationMs) {
                    m_durationMs = durationMs;
                    emit durationChanged(m_durationMs);
                }
                m_state = Playing;
                if (m_currentMusic.id > 0 || m_currentMusic.isLocalFile())
                    emit musicStarted(m_currentMusic);
                emit stateChanged(m_state);
                emit mediaPlaybackStateChanged();
            });

    connect(eng, &AudioEngine::positionChanged, this,
            [this, eng, gen](qint64 pos) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                m_positionMs = pos;
                emit positionChanged(pos);
            });

    connect(eng, &AudioEngine::durationChanged, this,
            [this, eng, gen](qint64 dur) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                m_durationMs = dur;
                emit durationChanged(dur);
            });

    connect(eng, &AudioEngine::playerEnded, this, [this, eng, gen]() {
        if (gen != m_openGen || eng != m_audio)
            return;
        // 曲尾兜底：若下一首已就绪但来不及按进度提交，此刻在排空处续接（仍无缝）。
        if (m_hasPrepared && m_preparedReady) {
            eng->commitSource();
            return;
        }
        m_state = Stopped;
        emit stateChanged(m_state);
        emit mediaPlaybackStateChanged();
        emit playbackFinished();
    });

    connect(eng, &AudioEngine::errorOccurred, this,
            [this, eng, gen](const QString &msg) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                emit mediaError(msg);
            });

    connect(eng, &AudioEngine::sourceReady, this, [this, eng, gen]() {
        if (gen != m_openGen || eng != m_audio)
            return;
        // 音质无缝切换：就绪即自动接管；曲间无缝由 commitPreparedNext 显式触发。
        if (m_switching)
            eng->commitSource();
        else if (m_hasPrepared)
            m_preparedReady = true;
    });

    connect(eng, &AudioEngine::sourceSwitched, this,
            [this, eng, gen](qint64 positionMs) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                if (m_switching) {
                    // 音质切换：曲目不变，仅底层源替换。
                    m_switching = false;
                    m_preparedReady = false;
                    m_currentUrl = m_preparedUrl;
                    m_preparedUrl = QUrl();
                    emit mediaPlaybackStateChanged();
                    qDebug() << "[PlayerEngine] 音质无缝切换完成 pos=" << positionMs;
                } else if (m_hasPrepared) {
                    // 曲间无缝：元数据/时长切到下一首。
                    const MusicInfo next = m_preparedMusic;
                    m_hasPrepared = false;
                    m_preparedReady = false;
                    m_currentUrl = m_preparedUrl;
                    m_preparedUrl = QUrl();
                    m_preparedMusic = MusicInfo();
                    if (next.duration > 0) {
                        m_durationMs = static_cast<qint64>(next.duration) * 1000;
                        emit durationChanged(m_durationMs);
                    }
                    qDebug() << "[PlayerEngine] 曲间无缝接管 pos=" << positionMs
                             << "next=" << next.title;
                    emit transitionedToNext(next);
                }
            });

    connect(eng, &AudioEngine::sourceError, this,
            [this, eng, gen](const QString &msg) {
                if (gen != m_openGen || eng != m_audio)
                    return;
                qWarning() << "[PlayerEngine] 暂存源错误:" << msg;
                m_switching = false;
                m_hasPrepared = false;
                m_preparedReady = false;
            });

    connect(eng, &AudioEngine::sinkChanged, this, [](bool ok, const QString &err) {
        if (!ok)
            qWarning() << "[PlayerEngine] 输出设备切换失败:" << err;
    });

    connect(eng, &AudioEngine::stopped, eng, &QObject::deleteLater);

    AudioEngine::Config cfg;
    cfg.startOffsetMs = resumeMs > 0 ? resumeMs : 0;
    cfg.outputSampleRate = 0; // passthrough（跟随源）
    cfg.outputChannels = 2;
    cfg.skipEncoder = true;
    cfg.noDiskCache = 0; // 保持文件模式，不改动既有缓存/落盘策略
    m_audio->start(url.toString(), cfg);
}

// ── 播放控制 ─────────────────────────────────────────────────────────

void PlayerEngine::play(const QUrl &url)
{
    beginSession(url, -1);
}

void PlayerEngine::playLocalResuming(const QString &localPath, qint64 resumeMs)
{
    beginSession(QUrl::fromLocalFile(localPath), resumeMs);
}

void PlayerEngine::playResuming(const QUrl &url, qint64 resumeMs)
{
    beginSession(url, resumeMs);
}

void PlayerEngine::switchSourceWithoutRestart(const QUrl &url)
{
    if (url.isEmpty())
        return;
    if (!m_audio) {
        // 无会话：退回普通加载（断点续播）。
        beginSession(url, m_positionMs > 0 ? m_positionMs : -1);
        return;
    }
    cancelFade();
    m_switching = true;
    m_hasPrepared = false;
    m_preparedReady = false;
    m_preparedMusic = MusicInfo();
    m_preparedUrl = url;
    m_audio->prepareSource(url.toString(), /*nextTrack=*/false);
}

void PlayerEngine::prepareNextSource(const QUrl &url, const MusicInfo &music)
{
    if (!m_audio || url.isEmpty() || m_hasPrepared || m_switching)
        return;
    m_preparedUrl = url;
    m_preparedMusic = music;
    m_hasPrepared = true;
    m_preparedReady = false;
    m_audio->prepareSource(url.toString(), /*nextTrack=*/true);
}

void PlayerEngine::commitPreparedNext()
{
    if (!m_audio || !m_hasPrepared)
        return;
    m_audio->commitSource();
}

bool PlayerEngine::hasPreparedNext() const
{
    return m_hasPrepared && m_audio != nullptr;
}

bool PlayerEngine::isPreparedNextReady() const
{
    return m_hasPrepared && m_preparedReady && m_audio != nullptr;
}

void PlayerEngine::play()
{
    cancelFade();
    m_desiredPlaying = true;
    if (m_audio) {
        applyEngineVolume();
        m_audio->play();
        m_audio->requestStatus();
    }
    if (m_state != Playing && m_audio && m_engineReady) {
        m_state = Playing;
        emit stateChanged(m_state);
        emit mediaPlaybackStateChanged();
    }
}

void PlayerEngine::pause()
{
    cancelFade();
    m_desiredPlaying = false;
    if (m_audio) {
        m_audio->pause();
        m_audio->requestStatus();
    }
    if (m_state != Paused) {
        m_state = Paused;
        emit stateChanged(m_state);
        emit mediaPlaybackStateChanged();
    }
}

void PlayerEngine::stop()
{
    cancelFade();
    teardownEngine();
    ++m_openGen;
    m_pendingUrl = QUrl();
    m_pendingResumeMs = -1;
    m_currentUrl = QUrl();
    m_durationMs = 0;
    m_positionMs = 0;
    m_hasPrepared = false;
    m_preparedReady = false;
    m_switching = false;
    m_desiredPlaying = false;
    m_engineReady = false;
    if (m_state != Stopped) {
        m_state = Stopped;
        emit stateChanged(m_state);
        emit mediaPlaybackStateChanged();
    }
}

void PlayerEngine::setVolume(float volume)
{
    m_targetVolume = qBound(0.0f, volume, 1.0f);
    if (!m_fadingIn && !m_fadingOut)
        applyEngineVolume();
}

void PlayerEngine::setPosition(qint64 position)
{
    if (m_seekLimitMs >= 0 && position > m_seekLimitMs)
        position = m_seekLimitMs;
    if (m_audio)
        m_audio->seek(position);
    m_positionMs = position;
}

// ── 淡入淡出 ─────────────────────────────────────────────────────────

void PlayerEngine::cancelFade()
{
    if (m_fadeTimer) {
        m_fadeTimer->stop();
        delete m_fadeTimer;
        m_fadeTimer = nullptr;
    }
    m_fadingIn = false;
    m_fadingOut = false;
}

void PlayerEngine::fadeIn()
{
    cancelFade();
    m_fadingIn = true;
    m_desiredPlaying = true;
    m_fadeValue = 0.0f;
    applyEngineVolume();
    if (m_audio)
        m_audio->play();

    m_state = Playing;
    emit stateChanged(m_state);
    emit mediaPlaybackStateChanged();

    m_fadeTimer = new QTimer(this);
    connect(m_fadeTimer, &QTimer::timeout, this, &PlayerEngine::onFadeTick);
    m_fadeTimer->start(20);
}

void PlayerEngine::fadeOut()
{
    cancelFade();
    m_fadingOut = true;
    m_desiredPlaying = false;
    m_fadeValue = m_targetVolume;

    m_state = Paused;
    emit stateChanged(m_state);

    m_fadeTimer = new QTimer(this);
    connect(m_fadeTimer, &QTimer::timeout, this, &PlayerEngine::onFadeTick);
    m_fadeTimer->start(20);
}

void PlayerEngine::onFadeTick()
{
    const float step = 0.04f;

    if (m_fadingIn) {
        m_fadeValue += step;
        if (m_fadeValue >= m_targetVolume) {
            m_fadeValue = m_targetVolume;
            m_fadingIn = false;
            m_fadeTimer->stop();
            delete m_fadeTimer;
            m_fadeTimer = nullptr;
            emit fadeComplete();
        }
        applyEngineVolume();
    } else if (m_fadingOut) {
        m_fadeValue -= step;
        if (m_fadeValue <= 0.0f) {
            m_fadeValue = 0.0f;
            applyEngineVolume();
            if (m_audio)
                m_audio->pause();
            m_fadingOut = false;
            m_fadeTimer->stop();
            delete m_fadeTimer;
            m_fadeTimer = nullptr;
            emit fadeComplete();
        } else {
            applyEngineVolume();
        }
    }
}

// ── 状态查询 ─────────────────────────────────────────────────────────

PlayerEngine::PlaybackState PlayerEngine::playbackState() const
{
    return m_state;
}

bool PlayerEngine::isActuallyPlaying() const
{
    return m_audio && m_audio->isPlaying();
}

PlayerEngine::PlaybackState PlayerEngine::transportStateForOs() const
{
    if (m_fadingOut && m_audio && m_audio->isPlaying())
        return Paused;
    return m_state;
}

qint64 PlayerEngine::duration() const
{
    return m_durationMs;
}

qint64 PlayerEngine::position() const
{
    return m_positionMs;
}

QUrl PlayerEngine::currentMediaUrl() const
{
    return m_currentUrl;
}

int PlayerEngine::audioBitRateBps() const
{
    // 原生引擎解码侧不暴露源码率（保留接口：0 表示未知）。
    return 0;
}

float PlayerEngine::volume() const
{
    return effectiveVolume();
}

void PlayerEngine::setCurrentMusic(const MusicInfo& music)
{
    m_currentMusic = music;
}

// ── 输出设备 ─────────────────────────────────────────────────────────

QAudioDevice PlayerEngine::outputDevice() const
{
    return m_outputDevice;
}

QString PlayerEngine::mapDeviceToSinkId(const QAudioDevice &device)
{
    if (device.isNull())
        return QString();
    const QByteArray qtId = device.id();
    const QString name = device.description();
    const QVector<AudioEngine::Sink> sinks = AudioEngine::listSinks();
    for (const auto &s : sinks) {
        if (!qtId.isEmpty() && s.id == QString::fromUtf8(qtId))
            return s.id;
    }
    for (const auto &s : sinks) {
        if (!name.isEmpty() && s.name == name)
            return s.id;
    }
    return QString();
}

void PlayerEngine::setOutputDevice(const QAudioDevice &device)
{
    if (device.isNull())
        return;
    m_outputDevice = device;
    if (!m_audio)
        return;
    const QString sinkId = mapDeviceToSinkId(device);
    if (!sinkId.isNull())
        m_audio->setSink(sinkId);
    else
        m_audio->setSink(QString()); // 回默认输出
}
