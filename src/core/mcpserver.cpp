/**
 * @file mcpserver.cpp
 */

#include "mcpserver.h"

#include "version.h"

#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QList>
#include <QPair>
#include <QSharedPointer>
#include <QUrl>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUuid>

namespace {

constexpr const char *kLatestProtocol = "2025-06-18";
const QStringList kSupportedProtocols{
    QStringLiteral("2025-06-18"),
    QStringLiteral("2025-03-26"),
    QStringLiteral("2024-11-05"),
};

QJsonObject rpcError(const QJsonValue &id, int code, const QString &message)
{
    return QJsonObject{
        {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
        {QStringLiteral("id"), id},
        {QStringLiteral("error"),
         QJsonObject{{QStringLiteral("code"), code}, {QStringLiteral("message"), message}}},
    };
}

QJsonObject rpcResult(const QJsonValue &id, const QJsonObject &result)
{
    return QJsonObject{
        {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
        {QStringLiteral("id"), id},
        {QStringLiteral("result"), result},
    };
}

QByteArray statusText(int status)
{
    switch (status) {
    case 200: return "OK";
    case 202: return "Accepted";
    case 204: return "No Content";
    case 400: return "Bad Request";
    case 401: return "Unauthorized";
    case 404: return "Not Found";
    case 405: return "Method Not Allowed";
    case 500: return "Internal Server Error";
    default: return "OK";
    }
}

} // namespace

McpServer::McpServer(QObject *parent)
    : QObject(parent)
{
}

McpServer::~McpServer()
{
    stop();
}

bool McpServer::start(quint16 port, const QString &token, bool allowRemote)
{
    stop();

    m_token = token.trimmed();
    m_server = new QTcpServer(this);
    const QHostAddress bind = allowRemote ? QHostAddress::Any : QHostAddress::LocalHost;
    if (!m_server->listen(bind, port)) {
        m_error = m_server->errorString();
        delete m_server;
        m_server = nullptr;
        // 通知界面刷新，让设置页展示启动失败原因。
        emit runningChanged(false);
        return false;
    }

    m_port = m_server->serverPort();
    m_error.clear();
    connect(m_server, &QTcpServer::newConnection, this, &McpServer::onNewConnection);
    emit runningChanged(true);
    return true;
}

void McpServer::stop()
{
    if (m_server) {
        m_server->close();
        m_server->deleteLater();
        m_server = nullptr;
    }
    const bool wasRunning = !m_sessions.isEmpty() || m_port != 0;
    for (auto it = m_sessions.begin(); it != m_sessions.end(); ++it) {
        if (it->stream)
            it->stream->disconnectFromHost();
    }
    m_sessions.clear();
    m_buffers.clear();
    m_httpSessions.clear();
    m_port = 0;
    if (wasRunning)
        emit runningChanged(false);
}

bool McpServer::isRunning() const
{
    return m_server && m_server->isListening();
}

QString McpServer::endpointUrl() const
{
    return QStringLiteral("http://127.0.0.1:%1/mcp").arg(m_port);
}

void McpServer::onNewConnection()
{
    while (m_server && m_server->hasPendingConnections()) {
        QTcpSocket *socket = m_server->nextPendingConnection();
        m_buffers.insert(socket, QByteArray());
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { onReadyRead(socket); });
        connect(socket, &QTcpSocket::disconnected, this, [this, socket]() { onDisconnected(socket); });
    }
}

void McpServer::onDisconnected(QTcpSocket *socket)
{
    m_buffers.remove(socket);
    const QString httpSession = m_httpSessions.take(socket);
    if (!httpSession.isEmpty())
        m_sessions.remove(httpSession);
    for (auto it = m_sessions.begin(); it != m_sessions.end();) {
        if (it->stream == socket)
            it = m_sessions.erase(it);
        else
            ++it;
    }
    socket->deleteLater();
}

void McpServer::onReadyRead(QTcpSocket *socket)
{
    QByteArray &buf = m_buffers[socket];
    buf.append(socket->readAll());

    HttpRequest req;
    const int headerEnd = buf.indexOf("\r\n\r\n");
    if (headerEnd < 0)
        return;

    const QList<QByteArray> lines = buf.left(headerEnd).split('\n');
    if (lines.isEmpty())
        return;
    const QList<QByteArray> requestLine = lines.first().trimmed().split(' ');
    if (requestLine.size() < 2)
        return;
    req.method = QString::fromLatin1(requestLine.at(0)).toUpper();
    const QString target = QString::fromLatin1(requestLine.at(1));
    const int q = target.indexOf(QLatin1Char('?'));
    if (q >= 0) {
        req.path = target.left(q);
        req.query = target.mid(q + 1);
    } else {
        req.path = target;
    }
    for (int i = 1; i < lines.size(); ++i) {
        const QByteArray line = lines.at(i).trimmed();
        const int colon = line.indexOf(':');
        if (colon <= 0)
            continue;
        req.headers.insert(QString::fromLatin1(line.left(colon)).trimmed().toLower(),
                           QString::fromLatin1(line.mid(colon + 1)).trimmed());
    }

    const int contentLength = req.headers.value(QStringLiteral("content-length")).toInt();
    const int total = headerEnd + 4 + contentLength;
    if (buf.size() < total)
        return;
    req.body = buf.mid(headerEnd + 4, contentLength);
    buf.clear();

    dispatch(socket, req);
}

void McpServer::dispatch(QTcpSocket *socket, const HttpRequest &req)
{
    if (req.method == QLatin1String("OPTIONS")) {
        writeHttp(socket, 204, QByteArray(),
                  QByteArray(),
                  {{"Allow", "GET, POST, DELETE, OPTIONS"},
                   {"Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS"},
                   {"Access-Control-Allow-Headers", "Content-Type, Authorization, Mcp-Session-Id, Accept"},
                   {"Access-Control-Allow-Origin", "*"}});
        return;
    }

    if (!m_token.isEmpty()) {
        const QString auth = req.headers.value(QStringLiteral("authorization"));
        const QString expected = QStringLiteral("Bearer ") + m_token;
        if (auth.compare(expected, Qt::CaseInsensitive) != 0) {
            writeHttp(socket, 401, "application/json",
                      QByteArrayLiteral("{\"error\":\"unauthorized\"}"),
                      {{"WWW-Authenticate", "Bearer"}});
            return;
        }
    }

    if (req.method == QLatin1String("GET") && req.path == QLatin1String("/health")) {
        writeHttp(socket, 200, "text/plain; charset=utf-8", QByteArrayLiteral("ok"));
        return;
    }
    if (req.method == QLatin1String("POST") && req.path == QLatin1String("/mcp")) {
        handleStreamablePost(socket, req);
        return;
    }
    if (req.method == QLatin1String("GET") && req.path == QLatin1String("/mcp")) {
        handleStreamableGet(socket, req);
        return;
    }
    if (req.method == QLatin1String("DELETE") && req.path == QLatin1String("/mcp")) {
        const QString sid = sessionIdFor(req);
        if (Session *s = findSession(sid)) {
            if (s->stream)
                s->stream->disconnectFromHost();
            m_sessions.remove(sid);
        }
        writeHttp(socket, 204, QByteArray(), QByteArray());
        return;
    }
    if (req.method == QLatin1String("GET") && req.path == QLatin1String("/sse")) {
        handleLegacySse(socket);
        return;
    }
    if (req.method == QLatin1String("POST") && req.path == QLatin1String("/messages")) {
        handleLegacyPost(socket, req);
        return;
    }

    writeHttp(socket, 404, "application/json", QByteArrayLiteral("{\"error\":\"not found\"}"));
}

void McpServer::handleStreamablePost(QTcpSocket *socket, const HttpRequest &req)
{
    QString sid = sessionIdFor(req);
    if (findSession(sid) == nullptr) {
        const QJsonDocument doc = QJsonDocument::fromJson(req.body);
        const QString method = doc.isObject() ? doc.object().value(QStringLiteral("method")).toString()
                                              : QString();
        sid = createSession(false, nullptr);
        m_httpSessions.insert(socket, sid);
        if (method.isEmpty() && sid.isEmpty()) {
            writeHttp(socket, 400, "application/json", QByteArrayLiteral("{\"error\":\"bad request\"}"));
            return;
        }
    }
    m_httpSessions.insert(socket, sid);
    processPayload(req.body, Target{socket, sid});
}

void McpServer::handleStreamableGet(QTcpSocket *socket, const HttpRequest &req)
{
    QString sid = sessionIdFor(req);
    if (findSession(sid) == nullptr)
        sid = createSession(false, socket);
    else
        findSession(sid)->stream = socket;

    QByteArray resp = "HTTP/1.1 200 OK\r\n"
                      "Content-Type: text/event-stream\r\n"
                      "Cache-Control: no-cache\r\n"
                      "Connection: keep-alive\r\n";
    resp += "Mcp-Session-Id: " + sid.toUtf8() + "\r\n\r\n";
    socket->write(resp);
    socket->write(": connected\n\n");
}

void McpServer::handleLegacySse(QTcpSocket *socket)
{
    const QString sid = createSession(true, socket);

    QByteArray resp = "HTTP/1.1 200 OK\r\n"
                      "Content-Type: text/event-stream\r\n"
                      "Cache-Control: no-cache\r\n"
                      "Connection: keep-alive\r\n\r\n";
    resp += "event: endpoint\n";
    resp += "data: /messages?sessionId=" + sid.toUtf8() + "\n\n";
    socket->write(resp);
}

void McpServer::handleLegacyPost(QTcpSocket *socket, const HttpRequest &req)
{
    const QString sid = sessionIdFor(req);
    if (findSession(sid) == nullptr) {
        writeHttp(socket, 404, "application/json", QByteArrayLiteral("{\"error\":\"unknown session\"}"));
        return;
    }
    writeHttp(socket, 202, "application/json", QByteArray());
    processPayload(req.body, Target{nullptr, sid});
}

void McpServer::processPayload(const QByteArray &body, const Target &target)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(body, &err);
    if (err.error != QJsonParseError::NoError) {
        sendRpcDocument(target, QJsonDocument(rpcError(QJsonValue(), -32700, QStringLiteral("Parse error"))));
        return;
    }

