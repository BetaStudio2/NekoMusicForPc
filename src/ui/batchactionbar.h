#pragma once

/**
 * @file batchactionbar.h
 * @brief 单曲列表批量编辑模式的操作条（已选 N 首 / 全选 / 批量动作 / 退出）
 *
 * 设计约定：
 *   - 与页面顶部原有按钮排（播放 / 下载全部 / 更多 ⋯）占同一行位置，
 *     进入批量模式时隐藏原按钮排、显示本操作条，退出时反向切换；
 *   - 按钮按页面能力显示（canXxx = false 的整个不显示），
 *     选中数量为 0 时统一置灰，避免出现点了没反应的死按钮；
 *   - 文案全部走 I18n，三张语言表都有对应键。
 */

#include <QWidget>

class QLabel;
class QPushButton;

class BatchActionBar : public QWidget
{
    Q_OBJECT

public:
    explicit BatchActionBar(QWidget *parent = nullptr);

    /** 页面能力：false 的按钮不创建/不显示 */
    void setCapabilities(bool canAddToPlaylist, bool canAddToQueue, bool canDownload,
                         bool canUnfavorite, bool canRemoveFromPlaylist);

    /** 已选数量：更新「已选 N 首」文案与各按钮可用状态 */
    void setSelectedCount(int count);
    /** 全选 / 取消全选按钮文案跟随当前是否已全选 */
    void setAllSelected(bool allSelected);
    /** 退出批量模式时复位（数量归零、全选态复位） */
    void reset() { setAllSelected(false); setSelectedCount(0); }

    void retranslate();
    void applyTheme();

signals:
    void addToPlaylistRequested();
    void addToQueueRequested();
    void downloadRequested();
    void unfavoriteRequested();
    void removeFromPlaylistRequested();
    void selectAllToggled();
    void exitRequested();

private:
    QPushButton *makeActionButton(const char *iconName, const char *textKey);

    QLabel *m_countLbl = nullptr;
    QPushButton *m_selectAllBtn = nullptr;
    QPushButton *m_addToPlaylistBtn = nullptr;
    QPushButton *m_addToQueueBtn = nullptr;
    QPushButton *m_downloadBtn = nullptr;
    QPushButton *m_unfavoriteBtn = nullptr;
    QPushButton *m_removeFromPlaylistBtn = nullptr;
    QPushButton *m_exitBtn = nullptr;

    int m_selectedCount = 0;
    bool m_allSelected = false;
};
