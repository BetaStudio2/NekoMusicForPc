#include "micsynccontroller.h"

#include <QList>
#include <QProcess>
#include <QStandardPaths>
#include <QStringList>

namespace {

constexpr char kBusSink[] = "nekomusic_mic_bus";
constexpr char kCombinedSource[] = "nekomusic_mic";
constexpr char kDeviceDescription[] = "NekoMusicMic";
constexpr char kBusDescription[] = "NekoMusicMicBus";

struct PactlResult
{
    bool started = false;
    int exitCode = -1;
    QString out;
    QString err;

    bool ok() const { return started && exitCode == 0; }
};

PactlResult runPactl(const QStringList &args)
{
    PactlResult result;
    QProcess proc;
    proc.start(QStringLiteral("pactl"), args);
    if (!proc.waitForStarted(3000))
        return result;
    result.started = true;
    if (!proc.waitForFinished(8000)) {
        proc.kill();
        proc.waitForFinished(1000);
        result.err = QStringLiteral("pactl timeout");
        return result;
    }
    result.exitCode = proc.exitCode();
    result.out = QString::fromLocal8Bit(proc.readAllStandardOutput());
    result.err = QString::fromLocal8Bit(proc.readAllStandardError());
    return result;
}

bool pactlAvailable()
{
    static const bool available = !QStandardPaths::findExecutable(QStringLiteral("pactl")).isEmpty();
    return available;
}

/** 已加载的模块索引，按加载顺序保存，卸载时反序。 */
QList<int> &loadedModules()
{
    static QList<int> modules;
    return modules;
}

/** 开启前的默认输入设备，关闭时还原。 */
QString &savedDefaultSource()
{
    static QString source;
    return source;
}

void unloadModule(int index)
{
    if (index >= 0)
        runPactl({QStringLiteral("unload-module"), QString::number(index)});
}

void unloadAllLoaded()
{
    QList<int> &modules = loadedModules();
    for (int i = modules.size() - 1; i >= 0; --i)
        unloadModule(modules[i]);
    modules.clear();
}

/** 清理上次异常退出遗留的同名模块。 */
void removeLeftoverModules()
{
    const PactlResult result = runPactl({QStringLiteral("list"), QStringLiteral("short"),
                                         QStringLiteral("modules")});
    if (!result.ok())
        return;

    const QStringList lines = result.out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList fields = line.split(QLatin1Char('\t'), Qt::SkipEmptyParts);
        if (fields.size() < 3)
            continue;
        const QString moduleName = fields.at(1);
        const QString args = fields.mid(2).join(QLatin1Char(' '));
        const bool ours = (moduleName == QStringLiteral("module-null-sink")
                           && args.contains(QStringLiteral("sink_name=%1").arg(QLatin1String(kBusSink))))
                          || (moduleName == QStringLiteral("module-loopback")
                              && args.contains(QLatin1String(kBusSink)))
                          || (moduleName == QStringLiteral("module-remap-source")
                              && args.contains(QStringLiteral("source_name=%1")
                                                   .arg(QLatin1String(kCombinedSource))));
        if (!ours)
            continue;
        bool ok = false;
        const int index = fields.at(0).toInt(&ok);
        if (ok)
            unloadModule(index);
    }
}

QString queryDefault(const QString &getArg, const QString &infoPrefix)
{
    const PactlResult direct = runPactl({getArg});
    if (direct.ok()) {
        const QString name = direct.out.trimmed();
        if (!name.isEmpty())
            return name;
    }

    const PactlResult info = runPactl({QStringLiteral("info")});
    if (!info.ok())
        return {};
    const QStringList lines = info.out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.startsWith(infoPrefix))
            return trimmed.section(QLatin1Char(':'), 1).trimmed();
    }
    return {};
}

QString defaultSinkName()
{
    return queryDefault(QStringLiteral("get-default-sink"), QStringLiteral("Default Sink:"));
}

/** 选取一个真实麦克风源：默认输入优先，若默认已是我们的混音源则退回第一个非 monitor 源。 */
QString realMicSource()
{
    const QString current = queryDefault(QStringLiteral("get-default-source"),
                                         QStringLiteral("Default Source:"));
    if (!current.isEmpty() && current != QLatin1String(kCombinedSource)
        && !current.endsWith(QLatin1String(".monitor")))
        return current;

    const PactlResult list = runPactl({QStringLiteral("list"), QStringLiteral("short"),
                                       QStringLiteral("sources")});
    if (!list.ok())
        return {};
    const QStringList lines = list.out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList fields = line.split(QLatin1Char('\t'), Qt::SkipEmptyParts);
        if (fields.size() < 2)
            continue;
        const QString name = fields.at(1);
        if (!name.endsWith(QLatin1String(".monitor")) && name != QLatin1String(kCombinedSource))
            return name;
    }
    return {};
}

} // namespace

