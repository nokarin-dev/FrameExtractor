#pragma once

#include <QDialog>

class QProgressBar;
class QLabel;

class DownloadDialog : public QDialog
{
    Q_OBJECT

public:
    explicit DownloadDialog(QWidget *parent = nullptr);

    void setProgress(int percent);
    void setStatus(const QString &text);

private:
    QProgressBar *progressBar;
    QLabel *statusLabel;
};