    if (doc.isArray()) {
        const QJsonArray arr = doc.array();
        if (arr.isEmpty()) {
            sendAccepted(target);
            return;
        }
        auto responses = QSharedPointer<QJsonArray>::create();
        auto remaining = QSharedPointer<int>::create(arr.size());
        auto produced = QSharedPointer<bool>::create(false);
        for (const QJsonValue &value : arr) {
            processRpc(value.toObject(), target,
                       [this, target, responses, remaining, produced](bool ok, const QJsonObject &response) {
                           if (ok) {
                               responses->append(response);
                               *produced = true;
                           }
                           if (--(*remaining) == 0) {
                               if (*produced)
                                   sendRpcDocument(target, QJsonDocument(*responses));
                               else
                                   sendAccepted(target);
                           }
                       });
        }
        return;
    }

    if (doc.isObject()) {
        processRpc(doc.object(), target, [this, target](bool ok, const QJsonObject &response) {
            if (ok)
                sendRpcDocument(target, QJsonDocument(response));
            else
                sendAccepted(target);
        });
        return;
    }

    sendRpcDocument(target, QJsonDocument(rpcError(QJsonValue(), -32600, QStringLiteral("Invalid Request"))));
}

void McpServer::processRpc(const QJsonObject &request, const Target &target,
                           const std::function<void(bool, const QJsonObject &)> &sink)
{
    const QString method = request.value(QStringLiteral("method")).toString();
    const QJsonValue id = request.value(QStringLiteral("id"));
    const QJsonObject params = request.value(QStringLiteral("params")).toObject();
    const bool notification = id.isUndefined() || id.isNull();

    auto reply = [&sink, &id](const QJsonObject &result) { sink(true, rpcResult(id, result)); };
    auto notifyOnly = [&sink]() { sink(false, QJsonObject()); };

    if (method == QLatin1String("initialize")) {
        const QString requested = params.value(QStringLiteral("protocolVersion")).toString();
        const QString chosen = kSupportedProtocols.contains(requested)
                                   ? requested
                                   : QString::fromLatin1(kLatestProtocol);
        QJsonObject capabilities{
            {QStringLiteral("tools"), QJsonObject{{QStringLiteral("listChanged"), false}}},
        };
        QJsonObject result{
            {QStringLiteral("protocolVersion"), chosen},
            {QStringLiteral("capabilities"), capabilities},
            {QStringLiteral("serverInfo"),
             QJsonObject{{QStringLiteral("name"), QStringLiteral("NekoMusic")},
                         {QStringLiteral("version"), QStringLiteral(APP_VERSION)}}},
            {QStringLiteral("instructions"),
             QStringLiteral("Neko 云音乐桌面端：可查询当前播放与队列，控制播放/暂停/上一首/下一首/进度/音量，"
                            "搜索曲库并按 ID 播放。")},
        };
        reply(result);
        return;
    }
    if (method.startsWith(QLatin1String("notifications/"))) {
        notifyOnly();
        return;
    }
    if (method == QLatin1String("ping")) {
        reply(QJsonObject());
        return;
    }
    if (method == QLatin1String("tools/list")) {
        QJsonArray tools;
        if (m_host)
            tools = m_host->listTools();
        reply(QJsonObject{{QStringLiteral("tools"), tools}});
        return;
    }
    if (method == QLatin1String("tools/call")) {
        const QString name = params.value(QStringLiteral("name")).toString();
        const QJsonObject arguments = params.value(QStringLiteral("arguments")).toObject();
        if (!m_host) {
            sink(true, rpcError(id, -32603, QStringLiteral("MCP 工具宿主不可用")));
            return;
        }
        QPointer<McpServer> self(this);
        m_host->callTool(name, arguments,
                         [sink, id, self](bool ok, const QString &text, const QJsonObject &structured) {
                             QJsonObject result{
                                 {QStringLiteral("content"),
                                  QJsonArray{QJsonObject{{QStringLiteral("type"), QStringLiteral("text")},
                                                         {QStringLiteral("text"), text}}}},
                             };
                             if (ok && !structured.isEmpty())
                                 result.insert(QStringLiteral("structuredContent"), structured);
                             if (!ok)
                                 result.insert(QStringLiteral("isError"), true);
                             sink(true, rpcResult(id, result));
                         });
        return;
    }
    if (method == QLatin1String("resources/list")) {
        reply(QJsonObject{{QStringLiteral("resources"), QJsonArray()}});
        return;
    }
    if (method == QLatin1String("resources/templates/list")) {
        reply(QJsonObject{{QStringLiteral("resourceTemplates"), QJsonArray()}});
        return;
    }
    if (method == QLatin1String("prompts/list")) {
        reply(QJsonObject{{QStringLiteral("prompts"), QJsonArray()}});
        return;
    }
    if (method == QLatin1String("logging/setLevel")) {
        reply(QJsonObject());
        return;
    }

    if (notification) {
        notifyOnly();
        return;
    }
    sink(true, rpcError(id, -32601, QStringLiteral("Method not found: ") + method));
}

