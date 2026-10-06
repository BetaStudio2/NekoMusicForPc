#include "audioengine.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>

#include <cstring>
#include <vector>

#include "archoera_mediaengine.h"

namespace {
constexpr int kEventBufCap = 2048;
constexpr int kWaitTimeoutMs = 80;

QString makeSessionDir()
{
    static std::atomic<quint64> s_seq{0};
    const QString dir = QDir::tempPath()
        + QStringLiteral("/neko-archoera-%1-%2-%3")
              .arg(QCoreApplication::applicationPid())
              .arg(QDateTime::currentMSecsSinceEpoch())
              .arg(s_seq.fetch_add(1));
    return dir;
}
} // namespace

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent)
{
}

AudioEngine::~AudioEngine()
{
    m_quit.store(true);
    if (m_thread.joinable())
        m_thread.join();
    m_handle.store(nullptr);
    cleanupSessionDir();
}

void AudioEngine::cleanupSessionDir()
{
    if (m_sessionDir.isEmpty())
        return;
    QDir(m_sessionDir).removeRecursively();
    m_sessionDir.clear();
}

void AudioEngine::start(const QString &source, const Config &cfg)
{
    if (m_thread.joinable() || source.isEmpty())
        return;

    m_quit.store(false);
    m_running.store(false);
    m_startedEmitted = false;
    m_playing = false;
    m_durationMs = 0;

    m_sessionDir = makeSessionDir();
    QDir().mkpath(m_sessionDir);

    const std::string src = source.toUtf8().toStdString();
    const std::string sessionDir = m_sessionDir.toUtf8().toStdString();
    const std::string playerFile =
        (m_sessionDir + QStringLiteral("/stream.wav")).toUtf8().toStdString();

    EngineConfig engineCfg = ENGINE_CONFIG_DEFAULT;
    engineCfg.start_offset_ms = cfg.startOffsetMs;
    engineCfg.output_sample_rate = cfg.outputSampleRate;
    engineCfg.output_channels = cfg.outputChannels > 0 ? cfg.outputChannels : 2;
    engineCfg.bitrate = cfg.bitrate;
    engineCfg.skip_encoder = cfg.skipEncoder;
#if defined(HAS_ARCHOERA_KERNEL)
    // EraAudio Zig 解码内核已链接：默认“原生优先”（逐格式接管，遇到未支持/失败的
    // 格式由引擎内部自动回退 FFmpeg）。可用环境变量 NEKO_ERAUDIO=0 在运行时强制 FFmpeg。
    {
        const QByteArray eraEnv = qgetenv("NEKO_ERAUDIO");
        const bool disable = !eraEnv.isEmpty() && eraEnv.toInt() == 0;
        engineCfg.engine_mode = disable ? 0 : 1;
    }
#else
    engineCfg.engine_mode = 0; // 未链接 Zig 内核：恒 FFmpeg
#endif
    engineCfg.no_disk_cache = cfg.noDiskCache;
    engineCfg.pcm_mem_cap_kb = cfg.pcmMemCapKb;

    m_thread = std::thread([this, src, sessionDir, playerFile, engineCfg]() {
        char err[512] = {0};
        ArchoeraMediaEngine *e = archoera_mediaengine_create(
            src.c_str(), &engineCfg, playerFile.c_str(), sessionDir.c_str(),
            err, static_cast<int>(sizeof(err)));
        if (!e) {
            const QString msg = QStringLiteral("引擎创建失败: %1")
                                    .arg(QString::fromUtf8(err));
            QMetaObject::invokeMethod(this, [this, msg]() {
                emit startFailed(msg);
                emit stopped();
            }, Qt::QueuedConnection);
            return;
        }
        m_handle.store(e);
        m_running.store(true);

        std::vector<char> buf(kEventBufCap);
        while (!m_quit.load()) {
            const int r = archoera_mediaengine_wait_event(
                e, buf.data(), kEventBufCap, kWaitTimeoutMs);
            if (r > 0) {
                const QString line = QString::fromUtf8(buf.data(), r);
                QMetaObject::invokeMethod(this, [this, line]() {
                    handleEventLine(line);
                }, Qt::QueuedConnection);
            } else if (r < 0) {
                break; // 已销毁
            }
        }

        archoera_mediaengine_destroy(e);
        m_handle.store(nullptr);
        m_running.store(false);
        QMetaObject::invokeMethod(this, [this]() {
            emit stopped();
        }, Qt::QueuedConnection);
    });
}

void AudioEngine::stop()
{
    m_quit.store(true);
}

void AudioEngine::play()
{
    if (auto *e = m_handle.load())
        archoera_mediaengine_command(e, "{\"type\":\"play\"}");
}

void AudioEngine::pause()
{
    if (auto *e = m_handle.load())
        archoera_mediaengine_command(e, "{\"type\":\"pause\"}");
}

void AudioEngine::seek(qint64 positionMs)
{
    if (auto *e = m_handle.load()) {
        const QByteArray cmd = QStringLiteral("{\"type\":\"seek\",\"position_ms\":%1}")
                                   .arg(positionMs).toUtf8();
        archoera_mediaengine_command(e, cmd.constData());
    }
}

void AudioEngine::setVolume(float gain)
{
    if (auto *e = m_handle.load()) {
        const QByteArray cmd = QStringLiteral("{\"type\":\"set_volume\",\"gain\":%1}")
                                   .arg(static_cast<double>(gain), 0, 'f', 4).toUtf8();
        archoera_mediaengine_command(e, cmd.constData());
    }
}

