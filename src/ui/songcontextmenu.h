#pragma once

/**
 * @file songcontextmenu.h
 * @brief 歌曲右键菜单（自定义浮层，非 QMenu）
 */

#include <QWidget>
#include <QList>
#include <functional>

class SongContextMenuPopup : public QWidget
{
    Q_OBJECT

public:
    struct Entry {
        const char *iconName = nullptr;
        QString label;
        std::function<void()> action;
        /**
         * 置灰、不可点击（批量操作浮层里「选中 0 首」时的动作项用）。
         * 默认 false，现有各处 Menu 项的构造方式完全不受影响。
         */
        bool disabled = false;
    };

    /** 在 globalPos 显示菜单；anchor 用于 Popup 父级与主题 */
    static void showAt(QWidget *anchor, const QPoint &globalPos, const QList<Entry> &entries);

private:
    explicit SongContextMenuPopup(QWidget *anchor, const QList<Entry> &entries);

    void applyTheme();
    void positionAt(const QPoint &globalPos);

    QWidget *m_anchor = nullptr;
    QWidget *m_panel = nullptr;
    QList<Entry> m_entries;
    QList<QWidget *> m_rowWidgets;
};
