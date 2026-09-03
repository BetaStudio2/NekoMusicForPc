#include "core/landevicemanager.h"

#include "core/playlistmanager.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include <QCryptographicHash>
#include <QDateTime>
#include <QHostAddress>
#include <QHostInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkDatagram>
#include <QNetworkInterface>
#include <QRandomGenerator>
#include <QSettings>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QUdpSocket>
#include <algorithm>
#include <utility>

namespace {
constexpr quint16 kDiscoveryPort = 39393;
const QHostAddress kDiscoveryGroup(QStringLiteral("239.255.77.77"));
constexpr int kProtocol = 1;
constexpr int kDeviceTimeoutMs = 15'000;

QNetworkInterface multicastInterface()
{
    QNetworkInterface fallback;
    int fallbackScore = -1;
    for (const QNetworkInterface &interfaceInfo : QNetworkInterface::allInterfaces()) {
        const auto flags = interfaceInfo.flags();
        if (!flags.testFlag(QNetworkInterface::IsUp) ||
            !flags.testFlag(QNetworkInterface::IsRunning) ||
            flags.testFlag(QNetworkInterface::IsLoopBack)) {
            continue;
        }

        bool hasIpv4 = false;
        for (const QNetworkAddressEntry &entry : interfaceInfo.addressEntries()) {
            if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol &&
                !entry.ip().isLoopback()) {
                hasIpv4 = true;
                break;
            }
        }
        if (!hasIpv4)
            continue;

        const QString name = interfaceInfo.humanReadableName().toLower();
        int score = 1;
        if (name.contains(QStringLiteral("wlan")) ||
            name.contains(QStringLiteral("wifi")) ||
            name.startsWith(QStringLiteral("en")) ||
            name.startsWith(QStringLiteral("eth"))) {
            score += 4;
        }
        if (name.contains(QStringLiteral("docker")) ||
            name.contains(QStringLiteral("virbr")) ||
            name.contains(QStringLiteral("veth")) ||
            name.contains(QStringLiteral("tailscale"))) {
            score -= 4;
        }
        if (score > fallbackScore) {
            fallback = interfaceInfo;
            fallbackScore = score;
        }
    }
    return fallback;
}
}

LanDeviceManager &LanDeviceManager::instance()
{
    static LanDeviceManager manager;
    return manager;
}

