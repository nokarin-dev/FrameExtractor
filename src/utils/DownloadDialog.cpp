#include <QVBoxLayout>
#include <QLabel>
#include <QProgressBar>

#include "DownloadDialog.h"

DownloadDialog::DownloadDialog(QWidget* parent)
    : QDialog(parent)
{
    setWindowTitle("Downloading FFmpeg");
    resize(400, 120);

    QVBoxLayout* layout = new QVBoxLayout(this);

    statusLabel = new QLabel("Initializing...");
    progressBar = new QProgressBar();
    progressBar->setRange(0, 100);
    progressBar->setValue(0);

    layout->addWidget(statusLabel);
    layout->addWidget(progressBar);
}

void DownloadDialog::setProgress(int percent)
{
    if (progressBar)
        progressBar->setValue(percent);
}

void DownloadDialog::setStatus(const QString& text)
{
    if (statusLabel)
        statusLabel->setText(text);
}