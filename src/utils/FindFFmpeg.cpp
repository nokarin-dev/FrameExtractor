#include "FindFFmpeg.h"
#include <QStandardPaths>
#include <QFileInfo>
#include <QDir>
#include <QProcessEnvironment>
#include <QtSystemDetection>

QString findFFmpeg()
{
    QString ffmpeg = QStandardPaths::findExecutable("ffmpeg");
    if (!ffmpeg.isEmpty())
        return ffmpeg;

#ifdef Q_OS_WIN
    QStringList commonPaths = {
        "C:/ffmpeg/bin/ffmpeg.exe",
        "C:/Program Files/ffmpeg/bin/ffmpeg.exe",
        "C:/Program Files (x86)/ffmpeg/bin/ffmpeg.exe"};
#elif defined(Q_OS_MACOS)
    QStringList commonPaths = {
        "/usr/local/bin/ffmpeg",
        "/opt/homebrew/bin/ffmpeg"};
#else
    QStringList commonPaths = {
        "/usr/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/snap/bin/ffmpeg"};
#endif
    for (const QString &path : commonPaths)
    {
        if (QFileInfo::exists(path))
            return path;
    }

    return ""; // Not found
}