LanDeviceManager::LanDeviceManager(QObject *parent)
    : QObject(parent)
    , m_server(new QTcpServer(this))
    , m_udp(new QUdpSocket(this))
    , m_remoteSocket(new QTcpSocket(this))
    , m_announceTimer(new QTimer(this))
    , m_expireTimer(new QTimer(this))
    , m_broadcastTimer(new QTimer(this))
    , m_remoteReconnectTimer(new QTimer(this))
{
    m_announceTimer->setInterval(5'000);
    m_expireTimer->setInterval(5'000);
    m_broadcastTimer->setSingleShot(true);
    m_broadcastTimer->setInterval(50);
    m_remoteReconnectTimer->setSingleShot(true);
    m_remoteReconnectTimer->setInterval(1'000);

    connect(m_server, &QTcpServer::newConnection, this, &LanDeviceManager::handleServerConnection);
    connect(m_udp, &QUdpSocket::readyRead, this, [this]() {
        while (m_udp->hasPendingDatagrams()) {
            const QNetworkDatagram datagram = m_udp->receiveDatagram();
            receiveAnnouncement(datagram.data(), datagram.senderAddress().toString());
        }
    });
    connect(m_announceTimer, &QTimer::timeout, this, &LanDeviceManager::sendAnnouncement);
    connect(m_expireTimer, &QTimer::timeout, this, &LanDeviceManager::expireDevices);
    connect(m_broadcastTimer, &QTimer::timeout, this, &LanDeviceManager::broadcastQueue);
    connect(m_remoteReconnectTimer, &QTimer::timeout, this, [this]() {
        if (!m_selectedDeviceId.isEmpty() && m_running)
            connectRemote();
    });

    // Keep the remote subscription alive across transient Wi-Fi changes or
    // when the peer briefly restarts its LAN listener.
    connect(m_remoteSocket, &QTcpSocket::connected, this, &LanDeviceManager::sendSubscribe);
    connect(m_remoteSocket, &QTcpSocket::readyRead, this, &LanDeviceManager::handleRemoteData);
    connect(m_remoteSocket, &QTcpSocket::disconnected, this, [this]() {
        emit remoteConnectionChanged(false);
        scheduleRemoteReconnect();
    });
    connect(m_remoteSocket, &QTcpSocket::errorOccurred, this,
            [this](QAbstractSocket::SocketError) {
                emit remoteConnectionChanged(false);
                scheduleRemoteReconnect();
            });

    connect(&PlaylistManager::instance(), &PlaylistManager::playlistChanged,
            this, &LanDeviceManager::scheduleQueueBroadcast);
    connect(&PlaylistManager::instance(), &PlaylistManager::currentIndexChanged,
            this, &LanDeviceManager::scheduleQueueBroadcast);
    connect(&PlaylistManager::instance(), &PlaylistManager::playModeChanged,
            this, &LanDeviceManager::scheduleQueueBroadcast);
}

void LanDeviceManager::setPlayerState(int currentMusicId, bool isPlaying)
{
    if (m_playerMusicId == currentMusicId && m_playerPlaying == isPlaying)
        return;
    m_playerMusicId = currentMusicId;
    m_playerPlaying = isPlaying;
    scheduleQueueBroadcast();
}

void LanDeviceManager::setAccountUserId(int userId)
{
    if (m_accountUserId == userId)
        return;
    const bool wasRunning = m_running;
    if (wasRunning)
        stop();
    m_accountUserId = userId;
    if (wasRunning)
        start();
}

void LanDeviceManager::start()
{
    if (m_accountUserId <= 0)
        return;  // 未登录不参与局域网同步

    const QString currentAccountTag = accountTag();
    if (m_running && m_runningAccountTag == currentAccountTag)
        return;
    if (m_running)
        stop();

    if (!m_server->listen(QHostAddress::AnyIPv4, 0)) {
        qWarning("LAN queue server listen failed: %s", qPrintable(m_server->errorString()));
        return;
    }
    if (!m_udp->bind(QHostAddress::AnyIPv4, kDiscoveryPort,
                     QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qWarning("LAN discovery bind failed: %s", qPrintable(m_udp->errorString()));
        m_server->close();
        return;
    }
    const QNetworkInterface interfaceInfo = multicastInterface();
    if (interfaceInfo.isValid()) {
        m_udp->setMulticastInterface(interfaceInfo);
        m_udp->joinMulticastGroup(kDiscoveryGroup, interfaceInfo);
    } else {
        m_udp->joinMulticastGroup(kDiscoveryGroup);
    }
    m_running = true;
    m_runningAccountTag = currentAccountTag;
    m_revision++;
    m_announceTimer->start();
    m_expireTimer->start();
    sendAnnouncement();
}

void LanDeviceManager::stop()
{
    if (!m_running && !m_remoteSocket->isOpen() &&
        !m_remoteReconnectTimer->isActive() && m_devices.isEmpty())
        return;

    closeRemote();
    for (QTcpSocket *socket : std::as_const(m_subscribers)) {
        socket->disconnect(this);
        socket->disconnectFromHost();
        socket->deleteLater();
    }
    m_subscribers.clear();
    if (m_udp->state() == QAbstractSocket::BoundState)
        m_udp->leaveMulticastGroup(kDiscoveryGroup);
    m_udp->close();
    m_server->close();
    m_announceTimer->stop();
    m_expireTimer->stop();
    m_broadcastTimer->stop();
    m_running = false;
    m_devices.clear();
    m_remoteQueue = {};
    m_selectedDeviceId.clear();
    m_runningAccountTag.clear();
    emit devicesChanged();
    emit remoteQueueChanged();
    emit remoteConnectionChanged(false);
}

void LanDeviceManager::sendAnnouncement()
{
    if (!m_running || !m_udp->isOpen())
        return;

    const LanQueueSnapshotInfo snapshot = buildSnapshot();
    QJsonObject object{
        {QStringLiteral("protocol"), kProtocol},
        {QStringLiteral("type"), QStringLiteral("announce")},
        {QStringLiteral("deviceId"), deviceId()},
        {QStringLiteral("deviceName"), deviceName()},
        {QStringLiteral("platform"), QStringLiteral("pc")},
        {QStringLiteral("port"), static_cast<int>(m_server->serverPort())},
        {QStringLiteral("accountTag"), accountTag()},
        {QStringLiteral("queueRevision"), snapshot.revision},
        {QStringLiteral("queueCount"), snapshot.items.size()},
        {QStringLiteral("currentMusicId"), snapshot.currentMusicId},
        {QStringLiteral("timestamp"), QDateTime::currentMSecsSinceEpoch()}
    };
    const QByteArray data = QJsonDocument(object).toJson(QJsonDocument::Compact);
    m_udp->writeDatagram(data, kDiscoveryGroup, kDiscoveryPort);
    // Some access points isolate multicast in one direction. Broadcast is a
    // fallback for peers on the same IPv4 LAN.
    m_udp->writeDatagram(data, QHostAddress::Broadcast, kDiscoveryPort);
}

void LanDeviceManager::receiveAnnouncement(const QByteArray &payload, const QString &host)
{
    const QJsonDocument document = QJsonDocument::fromJson(payload);
    if (!document.isObject())
        return;
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("protocol")).toInt() != kProtocol ||
        object.value(QStringLiteral("type")).toString() != QStringLiteral("announce") ||
        object.value(QStringLiteral("accountTag")).toString() != accountTag())
        return;

    LanDeviceInfo device;
    device.deviceId = object.value(QStringLiteral("deviceId")).toString();
    device.deviceName = object.value(QStringLiteral("deviceName")).toString();
    device.platform = object.value(QStringLiteral("platform")).toString();
    device.host = host;
    device.port = static_cast<quint16>(object.value(QStringLiteral("port")).toInt());
    device.accountTag = object.value(QStringLiteral("accountTag")).toString();
    device.queueRevision = object.value(QStringLiteral("queueRevision")).toInteger();
    device.queueCount = object.value(QStringLiteral("queueCount")).toInt();
    device.currentMusicId = object.value(QStringLiteral("currentMusicId")).toInt();
    device.lastSeen = QDateTime::currentMSecsSinceEpoch();

    if (device.deviceId.isEmpty() || device.deviceId == deviceId() || device.port == 0)
        return;

    bool changed = false;
    for (LanDeviceInfo &existing : m_devices) {
        if (existing.deviceId == device.deviceId) {
            changed = existing.host != device.host ||
                existing.port != device.port ||
                existing.deviceName != device.deviceName ||
                existing.queueRevision != device.queueRevision ||
                existing.queueCount != device.queueCount ||
                existing.currentMusicId != device.currentMusicId;
            existing = device;
            if (changed)
                publishDevices();
            return;
        }
    }
    m_devices.append(device);
    emit deviceDiscovered(device.deviceName);
    publishDevices();
}

void LanDeviceManager::expireDevices()
{
    const qint64 cutoff = QDateTime::currentMSecsSinceEpoch() - kDeviceTimeoutMs;
    bool changed = false;
    for (int i = m_devices.size() - 1; i >= 0; --i) {
        if (m_devices.at(i).lastSeen < cutoff) {
            emit deviceDisconnected(m_devices.at(i).deviceName);
            if (m_devices.at(i).deviceId == m_selectedDeviceId) {
                m_selectedDeviceId.clear();
                closeRemote();
            }
            m_devices.removeAt(i);
            changed = true;
        }
    }
    if (changed)
        publishDevices();
}

void LanDeviceManager::handleServerConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *socket = m_server->nextPendingConnection();
        m_subscribers.append(socket);
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
            handleServerData(socket);
        });
        connect(socket, &QTcpSocket::disconnected, this, [this, socket]() {
            m_subscribers.removeAll(socket);
            socket->deleteLater();
        });
    }
}

