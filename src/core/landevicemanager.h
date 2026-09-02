#ifndef LANDEVICEMANAGER_H
#define LANDEVICEMANAGER_H

#include <QObject>
#include <QList>
#include <QString>
#include "core/musicinfo.h"

class QTcpServer;
class QTcpSocket;
class QUdpSocket;
class QTimer;
class PlayerEngine;

struct LanDeviceInfo {
    QString deviceId;
    QString deviceName;
    QString platform;
    QString host;
    quint16 port = 0;
    QString accountTag;
    qint64 queueRevision = 0;
    int queueCount = 0;
    int currentMusicId = 0;
    qint64 lastSeen = 0;
};

struct LanQueueSnapshotInfo {
    qint64 revision = 0;
    int currentIndex = -1;
    int currentMusicId = 0;
    bool isPlaying = false;
    QString playMode = QStringLiteral("list");
    QList<MusicInfo> items;
};

class LanDeviceManager : public QObject {
    Q_OBJECT

public:
    static LanDeviceManager &instance();

    void start();
    void stop();
    bool isRunning() const { return m_running; }
    void setPlayerEngine(PlayerEngine *engine);

    const QList<LanDeviceInfo> &devices() const { return m_devices; }
    const LanQueueSnapshotInfo &remoteQueue() const { return m_remoteQueue; }
    QString selectedDeviceId() const { return m_selectedDeviceId; }
    void selectDevice(const QString &deviceId);

signals:
    void devicesChanged();
    void deviceDiscovered(const QString &deviceName);
    void remoteQueueChanged();
    void remoteConnectionChanged(bool connected);

private:
    explicit LanDeviceManager(QObject *parent = nullptr);
    ~LanDeviceManager() override = default;
    LanDeviceManager(const LanDeviceManager &) = delete;
    LanDeviceManager &operator=(const LanDeviceManager &) = delete;

    void bindSockets();
    void sendAnnouncement();
    void receiveAnnouncement(const QByteArray &payload, const QString &host);
    void expireDevices();
    void handleServerConnection();
    void handleServerData(QTcpSocket *socket);
    void connectRemote();
    void closeRemote();
    void sendSubscribe();
    void handleRemoteData();
    void scheduleQueueBroadcast();
    void broadcastQueue();
    void scheduleRemoteReconnect();
    QByteArray snapshotJson() const;
    bool parseSnapshot(const QByteArray &line, LanQueueSnapshotInfo *snapshot) const;
    LanQueueSnapshotInfo buildSnapshot() const;
    QString accountTag() const;
    QString deviceId() const;
    QString deviceName() const;
    void publishDevices();

    bool m_running = false;
    QTcpServer *m_server = nullptr;
    QUdpSocket *m_udp = nullptr;
    QTcpSocket *m_remoteSocket = nullptr;
    QTimer *m_announceTimer = nullptr;
    QTimer *m_expireTimer = nullptr;
    QTimer *m_broadcastTimer = nullptr;
    QTimer *m_remoteReconnectTimer = nullptr;
    QList<QTcpSocket *> m_subscribers;
    QList<LanDeviceInfo> m_devices;
    LanQueueSnapshotInfo m_remoteQueue;
    QString m_selectedDeviceId;
    QByteArray m_remoteBuffer;
    qint64 m_revision = 0;
    bool m_closingRemote = false;
    QString m_runningAccountTag;
    PlayerEngine *m_playerEngine = nullptr;
};

#endif // LANDEVICEMANAGER_H
