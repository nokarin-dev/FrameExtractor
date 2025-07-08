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

#include "utils/find_ffmpeg.h"

class RoundedWindow : public QWidget {
public:
    RoundedWindow() {
        setWindowFlags(Qt::FramelessWindowHint | Qt::WindowSystemMenuHint);
        setAttribute(Qt::WA_TranslucentBackground);
        enableBlur();
    }

protected:
    QPoint dragPos;

    void mousePressEvent(QMouseEvent* event) override {
        if (event->button() == Qt::LeftButton) {
            dragPos = event->globalPosition().toPoint() - frameGeometry().topLeft();
            event->accept();
        }
    }

    void mouseMoveEvent(QMouseEvent* event) override {
        if (event->buttons() & Qt::LeftButton) {
            move(event->globalPosition().toPoint() - dragPos);
            event->accept();
        }
    }

    void paintEvent(QPaintEvent*) override {
        QPainter p(this);
        p.setRenderHint(QPainter::Antialiasing);
        p.setBrush(QColor(30, 30, 30, 220));  // Semi-transparent
        p.setPen(Qt::NoPen);
        p.drawRoundedRect(rect(), 12, 12);
    }

    void enableBlur() {
        #ifdef Q_OS_WIN
        HWND hwnd = (HWND)winId();

        DWM_BLURBEHIND bb = {};
        bb.dwFlags = DWM_BB_ENABLE;
        bb.fEnable = true;
        bb.hRgnBlur = nullptr;
        DwmEnableBlurBehindWindow(hwnd, &bb);
        #elif defined(Q_OS_LINUX)
        // KDE Wayland/X11 compositor blur hint
        setProperty("_KDE_NET_WM_BLUR_BEHIND_REGION", QRegion(rect()));
        #elif defined(Q_OS_MAC)
        // Optional: macOS native blur may require Cocoa bridge (Objective-C)
        #endif
    }
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    QApplication::setStyle(QStyleFactory::create("Fusion"));

    QPalette darkPalette;
    darkPalette.setColor(QPalette::Window, QColor(30, 30, 30));
    darkPalette.setColor(QPalette::WindowText, Qt::white);
    darkPalette.setColor(QPalette::Base, QColor(25, 25, 25));
    darkPalette.setColor(QPalette::AlternateBase, QColor(53, 53, 53));
    darkPalette.setColor(QPalette::ToolTipBase, Qt::white);
    darkPalette.setColor(QPalette::ToolTipText, Qt::white);
    darkPalette.setColor(QPalette::Text, Qt::white);
    darkPalette.setColor(QPalette::Button, QColor(50, 50, 50));
    darkPalette.setColor(QPalette::ButtonText, Qt::white);
    darkPalette.setColor(QPalette::BrightText, Qt::red);
    darkPalette.setColor(QPalette::Link, QColor(42, 130, 218));
    darkPalette.setColor(QPalette::Highlight, QColor(42, 130, 218));
    darkPalette.setColor(QPalette::HighlightedText, Qt::black);
    app.setPalette(darkPalette);

    QString ffmpegPath = findFFmpeg();
    if (ffmpegPath.isEmpty()) {
        qCritical() << "❌ FFmpeg not found. Make sure it is installed and in your PATH.";
        return -1;
    }

    RoundedWindow window;
    window.setWindowTitle("Frame Extractor");
    window.resize(640, 480);

    QVBoxLayout *layout = new QVBoxLayout(&window);
    layout->setContentsMargins(16, 16, 16, 16);

    QPushButton* closeBtn = new QPushButton("✖");
    closeBtn->setFixedSize(30, 30);
    closeBtn->setStyleSheet("QPushButton { background-color: #aa0000; color: white; border: none; border-radius: 15px; } QPushButton:hover { background-color: red; }");
    QObject::connect(closeBtn, &QPushButton::clicked, &window, &QWidget::close);
    layout->addWidget(closeBtn, 0, Qt::AlignRight);

    QGroupBox *inputGroup = new QGroupBox("🎬 Video Input");
    QVBoxLayout *inputLayout = new QVBoxLayout(inputGroup);
    QHBoxLayout *videoLayout = new QHBoxLayout();
    QLineEdit *videoPathEdit = new QLineEdit();
    QPushButton *browseBtn = new QPushButton("Browse...");
    videoLayout->addWidget(videoPathEdit);
    videoLayout->addWidget(browseBtn);
    inputLayout->addLayout(videoLayout);

