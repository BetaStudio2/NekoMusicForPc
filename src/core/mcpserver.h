#pragma once

/**
 * @file mcpserver.h
 * @brief 内置 MCP（Model Context Protocol）服务端。
 *
 * 以本地 HTTP 形式对外提供 MCP：支持 Streamable HTTP（`POST/GET /mcp`）与
 * 兼容旧规范的 SSE 传输（`GET /sse` + `POST /messages`）。JSON-RPC 2.0，
 * 会话使用 `Mcp-Session-Id` 头（旧传输用 `?sessionId=`）。
 *
 * 具体工具由 {@link McpToolHost} 提供，便于与播放器解耦。
 */

#include <QByteArray>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QObject>
#include <QPointer>
#include <QString>
#include <functional>

class QJsonDocument;
class QTcpServer;
class QTcpSocket;

/** MCP 工具宿主：由业务层实现，提供工具清单与调用结果。 */
class McpToolHost
{
public:
    virtual ~McpToolHost() = default;

    /** 返回 tools/list 的 tools 数组（每项含 name / description / inputSchema）。 */
    virtual QJsonArray listTools() const = 0;

    /**
     * 调用工具。允许异步：处理完成后回调 done(ok, text, structuredContent)。
     * @param structuredContent 可选的 structuredContent 对象（无则传空对象）。
     */
    virtual void callTool(const QString &name, const QJsonObject &arguments,
                          std::function<void(bool ok, const QString &text,
                                             const QJsonObject &structuredContent)> done) = 0;
};

class McpServer : public QObject
{
    Q_OBJECT

public:
    explicit McpServer(QObject *parent = nullptr);
    ~McpServer() override;

    void setHost(McpToolHost *host) { m_host = host; }

    /** 启动监听；token 非空时校验 Bearer 头。allowRemote 为真时监听所有网卡。 */
    bool start(quint16 port, const QString &token = QString(), bool allowRemote = false);
    void stop();

    bool isRunning() const;
    quint16 port() const { return m_port; }
    QString errorString() const { return m_error; }
    QString endpointUrl() const;

signals:
    void runningChanged(bool running);

private:
    struct HttpRequest {
        QString method;
        QString path;
        QString query;
        QHash<QString, QString> headers;
        QByteArray body;
    };
    struct Session {
        QString id;
        QPointer<QTcpSocket> stream; // SSE 长连接（GET /mcp 或 GET /sse）
        bool legacy = false;
    };
    /** 一次 RPC 的回复目标：Streamable HTTP 写回 socket，旧 SSE 推给会话流。 */
    struct Target {
        QPointer<QTcpSocket> http;
        QString sessionId;
    };

    void onNewConnection();
    void onReadyRead(QTcpSocket *socket);
    void onDisconnected(QTcpSocket *socket);

    void dispatch(QTcpSocket *socket, const HttpRequest &req);
    void handleStreamablePost(QTcpSocket *socket, const HttpRequest &req);
    void handleStreamableGet(QTcpSocket *socket, const HttpRequest &req);
    void handleLegacySse(QTcpSocket *socket);
    void handleLegacyPost(QTcpSocket *socket, const HttpRequest &req);

    void processPayload(const QByteArray &body, const Target &target);
    /** 处理单条 JSON-RPC；notification（无 id）不产生回复。 */
    void processRpc(const QJsonObject &request, const Target &target,
                    const std::function<void(bool produced, const QJsonObject &)> &sink);

    QString sessionIdFor(const HttpRequest &req) const;
    Session *findSession(const QString &id);
    QString createSession(bool legacy, QTcpSocket *stream);

    void writeHttp(QTcpSocket *socket, int status, const QByteArray &contentType,
                   const QByteArray &body, const QList<QPair<QByteArray, QByteArray>> &extra = {});
    void writeJsonRpc(const Target &target, const QJsonObject &response);
    void sendRpcDocument(const Target &target, const QJsonDocument &doc);
    void sendAccepted(const Target &target);
    static void writeSse(QTcpSocket *socket, const QByteArray &data, const QByteArray &event = QByteArray());

    McpToolHost *m_host = nullptr;
    QTcpServer *m_server = nullptr;
    quint16 m_port = 0;
    QString m_token;
    QString m_error;
    QHash<QTcpSocket *, QByteArray> m_buffers;
    QHash<QString, Session> m_sessions;
    QHash<QTcpSocket *, QString> m_httpSessions;
    quint64 m_nextSession = 1;
};
