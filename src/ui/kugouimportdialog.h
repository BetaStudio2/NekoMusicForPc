#pragma once

/**
 * @file kugouimportdialog.h
 * @brief 酷狗音乐歌单导入对话框
 */

#include "ui/externalimportdialog.h"

/**
 * 酷狗音乐歌单导入对话框：仅提供酷狗专属的输入解析与详情请求，
 * UI 与导入流程复用 ExternalImportDialog。
 */
class KugouImportDialog : public ExternalImportDialog
{
    Q_OBJECT

public:
    explicit KugouImportDialog(ApiClient *apiClient, QWidget *parent = nullptr);

protected:
    QString parseInput(const QString &input) const override;
    void fetchPlaylist(const QString &id, FetchCallback cb) override;
};
