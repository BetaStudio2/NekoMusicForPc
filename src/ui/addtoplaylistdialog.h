#pragma once

/**
 * @file addtoplaylistdialog.h
 * @brief 添加到歌单 — SPlayer $modal.create + PlaylistAdd.vue（应用内浮层）
 */

#include <QWidget>
#include <QHash>
#include <QList>
#include <QPixmap>
#include "core/musicinfo.h"

class ApiClient;
class QScrollArea;
class QVBoxLayout;
class QLabel;
class QPushButton;
class QParallelAnimationGroup;
class QTimer;

class AddToPlaylistDialog : public QWidget
{
    Q_OBJECT

public:
    explicit AddToPlaylistDialog(const MusicInfo &music, ApiClient *apiClient, QWidget *parent = nullptr);
    /**
     * 批量版：一次把多首曲目加入同一个歌单。
     * 在线歌单按 music_id 逐首调用 ApiClient::addMusicToPlaylist（接口只接受单曲），
     * 全程用 Toast 报进度，收尾时报告「成功 N 首 / 失败 M 首」。
     */
    AddToPlaylistDialog(const QList<MusicInfo> &musics, ApiClient *apiClient, QWidget *parent = nullptr);

    void openOn(QWidget *host);

signals:
    void playlistsChanged();
    void closed();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void resizeEvent(QResizeEvent *event) override;
    void keyPressEvent(QKeyEvent *event) override;

private:
    struct PlaylistRow {
        int id = 0;
        QString name;
        int musicCount = 0;
        QString coverUrl;
    };

    void dismiss();
    void dismissAnimated();
    void refreshBackdrop();
    void scheduleBackdropRefresh(int delayMs = 160);
    void layoutOverlay();
    void animateOpen();
    void animateClose(const std::function<void()> &onFinished);
    void stopAnimations();
    void finishOpenAnimation();
    int cardWidthForHost() const;
    int cardHeightForHost() const;
    void setupUi();
    void updateCardHeight();
    void applyTheme();
    void clearList();
    void loadPlaylists();
    void loadLocalPlaylists();
    void loadOnlinePlaylists();
    QWidget *appendCreateRow();
    QWidget *appendPlaylistRow(const PlaylistRow &row);
    void bindCover(QWidget *rowWidget, const QString &coverUrl);
    void openCreatePlaylist();
    void addToPlaylist(int playlistId);
    /** 批量加入（在线歌单）：按序逐首请求，回调里继续下一首 */
    void addBatchToOnlinePlaylist(int playlistId);
    void reportBatchResult(int success, int failed);
    /** 批量加入时给用户的进度提示（第 n / 共 N 首） */
    void showBatchProgress(int done, int total);

    MusicInfo m_music;
    /** 批量模式下的曲目列表（单曲模式时只有一首，m_music == m_musics.first()） */
    QList<MusicInfo> m_musics;
    ApiClient *m_apiClient = nullptr;
    QWidget *m_host = nullptr;
    bool m_isLocal = false;
    bool m_adding = false;
    bool m_dismissing = false;
    /** 批量加入的进度计数（0 表示单曲模式） */
    int m_batchTotal = 0;
    int m_batchDone = 0;
    int m_batchSuccess = 0;
    int m_batchFailed = 0;

    QWidget *m_backdrop = nullptr;
    QWidget *m_card = nullptr;
    QWidget *m_cardBody = nullptr;
    QLabel *m_titleLbl = nullptr;
    QPushButton *m_closeBtn = nullptr;
    QScrollArea *m_scroll = nullptr;
    QWidget *m_listHost = nullptr;
    QVBoxLayout *m_listLay = nullptr;
    QLabel *m_emptyLbl = nullptr;
    QHash<int, QWidget *> m_rowsByPlaylistId;

    QParallelAnimationGroup *m_animGroup = nullptr;
    QTimer *m_backdropRefreshTimer = nullptr;
};
