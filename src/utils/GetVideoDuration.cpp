#include <QString>
#include <QProcess>
#include <QStringList>
#include <QRegularExpression>
#include <QRegularExpressionMatch>

QString getVideoDuration(const QString &ffmpegPath, const QString &videoPath)
{
    QProcess process;
    QStringList args = {"-i", videoPath};
    process.start(ffmpegPath, args);
    process.waitForStarted();
    process.waitForFinished();
    QString stdErr = process.readAllStandardError();
    QRegularExpression re("Duration: (\\d{2}:\\d{2}:\\d{2})");
    QRegularExpressionMatch match = re.match(stdErr);
    if (match.hasMatch())
        return match.captured(1);
    return "00:00:05";
}