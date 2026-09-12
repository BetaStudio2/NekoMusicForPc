#pragma once

/**
 * @file qqimportdialog.h
 * @brief QQ 音乐歌单导入对话框
 */

#include <QDialog>
#include <QList>
#include <QPair>
#include "core/apiclient.h"

class QLineEdit;
class QLabel;
class QPushButton;
class QComboBox;
class QProgressBar;
class QNetworkReply;

/**
 * QQ 音乐歌单导入对话框
 * 支持输入 QQ 音乐歌单分享链接或 ID，导入到本地歌单
 */
class QqImportDialog : public QDialog
{
    Q_OBJECT

public:
    QqImportDialog(ApiClient *apiClient, QWidget *parent = nullptr);
    ~QqImportDialog() override;

signals:
    void importCompleted(int addedCount, int totalCount, int failCount, bool importedToFavorites);

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
    void setStep(int step);
    void setError(const QString &error);
    void setProgress(const QString &status);
    
    static QString parsePlaylistId(const QString &input);

    static constexpr int kImportTargetNewPlaylist = -1;

    ApiClient *m_apiClient = nullptr;
    QNetworkReply *m_pullReply = nullptr;

    // 导入进度
    int m_totalTracks = 0;
    int m_finishedTracks = 0;
    int m_importedCount = 0;
    int m_existedCount = 0;
    int m_failedCount = 0;
    
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
    int m_currentStep = 1;  // 1=输入链接, 2=选择歌单, 3=导入中, 4=完成
    QString m_qqDisstid;
    QString m_qqPlaylistName;
    QList<ApiClient::NeteaseTrack> m_qqTracks;
    QList<QPair<int, QString>> m_userPlaylists;  // id, name
};
