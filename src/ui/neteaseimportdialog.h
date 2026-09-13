#pragma once

/**
 * @file neteaseimportdialog.h
 * @brief 网易云歌单导入对话框
 */

#include "ui/externalimportdialog.h"

/**
 * 网易云歌单导入对话框：仅提供网易云专属的输入解析与详情请求，
 * UI 与导入流程复用 ExternalImportDialog。
 */
class NeteaseImportDialog : public ExternalImportDialog
{
    Q_OBJECT

public:
    explicit NeteaseImportDialog(ApiClient *apiClient, QWidget *parent = nullptr);

protected:
    QString parseInput(const QString &input) const override;
    void fetchPlaylist(const QString &id, FetchCallback cb) override;
};