void LanDeviceManager::handleServerData(QTcpSocket *socket)
{
    while (socket->canReadLine()) {
        const QByteArray line = socket->readLine().trimmed();
        const QJsonDocument document = QJsonDocument::fromJson(line);
        if (!document.isObject())
            continue;
        const QJsonObject object = document.object();
        if (!socket->property("lanSubscribed").toBool()) {
            if (object.value(QStringLiteral("type")).toString() != QStringLiteral("subscribe") ||
                object.value(QStringLiteral("accountTag")).toString() != accountTag()) {
                socket->disconnectFromHost();
                return;
            }
            socket->setProperty("lanSubscribed", true);
            socket->write(snapshotJson());
            socket->flush();
        } else if (object.value(QStringLiteral("type")).toString() == QStringLiteral("ping")) {
            socket->write("{\"type\":\"pong\"}\n");
            socket->flush();
        }
    }
}

void LanDeviceManager::connectRemote()
{
    closeRemote();
    for (const LanDeviceInfo &device : std::as_const(m_devices)) {
        if (device.deviceId != m_selectedDeviceId)
            continue;
        m_remoteSocket->connectToHost(device.host, device.port);
        return;
    }
    emit remoteConnectionChanged(false);
}

void LanDeviceManager::closeRemote()
{
    m_remoteReconnectTimer->stop();
    m_closingRemote = true;
    if (m_remoteSocket->state() != QAbstractSocket::UnconnectedState)
        m_remoteSocket->abort();
    m_closingRemote = false;
    m_remoteBuffer.clear();
    m_remoteQueue = {};
    emit remoteQueueChanged();
    emit remoteConnectionChanged(false);
}

