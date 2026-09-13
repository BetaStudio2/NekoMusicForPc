#pragma once

/**
 * @file externalimportdialog.h
 * @brief 外部歌单导入对话框公共基类
 *
 * 网易云 / QQ / 酷狗三个导入弹窗的 UI 与交互流程完全一致，仅「输入解析」
 * 与「歌单详情请求」不同。基类负责：
 *   - 输入链接 → 获取详情 → 选择目标歌单 → SSE 导入 → 进度/结果展示
 * 子类只需提供 i18n key 配置、parseInput() 与 fetchPlaylist()。
 */

#include <QDialog>
#include <QList>
#include <QPair>
#include <functional>
#include "core/apiclient.h"

class QLineEdit;
class QLabel;
class QPushButton;
class QComboBox;
class QProgressBar;
class QNetworkReply;

class ExternalImportDialog : public QDialog
{
    Q_OBJECT

public:
    /** 各平台的文案 key 与 pull source。 */
    struct SourceConfig {
        QString source;            // "netease" / "qq" / "kugou"
        QString titleKey;
        QString descKey;
        QString placeholderKey;
        QString invalidKey;
        QString emptyKey;
        QString playlistInfoKey;
    };

    /** 统一的歌单详情数据结构（各平台响应归一化后）。 */
    struct PlaylistData {
        QString id;                // 传给 pull 的外部歌单 ID
        QString name;
        int trackCount = 0;
        QList<ApiClient::NeteaseTrack> tracks;
    };

    using FetchCallback = std::function<void(bool ok, const QString &message, const PlaylistData &data)>;

    ExternalImportDialog(ApiClient *apiClient, const SourceConfig &config, QWidget *parent = nullptr);
    ~ExternalImportDialog() override;

signals:
    void importCompleted(int addedCount, int totalCount, int failCount, bool importedToFavorites);

protected:
    ApiClient *apiClient() const { return m_apiClient; }

    /** 解析用户输入为传给后端的 ID；返回空串表示非法。 */
    virtual QString parseInput(const QString &input) const = 0;
    /** 请求歌单详情，异步回调归一化后的 PlaylistData。 */
    virtual void fetchPlaylist(const QString &id, FetchCallback cb) = 0;

private slots:
    void onFetchPlaylist();
    void onStartImport();

private:
    void setupUi();
    void updatePlaylistCombo();
    void startPull(int targetPlaylistId, const QString &newPlaylistName);
    void onPullTrack(const ApiClient::ExternalPullTrack &track);
    void onPullProgress(const ApiClient::ExternalPullProgress &progress);
    void restoreImportControls();
    void finishImport(const ApiClient::ExternalPullSummary &summary);
    void setError(const QString &error);
    void setProgress(const QString &status);

    static constexpr int kImportTargetNewPlaylist = -1;

    ApiClient *m_apiClient = nullptr;
    SourceConfig m_config;
    QNetworkReply *m_pullReply = nullptr;

    // 导入进度
    int m_totalTracks = 0;
    int m_finishedTracks = 0;

    // UI 组件
    QLineEdit *m_inputEdit = nullptr;
    QPushButton *m_fetchBtn = nullptr;
    QLabel *m_playlistInfoLabel = nullptr;
    QComboBox *m_targetPlaylistCombo = nullptr;
    QLineEdit *m_newPlaylistEdit = nullptr;
    QPushButton *m_importBtn = nullptr;
    QProgressBar *m_progressBar = nullptr;
    QLabel *m_statusLabel = nullptr;
    QLabel *m_errorLabel = nullptr;
    QPushButton *m_closeBtn = nullptr;

    // 状态
    PlaylistData m_playlistData;
    QList<QPair<int, QString>> m_userPlaylists;  // id, name
};