bool nekoMicSyncBackendAvailable()
{
    return pactlAvailable();
}

void nekoMicSyncBackendSetPlayer(PlayerEngine *)
{
    // Linux 通过 PulseAudio/PipeWire 混音，无需改动播放器输出设备。
}

QString nekoMicSyncBackendDeviceLabel()
{
    return QStringLiteral("NekoMusicMic");
}

QString nekoMicSyncBackendHintKey()
{
    return pactlAvailable() ? QStringLiteral("micSyncHint")
                            : QStringLiteral("micSyncUnsupportedHint");
}

bool nekoMicSyncBackendStart(QString *error)
{
    auto fail = [error](const QString &message) {
        if (error)
            *error = message;
        return false;
    };

    if (!pactlAvailable())
        return fail(QStringLiteral("未找到 pactl，请安装 PulseAudio / pipewire-pulse"));

    removeLeftoverModules();
    unloadAllLoaded();

    const QString sink = defaultSinkName();
    if (sink.isEmpty())
        return fail(QStringLiteral("无法获取默认音频输出设备"));

    const QString mic = realMicSource();
    if (mic.isEmpty())
        return fail(QStringLiteral("无法获取默认麦克风输入设备"));

    auto load = [&](const QStringList &args, const QString &what) -> int {
        const PactlResult result = runPactl(QStringList{QStringLiteral("load-module")} + args);
        bool ok = false;
        const int index = result.out.trimmed().toInt(&ok);
        if (!result.ok() || !ok) {
            const QString detail = result.err.trimmed();
            if (error)
                *error = detail.isEmpty() ? what : QStringLiteral("%1：%2").arg(what, detail);
            return -1;
        }
        return index;
    };

    auto rollback = [&]() {
        unloadAllLoaded();
        removeLeftoverModules();
    };

    const int busModule =
        load({QStringLiteral("module-null-sink"), QStringLiteral("sink_name=%1").arg(QLatin1String(kBusSink)),
              QStringLiteral("sink_properties=device.description=%1").arg(QLatin1String(kBusDescription))},
             QStringLiteral("创建音频混音总线失败"));
    if (busModule < 0) {
        rollback();
        return false;
    }
    loadedModules().append(busModule);

    const int micModule =
        load({QStringLiteral("module-loopback"), QStringLiteral("source=%1").arg(mic),
              QStringLiteral("sink=%1").arg(QLatin1String(kBusSink)), QStringLiteral("latency_msec=20"),
              QStringLiteral("source_dont_move=true"), QStringLiteral("sink_dont_move=true")},
             QStringLiteral("把麦克风接入混音总线失败"));
    if (micModule < 0) {
        rollback();
        return false;
    }
    loadedModules().append(micModule);

    const int musicModule =
        load({QStringLiteral("module-loopback"), QStringLiteral("source=%1.monitor").arg(sink),
              QStringLiteral("sink=%1").arg(QLatin1String(kBusSink)), QStringLiteral("latency_msec=20"),
              QStringLiteral("source_dont_move=true"), QStringLiteral("sink_dont_move=true")},
             QStringLiteral("把播放声音接入混音总线失败"));
    if (musicModule < 0) {
        rollback();
        return false;
    }
    loadedModules().append(musicModule);

    const int remapModule =
        load({QStringLiteral("module-remap-source"),
              QStringLiteral("master=%1.monitor").arg(QLatin1String(kBusSink)),
              QStringLiteral("source_name=%1").arg(QLatin1String(kCombinedSource)),
              QStringLiteral("source_properties=device.description=%1").arg(QLatin1String(kDeviceDescription))},
             QStringLiteral("注册混音后的麦克风失败"));
    if (remapModule < 0) {
        rollback();
        return false;
    }
    loadedModules().append(remapModule);

    savedDefaultSource() = mic;
    runPactl({QStringLiteral("set-default-source"), QLatin1String(kCombinedSource)});
    return true;
}

void nekoMicSyncBackendStop()
{
    const QString previous = savedDefaultSource();
    if (!previous.isEmpty())
        runPactl({QStringLiteral("set-default-source"), previous});
    savedDefaultSource().clear();

    unloadAllLoaded();
    if (pactlAvailable())
        removeLeftoverModules();
}