void LanDeviceManager::selectDevice(const QString &deviceIdValue)
{
    if (deviceIdValue == m_selectedDeviceId)
        return;
    m_selectedDeviceId = deviceIdValue;
    if (m_selectedDeviceId.isEmpty()) {
        closeRemote();
        return;
    }
    connectRemote();
}

void LanDeviceManager::scheduleRemoteReconnect()
{
    if (m_closingRemote || !m_running || m_selectedDeviceId.isEmpty())
        return;
    if (!m_remoteReconnectTimer->isActive())
        m_remoteReconnectTimer->start();
}

void LanDeviceManager::sendSubscribe()
{
    QJsonObject object{
        {QStringLiteral("protocol"), kProtocol},
        {QStringLiteral("type"), QStringLiteral("subscribe")},
        {QStringLiteral("accountTag"), accountTag()},
        {QStringLiteral("deviceId"), deviceId()},
        {QStringLiteral("deviceName"), deviceName()},
        {QStringLiteral("platform"), QStringLiteral("pc")},
        {QStringLiteral("port"), static_cast<int>(m_server->serverPort())}
    };
    m_remoteSocket->write(QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n');
    m_remoteSocket->flush();
    emit remoteConnectionChanged(true);
}

void LanDeviceManager::handleRemoteData()
{
    m_remoteBuffer.append(m_remoteSocket->readAll());
    while (true) {
        const int end = m_remoteBuffer.indexOf('\n');
        if (end < 0)
            return;
        const QByteArray line = m_remoteBuffer.left(end).trimmed();
        m_remoteBuffer.remove(0, end + 1);
        LanQueueSnapshotInfo snapshot;
        if (parseSnapshot(line, &snapshot)) {
            m_remoteQueue = snapshot;
            emit remoteQueueChanged();
        }
    }
}

void LanDeviceManager::scheduleQueueBroadcast()
{
    if (!m_running)
        return;
    ++m_revision;
    sendAnnouncement();
    if (!m_broadcastTimer->isActive())
        m_broadcastTimer->start();
}

void LanDeviceManager::broadcastQueue()
{
    const QByteArray data = snapshotJson();
    for (QTcpSocket *socket : std::as_const(m_subscribers)) {
        if (socket->property("lanSubscribed").toBool() &&
            socket->state() == QAbstractSocket::ConnectedState) {
            socket->write(data);
            socket->flush();
        }
    }
}

QByteArray LanDeviceManager::snapshotJson() const
{
    const LanQueueSnapshotInfo snapshot = buildSnapshot();
    QJsonArray items;
    for (const MusicInfo &music : snapshot.items) {
        items.append(QJsonObject{
            {QStringLiteral("id"), music.id},
            {QStringLiteral("title"), music.title},
            {QStringLiteral("artist"), music.artist},
            {QStringLiteral("album"), music.album},
            {QStringLiteral("duration"), music.duration},
            {QStringLiteral("coverPath"), music.coverUrl},
            {QStringLiteral("playable"), !music.isLocalFile()}
        });
    }
    const QJsonObject object{
        {QStringLiteral("protocol"), kProtocol},
        {QStringLiteral("type"), QStringLiteral("queue")},
        {QStringLiteral("revision"), snapshot.revision},
        {QStringLiteral("currentIndex"), snapshot.currentIndex},
        {QStringLiteral("currentMusicId"), snapshot.currentMusicId},
        {QStringLiteral("isPlaying"), snapshot.isPlaying},
        {QStringLiteral("playMode"), snapshot.playMode},
        {QStringLiteral("items"), items}
    };
    return QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
}

bool LanDeviceManager::parseSnapshot(const QByteArray &line, LanQueueSnapshotInfo *snapshot) const
{
    const QJsonDocument document = QJsonDocument::fromJson(line);
    if (!document.isObject())
        return false;
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("protocol")).toInt() != kProtocol ||
        object.value(QStringLiteral("type")).toString() != QStringLiteral("queue")) {
        return false;
    }

    snapshot->revision = object.value(QStringLiteral("revision")).toInteger();
    snapshot->currentIndex = object.value(QStringLiteral("currentIndex")).toInt(-1);
    snapshot->currentMusicId = object.value(QStringLiteral("currentMusicId")).toInt();
    snapshot->isPlaying = object.value(QStringLiteral("isPlaying")).toBool();
    snapshot->playMode = object.value(QStringLiteral("playMode")).toString(QStringLiteral("list"));
    snapshot->items.clear();
    for (const QJsonValue &value : object.value(QStringLiteral("items")).toArray()) {
        const QJsonObject item = value.toObject();
        MusicInfo music;
        music.id = item.value(QStringLiteral("id")).toInt();
        music.title = item.value(QStringLiteral("title")).toString();
        music.artist = item.value(QStringLiteral("artist")).toString();
        music.album = item.value(QStringLiteral("album")).toString();
        music.duration = item.value(QStringLiteral("duration")).toInt();
        music.coverUrl = item.value(QStringLiteral("coverPath")).toString();
        snapshot->items.append(music);
    }
    return true;
}