QString McpServer::sessionIdFor(const HttpRequest &req) const
{
    const QString fromHeader = req.headers.value(QStringLiteral("mcp-session-id"));
    if (!fromHeader.isEmpty())
        return fromHeader;
    if (req.query.isEmpty())
        return QString();
    for (const QString &pair : req.query.split(QLatin1Char('&'))) {
        const int eq = pair.indexOf(QLatin1Char('='));
        if (eq > 0 && pair.left(eq) == QLatin1String("sessionId"))
            return QUrl::fromPercentEncoding(pair.mid(eq + 1).toUtf8());
    }
    return QString();
}

McpServer::Session *McpServer::findSession(const QString &id)
{
    if (id.isEmpty())
        return nullptr;
    auto it = m_sessions.find(id);
    return it == m_sessions.end() ? nullptr : &it.value();
}

QString McpServer::createSession(bool legacy, QTcpSocket *stream)
{
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    Session session;
    session.id = id;
    session.stream = stream;
    session.legacy = legacy;
    m_sessions.insert(id, session);
    ++m_nextSession;
    return id;
}

void McpServer::writeHttp(QTcpSocket *socket, int status, const QByteArray &contentType,
                          const QByteArray &body,
                          const QList<QPair<QByteArray, QByteArray>> &extra)
{
    QByteArray resp = "HTTP/1.1 " + QByteArray::number(status) + ' ' + statusText(status) + "\r\n";
    if (!contentType.isEmpty())
        resp += "Content-Type: " + contentType + "\r\n";
    resp += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    resp += "Connection: close\r\n";
    for (const auto &header : extra)
        resp += header.first + ": " + header.second + "\r\n";
    resp += "\r\n";
    resp += body;
    socket->write(resp);
    socket->flush();
    socket->disconnectFromHost();
}

