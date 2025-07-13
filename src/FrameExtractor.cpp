#include <QApplication>
#include <QWidget>
#include <QFileDialog>
#include <QPushButton>
#include <QLineEdit>
#include <QLabel>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QProcess>
#include <QMessageBox>
#include <QDir>
#include <QPlainTextEdit>
#include <QGroupBox>
#include <QFont>
#include <QStyleFactory>
#include <QComboBox>
#include <QPainter>
#include <QGraphicsDropShadowEffect>
#include <QMouseEvent>
#include <QProgressDialog>
#include <QTimer>
#include <QRegularExpression>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#pragma comment(lib, "dwmapi.lib")
#endif

#include "utils/GetVideoDuration.h"
#include "utils/DownloadFFmpeg.h"
#include "utils/FindFFmpeg.h"

class RoundedWindow : public QWidget
{
public:
    RoundedWindow()
    {
        setWindowFlags(Qt::FramelessWindowHint | Qt::WindowSystemMenuHint);
        setAttribute(Qt::WA_TranslucentBackground);
        enableBlur();
    }

protected:
    QPoint dragPos;
    void mousePressEvent(QMouseEvent *event) override
    {
        if (event->button() == Qt::LeftButton)
            dragPos = event->globalPosition().toPoint() - frameGeometry().topLeft();
    }
    void mouseMoveEvent(QMouseEvent *event) override
    {
        if (event->buttons() & Qt::LeftButton)
            move(event->globalPosition().toPoint() - dragPos);
    }
    void paintEvent(QPaintEvent *) override
    {
        QPainter p(this);
        p.setRenderHint(QPainter::Antialiasing);
        p.setBrush(QColor(30, 30, 30, 230));
        p.setPen(Qt::NoPen);
        p.drawRoundedRect(rect(), 12, 12);
    }
    void enableBlur()
    {
#ifdef Q_OS_WIN
        HWND hwnd = (HWND)winId();
        DWM_BLURBEHIND bb = {};
        bb.dwFlags = DWM_BB_ENABLE;
        bb.fEnable = true;
        DwmEnableBlurBehindWindow(hwnd, &bb);
#endif
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setStyle(QStyleFactory::create("Fusion"));

    QPalette palette;
    palette.setColor(QPalette::Window, QColor(30, 30, 30));
    palette.setColor(QPalette::WindowText, Qt::white);
    palette.setColor(QPalette::Base, QColor(45, 45, 45));
    palette.setColor(QPalette::Text, Qt::white);
    palette.setColor(QPalette::Button, QColor(70, 70, 70));
    palette.setColor(QPalette::ButtonText, Qt::white);
    palette.setColor(QPalette::Highlight, QColor(42, 130, 218));
    palette.setColor(QPalette::HighlightedText, Qt::black);
    app.setPalette(palette);

    QString ffmpegPath = findFFmpeg();
    if (ffmpegPath.isEmpty())
    {
        QMessageBox msgBox;
        msgBox.setWindowTitle("FFmpeg Not Found");
        msgBox.setText("❌ FFmpeg not found. Install now?");
        QPushButton *installBtn = msgBox.addButton("Install", QMessageBox::AcceptRole);
        msgBox.addButton(QMessageBox::Cancel);
        msgBox.exec();
        if (msgBox.clickedButton() == installBtn)
        {
            ffmpegPath = installFFmpeg(nullptr);
            if (ffmpegPath.isEmpty())
                return -1;
        }
        else
            return -1;
    }

    RoundedWindow window;
    window.setWindowTitle("Frame Extractor");
    window.resize(540, 460);

    QVBoxLayout *layout = new QVBoxLayout(&window);
    layout->setContentsMargins(16, 16, 10, 10);
    layout->setSpacing(8);

    QHBoxLayout *closeLayout = new QHBoxLayout();
    QPushButton *closeBtn = new QPushButton("✖");
    closeBtn->setFixedSize(30, 30);
    closeBtn->setStyleSheet("QPushButton { background-color: #aa0000; color: white; border: none; border-radius: 15px; } QPushButton:hover { background-color: red; }");
    QObject::connect(closeBtn, &QPushButton::clicked, &window, &QWidget::close);
    closeLayout->addWidget(new QLabel("Frame Extractor"));
    closeLayout->addWidget(closeBtn, 0, Qt::AlignRight);

    QHBoxLayout *videoLayout = new QHBoxLayout();
    QLineEdit *videoPathEdit = new QLineEdit();
    QPushButton *browseVideoBtn = new QPushButton("Browse");
    videoLayout->addWidget(new QLabel("🎬 Input Video:"));
    videoLayout->addWidget(videoPathEdit);
    videoLayout->addWidget(browseVideoBtn);

    QHBoxLayout *outputLayout = new QHBoxLayout();
    QLineEdit *outputDirEdit = new QLineEdit();
    QPushButton *browseOutputBtn = new QPushButton("Browse");
    outputLayout->addWidget(new QLabel("📂 Output Dir:"));
    outputLayout->addWidget(outputDirEdit);
    outputLayout->addWidget(browseOutputBtn);

    QHBoxLayout *timeLayout = new QHBoxLayout();
    QLineEdit *startTimeEdit = new QLineEdit("00:00:00");
    QLineEdit *endTimeEdit = new QLineEdit("00:00:05");
    timeLayout->addWidget(new QLabel("Start:"));
    timeLayout->addWidget(startTimeEdit);
    timeLayout->addSpacing(10);
    timeLayout->addWidget(new QLabel("End:"));
    timeLayout->addWidget(endTimeEdit);

    QHBoxLayout *settingsLayout = new QHBoxLayout();
    QLineEdit *fpsEdit = new QLineEdit("10");
    QLineEdit *frameNameEdit = new QLineEdit("frame");
    QComboBox *formatCombo = new QComboBox();
    formatCombo->addItems({"png", "jpg", "jpeg"});
    settingsLayout->addWidget(new QLabel("FPS:"));
    settingsLayout->addWidget(fpsEdit);
    settingsLayout->addWidget(new QLabel("Name:"));
    settingsLayout->addWidget(frameNameEdit);
    settingsLayout->addWidget(new QLabel("Format:"));
    settingsLayout->addWidget(formatCombo);

    QPushButton *extractBtn = new QPushButton("Extract Frames");
    extractBtn->setMinimumHeight(40);

    layout->addLayout(closeLayout);
    layout->addLayout(videoLayout);
    layout->addLayout(outputLayout);
    layout->addLayout(timeLayout);
    layout->addLayout(settingsLayout);
    layout->addWidget(extractBtn);

    QObject::connect(browseVideoBtn, &QPushButton::clicked, [&]()
                     {
        QString path = QFileDialog::getOpenFileName(&window, "Select Video File");
        if (!path.isEmpty()) {
            videoPathEdit->setText(path);
            QString duration = getVideoDuration(ffmpegPath, path);
            if (!duration.isEmpty()) endTimeEdit->setText(duration);
        } });

    QObject::connect(videoPathEdit, &QLineEdit::textChanged, [&](const QString &text)
                     {
        if (text.endsWith("/") || QFile::exists(text)) {
            QString duration = getVideoDuration(ffmpegPath, text);
            if (!duration.isEmpty()) endTimeEdit->setText(duration);
        } });

    QObject::connect(browseOutputBtn, &QPushButton::clicked, [&]()
                     {
        QString path = QFileDialog::getExistingDirectory(&window, "Select Output Directory");
        if (!path.isEmpty()) outputDirEdit->setText(path); });

    QObject::connect(extractBtn, &QPushButton::clicked, [&]()
                     {
        QString videoPath = videoPathEdit->text();
        QString outputDir = outputDirEdit->text();
        QString startTime = startTimeEdit->text();
        QString endTime = endTimeEdit->text();
        QString fps = fpsEdit->text();
        QString prefix = frameNameEdit->text();
        QString format = formatCombo->currentText();

        if (videoPath.isEmpty() || outputDir.isEmpty() || prefix.isEmpty()) {
            QMessageBox::warning(&window, "Missing Fields", "Please fill in all fields.");
            return;
        }
        
        QDir().mkpath(outputDir);
        QProgressDialog progress("Extracting frames...", QString(), 0, 0, &window);
        progress.setWindowModality(Qt::WindowModal);
        progress.setCancelButton(nullptr);
        progress.show();

        QString outputPattern = QString("%1/%2%%d.%3").arg(outputDir, prefix, format);
        QStringList args = {
            "-ss", startTime,
            "-to", endTime,
            "-i", videoPath,
            "-vf", QString("fps=%1").arg(fps),
            "-fps_mode", "vfr",
            outputPattern
        };

        QProcess process;
        process.start(ffmpegPath, args);
        if (!process.waitForStarted()) {
            QMessageBox::critical(&window, "FFmpeg Error", "Failed to start FFmpeg.");
            return;
        }

        process.waitForFinished(-1);
        progress.close();

        if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
            QMessageBox::information(&window, "Done", "Frames extracted successfully.");
        } else {
            QString errMsg = process.readAllStandardError();
            QDialog *errorDialog = new QDialog(&window);
            errorDialog->setWindowTitle("FFmpeg Error");
            errorDialog->setModal(true);

            QVBoxLayout *dialogLayout = new QVBoxLayout(errorDialog);
            dialogLayout->addWidget(new QLabel("Failed to extract frames. Here's the log:"));

            QPlainTextEdit *logBox = new QPlainTextEdit();
            logBox->setReadOnly(true);
            logBox->setPlainText(errMsg);
            logBox->setWordWrapMode(QTextOption::NoWrap);
            dialogLayout->addWidget(logBox);

            QPushButton *closeBtn = new QPushButton("Close");
            QObject::connect(closeBtn, &QPushButton::clicked, errorDialog, &QDialog::accept);
            dialogLayout->addWidget(closeBtn);

            errorDialog->adjustSize();
            QRect parentGeom = window.geometry();
            int x = parentGeom.x() + (parentGeom.width() - errorDialog->width()) / 2;
            int y = parentGeom.y() + (parentGeom.height() - errorDialog->height()) / 2;
            errorDialog->move(x, y);

            errorDialog->exec();
        } });

    window.show();
    return app.exec();
}
