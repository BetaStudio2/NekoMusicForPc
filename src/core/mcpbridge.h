#pragma once

/**
 * @file mcpbridge.h
 * @brief 把播放器能力暴露为 MCP 工具（McpToolHost 的桌面端实现）。
 */

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QString>
#include <functional>

#include "core/mcpserver.h"
#include "core/musicinfo.h"

class ApiClient;
class PlayerEngine;

class McpBridge : public QObject, public McpToolHost
{
    Q_OBJECT

public:
    explicit McpBridge(PlayerEngine *engine, ApiClient *api, QObject *parent = nullptr);

    void setPlayCallback(std::function<void(const MusicInfo &)> cb) { m_play = std::move(cb); }
    void setNextCallback(std::function<void()> cb) { m_next = std::move(cb); }
    void setPreviousCallback(std::function<void()> cb) { m_previous = std::move(cb); }

    QJsonArray listTools() const override;
    void callTool(const QString &name, const QJsonObject &arguments,
                  std::function<void(bool ok, const QString &text, const QJsonObject &structuredContent)> done) override;

private:
    using Done = std::function<void(bool, const QString &, const QJsonObject &)>;

    static QJsonObject trackJson(const MusicInfo &info);
    QJsonObject playbackStateJson() const;

    void runSearch(const QString &query, int limit,
                   std::function<void(bool ok, const QList<MusicInfo> &tracks, const QString &error)> done);

    PlayerEngine *m_engine = nullptr;
    ApiClient *m_api = nullptr;
    std::function<void(const MusicInfo &)> m_play;
    std::function<void()> m_next;
    std::function<void()> m_previous;
};
