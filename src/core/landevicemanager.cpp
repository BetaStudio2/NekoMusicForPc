#include "core/landevicemanager.h"

#include "core/playlistmanager.h"
#include "core/playerengine.h"
#include "core/usermanager.h"

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

QList<QNetworkInterface> multicastInterfaces()
{
    QList<QNetworkInterface> interfaces;
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

        interfaces.append(interfaceInfo);
    }
    return interfaces;
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

void LanDeviceManager::setPlayerEngine(PlayerEngine *engine)
{
    if (m_playerEngine == engine)
        return;
    if (m_playerEngine)
        disconnect(m_playerEngine, &PlayerEngine::stateChanged,
                   this, &LanDeviceManager::scheduleQueueBroadcast);
    m_playerEngine = engine;
    if (m_playerEngine) {
        connect(m_playerEngine, &PlayerEngine::stateChanged,
                this, &LanDeviceManager::scheduleQueueBroadcast);
        connect(m_playerEngine, &PlayerEngine::musicStarted,
                this, [this](const MusicInfo &) { scheduleQueueBroadcast(); });
    }
}

void LanDeviceManager::start()
{
    if (!UserManager::instance().isLoggedIn())
        return;

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
    m_multicastInterfaces = multicastInterfaces();
    bool joinedAny = false;
    for (const QNetworkInterface &interfaceInfo : std::as_const(m_multicastInterfaces)) {
        if (!m_udp->joinMulticastGroup(kDiscoveryGroup, interfaceInfo)) {
            qWarning("LAN multicast join failed on %s: %s",
                     qPrintable(interfaceInfo.humanReadableName()),
                     qPrintable(m_udp->errorString()));
        } else {
            joinedAny = true;
        }
    }
    if (!joinedAny) {
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
    if (m_udp->state() == QAbstractSocket::BoundState) {
        for (const QNetworkInterface &interfaceInfo : std::as_const(m_multicastInterfaces))
            m_udp->leaveMulticastGroup(kDiscoveryGroup, interfaceInfo);
        // Also leave the default membership used when no interface-specific
        // join succeeded.
        m_udp->leaveMulticastGroup(kDiscoveryGroup);
    }
    m_multicastInterfaces.clear();
    m_lastDiscoveryHandshake.clear();
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

    const QByteArray data = announcementJson();
    if (m_multicastInterfaces.isEmpty()) {
        m_udp->writeDatagram(data, kDiscoveryGroup, kDiscoveryPort);
        m_udp->writeDatagram(data, QHostAddress::Broadcast, kDiscoveryPort);
        return;
    }

    // Send on every active IPv4 interface. A single preferred interface is
    // unreliable on machines with Wi-Fi, Ethernet, VPN, or virtual adapters.
    for (const QNetworkInterface &interfaceInfo : std::as_const(m_multicastInterfaces)) {
        m_udp->setMulticastInterface(interfaceInfo);
        m_udp->writeDatagram(data, kDiscoveryGroup, kDiscoveryPort);
        for (const QNetworkAddressEntry &entry : interfaceInfo.addressEntries()) {
            const QHostAddress broadcast = entry.broadcast();
            if (entry.ip().protocol() == QAbstractSocket::IPv4Protocol &&
                !broadcast.isNull()) {
                m_udp->writeDatagram(data, broadcast, kDiscoveryPort);
            }
        }
    }
}

void LanDeviceManager::sendAnnouncementTo(const QString &host)
{
    if (!m_running || !m_udp->isOpen())
        return;
    const QHostAddress address(host);
    if (address.isNull() || address.protocol() != QAbstractSocket::IPv4Protocol)
        return;
    // A unicast response works on networks that suppress multicast/broadcast
    // traffic while still allowing normal LAN TCP connections.
    m_udp->writeDatagram(announcementJson(), address, kDiscoveryPort);
}

void LanDeviceManager::sendDiscoveryHandshake(const LanDeviceInfo &device)
{
    if (!m_running || device.host.isEmpty() || device.port == 0)
        return;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_lastDiscoveryHandshake.value(device.deviceId, 0) < 10'000)
        return;
    m_lastDiscoveryHandshake.insert(device.deviceId, now);

    // This short-lived TCP hello is a fallback for APs that block all UDP
    // discovery traffic. The Android peer registers us as soon as it reads
    // the subscribe line, which is the same registration used by selection.
    auto *socket = new QTcpSocket(this);
    connect(socket, &QTcpSocket::connected, this, [this, socket]() {
        const QJsonObject object{
            {QStringLiteral("protocol"), kProtocol},
            {QStringLiteral("type"), QStringLiteral("subscribe")},
            {QStringLiteral("accountTag"), accountTag()},
            {QStringLiteral("deviceId"), deviceId()},
            {QStringLiteral("deviceName"), deviceName()},
            {QStringLiteral("platform"), QStringLiteral("pc")},
            {QStringLiteral("port"), static_cast<int>(m_server->serverPort())}
        };
        socket->write(QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n');
        socket->flush();
        socket->disconnectFromHost();
    });
    connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
    connect(socket, &QTcpSocket::errorOccurred, socket, [socket](QAbstractSocket::SocketError) {
        socket->abort();
    });
    socket->connectToHost(device.host, device.port);
}

QByteArray LanDeviceManager::announcementJson() const
{
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
    return QJsonDocument(object).toJson(QJsonDocument::Compact);
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

    // The PC can hear this peer, so answer directly to its source address.
    // This makes discovery work even when the access point drops multicast.
    sendAnnouncementTo(host);
    sendDiscoveryHandshake(device);

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
    if (m_playerEngine && m_playerEngine->currentMusic().id != 0) {
        snapshot.currentMusicId = m_playerEngine->currentMusic().id;
        for (int i = 0; i < snapshot.items.size(); ++i) {
            if (snapshot.items.at(i).id == snapshot.currentMusicId) {
                snapshot.currentIndex = i;
                break;
            }
        }
    } else if (snapshot.currentIndex >= 0 && snapshot.currentIndex < snapshot.items.size()) {
        snapshot.currentMusicId = snapshot.items.at(snapshot.currentIndex).id;
    }
    snapshot.isPlaying = m_playerEngine && m_playerEngine->isActuallyPlaying();
    return snapshot;
}

QString LanDeviceManager::accountTag() const
{
    const QVariantMap info = UserManager::instance().userInfo();
    const int userId = info.value(QStringLiteral("id"),
                                  info.value(QStringLiteral("userId"), -1)).toInt();
    return QString::fromLatin1(QCryptographicHash::hash(
        QByteArrayLiteral("nekomusic-lan-v1|") + QByteArray::number(userId),
        QCryptographicHash::Sha256).toHex());
}

QString LanDeviceManager::deviceId() const
{
    QSettings settings;
    const QString key = QStringLiteral("lan/deviceId");
    QString value = settings.value(key).toString();
    if (value.isEmpty()) {
        value = QString::number(QRandomGenerator::global()->generate64(), 16);
        settings.setValue(key, value);
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