LanQueueSnapshotInfo LanDeviceManager::buildSnapshot() const
{
    LanQueueSnapshotInfo snapshot;
    snapshot.revision = m_revision;
    snapshot.items = PlaylistManager::instance().playlist();
    snapshot.currentIndex = PlaylistManager::instance().currentIndex();
    snapshot.playMode = PlaylistManager::instance().playMode();
    snapshot.currentMusicId = m_playerMusicId;
    if (snapshot.currentMusicId != 0) {
        for (int i = 0; i < snapshot.items.size(); ++i) {
            if (snapshot.items.at(i).id == snapshot.currentMusicId) {
                snapshot.currentIndex = i;
                break;
            }
        }
    } else if (snapshot.currentIndex >= 0 && snapshot.currentIndex < snapshot.items.size()) {
        snapshot.currentMusicId = snapshot.items.at(snapshot.currentIndex).id;
    }
    snapshot.isPlaying = m_playerPlaying;
    return snapshot;
}

QString LanDeviceManager::accountTag() const
{
    const int userId = m_accountUserId;
    return QString::fromLatin1(QCryptographicHash::hash(
        QByteArrayLiteral("nekomusic-lan-v1|") + QByteArray::number(userId),
        QCryptographicHash::Sha256).toHex());
}

QString LanDeviceManager::deviceId() const
{
    const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    const QString dir = home + QStringLiteral("/.nekomusic");
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/lan-device-id");
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        const QString value = QString::fromUtf8(file.readAll()).trimmed();
        if (!value.isEmpty())
            return value;
    }
    const QString value = QString::number(QRandomGenerator::global()->generate64(), 16);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(value.toUtf8());
        file.close();
    }
    return value;
}

QString LanDeviceManager::deviceName() const
{
    const QString hostName = QHostInfo::localHostName().trimmed();
    return hostName.isEmpty() ? QStringLiteral("unknow") : hostName;
}

void LanDeviceManager::publishDevices()
{
    std::sort(m_devices.begin(), m_devices.end(), [](const LanDeviceInfo &a, const LanDeviceInfo &b) {
        return a.deviceName.toLower() < b.deviceName.toLower();
    });
    emit devicesChanged();
}