void AudioEngine::setSink(const QString &sinkId)
{
    if (auto *e = m_handle.load()) {
        const QJsonObject o{{QStringLiteral("type"), QStringLiteral("set_sink")},
                            {QStringLiteral("id"), sinkId}};
        const QByteArray cmd = QJsonDocument(o).toJson(QJsonDocument::Compact);
        archoera_mediaengine_command(e, cmd.constData());
    }
}

void AudioEngine::setEventInterval(int intervalMs)
{
    if (auto *e = m_handle.load()) {
        const QByteArray cmd = QStringLiteral("{\"type\":\"set_event_interval\",\"interval_ms\":%1}")
                                   .arg(intervalMs).toUtf8();
        archoera_mediaengine_command(e, cmd.constData());
    }
}

void AudioEngine::requestStatus()
{
    if (auto *e = m_handle.load())
        archoera_mediaengine_command(e, "{\"type\":\"get_status\"}");
}

void AudioEngine::prepareSource(const QString &url, bool nextTrack)
{
    if (auto *e = m_handle.load()) {
        QJsonObject o{{QStringLiteral("type"), QStringLiteral("prepare_source")},
                      {QStringLiteral("url"), url}};
        if (nextTrack)
            o.insert(QStringLiteral("next_track"), true);
        const QByteArray cmd = QJsonDocument(o).toJson(QJsonDocument::Compact);
        archoera_mediaengine_command(e, cmd.constData());
    }
}

void AudioEngine::commitSource()
{
    if (auto *e = m_handle.load())
        archoera_mediaengine_command(e, "{\"type\":\"commit_source\"}");
}

void AudioEngine::handleEventLine(const QString &line)
{
    QJsonParseError perr{};
    const QJsonDocument doc = QJsonDocument::fromJson(line.toUtf8(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return;
    const QJsonObject o = doc.object();
    const QString type = o.value(QStringLiteral("type")).toString();

    if (type == QLatin1String("ready")) {
        const int outRate = o.value(QStringLiteral("out_sample_rate")).toInt(
            o.value(QStringLiteral("sample_rate")).toInt());
        m_durationMs = static_cast<qint64>(o.value(QStringLiteral("duration_ms")).toDouble());
        if (!m_startedEmitted) {
            m_startedEmitted = true;
            emit started(
                m_durationMs,
                o.value(QStringLiteral("sample_rate")).toInt(),
                o.value(QStringLiteral("channels")).toInt(),
                outRate,
                o.value(QStringLiteral("backend")).toString());
        }
        emit durationChanged(m_durationMs);
    } else if (type == QLatin1String("status")) {
        const qint64 dur = static_cast<qint64>(o.value(QStringLiteral("duration_ms")).toDouble());
        if (dur > 0 && dur != m_durationMs) {
            m_durationMs = dur;
            emit durationChanged(dur);
        }
        emit positionChanged(static_cast<qint64>(o.value(QStringLiteral("position_ms")).toDouble()));
        if (o.contains(QStringLiteral("playing"))) {
            const bool playing = o.value(QStringLiteral("playing")).toBool();
            if (playing != m_playing) {
                m_playing = playing;
                emit playingChanged(playing, m_durationMs);
            }
        }
    } else if (type == QLatin1String("playing")) {
        const qint64 dur = static_cast<qint64>(o.value(QStringLiteral("duration_ms")).toDouble());
        if (dur > 0)
            m_durationMs = dur;
        m_playing = true;
        emit playingChanged(true, m_durationMs);
    } else if (type == QLatin1String("position")) {
        emit positionChanged(static_cast<qint64>(o.value(QStringLiteral("position_ms")).toDouble()));
    } else if (type == QLatin1String("done")) {
        emit contentDone();
    } else if (type == QLatin1String("player:ended")) {
        m_playing = false;
        emit playerEnded();
    } else if (type == QLatin1String("source_ready")) {
        emit sourceReady();
    } else if (type == QLatin1String("source_switched")) {
        emit sourceSwitched(static_cast<qint64>(o.value(QStringLiteral("position_ms")).toDouble()));
    } else if (type == QLatin1String("source_error")) {
        emit sourceError(o.value(QStringLiteral("message")).toString());
    } else if (type == QLatin1String("sink_changed")) {
        emit sinkChanged(o.value(QStringLiteral("ok")).toBool(),
                         o.value(QStringLiteral("err")).toString());
    } else if (type == QLatin1String("sink_stall")) {
        emit sinkStall(o.value(QStringLiteral("message")).toString());
    } else if (type == QLatin1String("error")) {
        const QString msg = o.value(QStringLiteral("message")).toString();
        if (!m_startedEmitted) {
            m_startedEmitted = true;
            emit startFailed(msg);
        }
        emit errorOccurred(msg);
    } else if (type == QLatin1String("exited")) {
        emit exited(o.value(QStringLiteral("code")).toInt());
    }
}

QVector<AudioEngine::Sink> AudioEngine::listSinks()
{
    QVector<Sink> sinks;
    std::vector<char> buf(16384);
    const int n = archoera_mediaengine_list_sinks(buf.data(), static_cast<int>(buf.size()));
    if (n <= 0)
        return sinks;
    const QJsonDocument doc = QJsonDocument::fromJson(QByteArray(buf.data(), n));
    if (!doc.isArray())
        return sinks;
    for (const QJsonValue &v : doc.array()) {
        const QJsonObject o = v.toObject();
        Sink s;
        s.id = o.value(QStringLiteral("id")).toString();
        s.name = o.value(QStringLiteral("name")).toString();
        s.isDefault = o.value(QStringLiteral("default")).toBool();
        sinks.append(s);
    }
    return sinks;
}