    QGroupBox *timeGroup = new QGroupBox("⏱️ Time Range");
    QVBoxLayout *timeLayout = new QVBoxLayout(timeGroup);
    QLineEdit *startTimeEdit = new QLineEdit("00:00:00");
    QLineEdit *endTimeEdit = new QLineEdit("00:00:05");
    timeLayout->addWidget(new QLabel("Start Time (HH:MM:SS):"));
    timeLayout->addWidget(startTimeEdit);
    timeLayout->addWidget(new QLabel("End Time (HH:MM:SS):"));
    timeLayout->addWidget(endTimeEdit);

    QGroupBox *settingsGroup = new QGroupBox("⚙️ Settings");
    QVBoxLayout *settingsLayout = new QVBoxLayout(settingsGroup);

    QLineEdit *fpsEdit = new QLineEdit("10");
    settingsLayout->addWidget(new QLabel("FPS:"));
    settingsLayout->addWidget(fpsEdit);

    QLineEdit *frameNameEdit = new QLineEdit("frame");
    settingsLayout->addWidget(new QLabel("Frame Name Prefix:"));
    settingsLayout->addWidget(frameNameEdit);

    QComboBox *formatCombo = new QComboBox();
    formatCombo->addItems({"png", "jpg", "jpeg"});
    settingsLayout->addWidget(new QLabel("Image Format:"));
    settingsLayout->addWidget(formatCombo);

    QLineEdit *outputDirEdit = new QLineEdit();
    settingsLayout->addWidget(new QLabel("Output Directory:"));
    settingsLayout->addWidget(outputDirEdit);

    QPushButton *extractBtn = new QPushButton("Extract Frames");
    extractBtn->setMinimumHeight(40);

    layout->addWidget(inputGroup);
    layout->addWidget(timeGroup);
    layout->addWidget(settingsGroup);
    layout->addWidget(extractBtn);

    QObject::connect(browseBtn, &QPushButton::clicked, [&]() {
        QString fileName = QFileDialog::getOpenFileName(&window, "Select Video File");
        if (!fileName.isEmpty()) videoPathEdit->setText(fileName);
    });

    QObject::connect(extractBtn, &QPushButton::clicked, [&]() {
        QString videoPath = videoPathEdit->text();
        QString startTime = startTimeEdit->text();
        QString endTime = endTimeEdit->text();
        QString fps = fpsEdit->text();
        QString outputDir = outputDirEdit->text();
        QString prefix = frameNameEdit->text();
        QString format = formatCombo->currentText().trimmed().toLower();

        if (!(format == "png" || format == "jpg" || format == "jpeg")) {
            QMessageBox::warning(&window, "Invalid Format", "Supported formats are: png, jpg, jpeg.");
            return;
        }

        if (videoPath.isEmpty() || outputDir.isEmpty() || prefix.isEmpty()) {
            QMessageBox::warning(&window, "Input Error", "Please fill in all fields.");
            return;
        }

        QDir().mkpath(outputDir);
        QString outputPattern = QString("%1/%2%d.%3").arg(outputDir, prefix, format);

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
            QMessageBox::critical(&window, "Error", "Failed to start FFmpeg.");
            return;
        }

        process.waitForFinished(-1);
        QString stdErr = process.readAllStandardError();

        if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0) {
            QMessageBox::information(&window, "Success", "Frames extracted successfully.");
        } else {
            QString errMsg = QString("Failed to extract frames.\nExit Code: %1\nError:\n%2").arg(process.exitCode()).arg(stdErr);

            QDialog* errorDialog = new QDialog(&window);
            errorDialog->setWindowTitle("FFmpeg Error");
            errorDialog->resize(600, 400);

            QVBoxLayout* dialogLayout = new QVBoxLayout(errorDialog);
            QLabel* label = new QLabel("Failed to extract frames. Here's the log:");
            dialogLayout->addWidget(label);

            QPlainTextEdit* logBox = new QPlainTextEdit();
            logBox->setReadOnly(true);
            logBox->setPlainText(errMsg);
            dialogLayout->addWidget(logBox);

            QPushButton* closeBtn = new QPushButton("Close");
            QObject::connect(closeBtn, &QPushButton::clicked, errorDialog, &QDialog::accept);
            dialogLayout->addWidget(closeBtn);

            errorDialog->exec();
        }
    });

    window.show();
    return app.exec();
}