void McpServer::writeJsonRpc(const Target &target, const QJsonObject &response)
{
    sendRpcDocument(target, QJsonDocument(response));
}

void McpServer::sendRpcDocument(const Target &target, const QJsonDocument &doc)
{
    const QByteArray payload = doc.toJson(QJsonDocument::Compact);
    if (target.http) {
        QList<QPair<QByteArray, QByteArray>> extra;
        if (!target.sessionId.isEmpty())
            extra.append({"Mcp-Session-Id", target.sessionId.toUtf8()});
        writeHttp(target.http, 200, "application/json", payload, extra);
        return;
    }
    if (!target.sessionId.isEmpty()) {
        if (Session *session = findSession(target.sessionId)) {
            if (session->stream)
                writeSse(session->stream, payload, "message");
        }
    }
}

void McpServer::sendAccepted(const Target &target)
{
    if (target.http) {
        QList<QPair<QByteArray, QByteArray>> extra;
        if (!target.sessionId.isEmpty())
            extra.append({"Mcp-Session-Id", target.sessionId.toUtf8()});
        writeHttp(target.http, 202, "application/json", QByteArray(), extra);
    }
}

void McpServer::writeSse(QTcpSocket *socket, const QByteArray &data, const QByteArray &event)
{
    if (!socket)
        return;
    QByteArray frame;
    if (!event.isEmpty())
        frame += "event: " + event + "\n";
    for (const QByteArray &line : data.split('\n'))
        frame += "data: " + line + "\n";
    frame += "\n";
    socket->write(frame);
    socket->flush();
}
