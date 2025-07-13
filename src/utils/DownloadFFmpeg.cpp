#include <QApplication>
#include <QByteArray>
#include <QCoreApplication>
#include <QMessageBox>
#include <QStandardPaths>
#include <QFile>
#include <QProcess>
#include <QDir>
#include <QEventLoop>
#include <QUrl>

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>

#include "DownloadDialog.h"

QString installFFmpeg(QWidget *parent)
{
    QString ffmpegUrl;
    QString archiveExt;
    QString outputBinaryName;

    QString os;

#ifdef Q_OS_WIN
    os = "windows";
    outputBinaryName = "ffmpeg.exe";
#elif defined(Q_OS_LINUX)
    os = "linux";
    outputBinaryName = "ffmpeg";
#elif defined(Q_OS_MACOS)
    os = "macos";
    outputBinaryName = "ffmpeg";
#else
    QMessageBox::critical(parent, "Unsupported", "Unsupported OS.");
    return QString();
#endif

#if defined(Q_PROCESSOR_X86_64)
    QString arch = "x64";
#elif defined(Q_PROCESSOR_ARM_64)
    QString arch = "arm64";
#else
    QMessageBox::critical(parent, "Unsupported", "Unsupported architecture.");
    return QString();
#endif

#ifdef Q_OS_WIN
    ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";
    archiveExt = "zip";
#elif defined(Q_OS_LINUX)
    ffmpegUrl = "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz";
    archiveExt = "tar.xz";
#elif defined(Q_OS_MACOS)
    ffmpegUrl = "https://evermeet.cx/ffmpeg/ffmpeg.zip";
    archiveExt = "zip";
#endif

#ifdef Q_OS_WIN
    QProcess winget;
    winget.start("winget", {"list"});
    if (winget.waitForStarted() && winget.waitForFinished())
    {
        QString output = winget.readAllStandardOutput();
        if (!output.isEmpty())
        {
            int result = QMessageBox::question(parent,
                                               "Use Winget?",
                                               "Winget package manager is available.\nDo you want to install FFmpeg using winget?",
                                               QMessageBox::Yes | QMessageBox::No);
            if (result == QMessageBox::Yes)
            {
                QProcess::execute("winget", {"install", "--id", "Gyan.FFmpeg", "-e", "--accept-source-agreements", "--accept-package-agreements"});
                return "ffmpeg"; // Assume available in PATH
            }
        }
    }
#endif

    DownloadDialog dialog(parent);
    dialog.show();

    QUrl url{ffmpegUrl};
    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    QNetworkReply *reply = manager.get(request);

    QObject::connect(reply, &QNetworkReply::downloadProgress, [&](qint64 bytesReceived, qint64 bytesTotal)
                     {
        if (bytesTotal > 0) {
            int percent = static_cast<int>((bytesReceived * 100) / bytesTotal);
            dialog.setProgress(percent);
            dialog.setStatus(QString("Downloading FFmpeg... %1%").arg(percent));
        } });

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error())
    {
        QMessageBox::critical(parent, "Download Failed", reply->errorString());
        reply->deleteLater();
        return QString();
    }

    QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(appData);
    QString archivePath = appData + "/ffmpeg_download." + archiveExt;

    QFile file(archivePath);
    if (!file.open(QIODevice::WriteOnly))
    {
        QMessageBox::critical(parent, "Write Error", "Can't save archive.");
        return QString();
    }
    file.write(reply->readAll());
    file.close();
    reply->deleteLater();

    dialog.setStatus("Extracting archive...");
    QApplication::processEvents();

    QString extractDir = appData + "/ffmpeg_bin";
    QDir().mkpath(extractDir);
    QString ffmpegBinary;

#ifdef Q_OS_WIN
    QProcess::execute("powershell", {"-Command", QString("Expand-Archive -Path \"%1\" -DestinationPath \"%2\" -Force").arg(archivePath, extractDir)});
#elif defined(Q_OS_LINUX) || defined(Q_OS_MACOS)
    QProcess::execute("tar", {"-xf", archivePath, "-C", extractDir});
#endif
    QDir root(extractDir);
    QStringList entries = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &dirName : entries)
    {
        QDir subDir(root.absoluteFilePath(dirName));
        QString path = subDir.absoluteFilePath(outputBinaryName);
        if (QFile::exists(path))
        {
            ffmpegBinary = path;
            break;
        }
    }

    if (ffmpegBinary.isEmpty())
    {
        QString path = root.absoluteFilePath(outputBinaryName);
        if (QFile::exists(path))
        {
            ffmpegBinary = path;
        }
    }

    if (ffmpegBinary.isEmpty())
    {
        QMessageBox::critical(parent, "Extract Failed", "Failed to locate ffmpeg binary after extraction.");
        return QString();
    }

    QMessageBox::information(parent, "FFmpeg Installed", "FFmpeg has been downloaded and installed.");
    return ffmpegBinary;
}