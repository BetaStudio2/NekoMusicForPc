#pragma once

/**
 * @file i18n.h
 * @brief 简易国际化 — 支持中文/英文
 */

#include <QString>
#include <QStringList>

class I18n
{
public:
    enum Language
    {
        NyaCN,
        ZhCN,
        EnUS
    };

    static I18n &instance();

    void setLanguage(Language lang);
    Language language() const { return m_lang; }

    /**
     * 取文案。当前语言表里没有该键时**回退到简中表**，简中也没有才返回键名本身
     * （以前直接返回键名，漏翻一个键界面上就会冒出 `duration` 这种标识符）。
     */
    QString tr(const QString &key) const;

    /**
     * i18n 键集合自检：返回「某张表缺了某个键」的清单（形如 "enUS:someKey"）。
     * 空列表表示三张表键集合一致。启动时调一次打到日志里，
     * 避免以后新增文案只补了一两张表；构建期可跑 tools/check-i18n-keys.ps1 做同样的检查。
     */
    static QStringList missingKeys();

    QString settingsTitle() const;
    QString version() const;
    QString system() const;
    QString languageLabel() const;
    QString languageNya() const;
    QString languageChinese() const;
    QString languageEnglish() const;
    QString languageZhCN() const;
    QString languageEnUS() const;
    QString showWindow() const;
    QString exitApp() const;

private:
    I18n() = default;
    Language m_lang = ZhCN;
};
