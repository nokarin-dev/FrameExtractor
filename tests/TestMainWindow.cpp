#include "TestMainWindow.h"
#include <QtTest/QtTest>
#include <QtWidgets/QPushButton> 
#include <QMainWindow>
#include <QVBoxLayout>
#include <qtestmouse.h>
#include <qtestsupport_widgets.h>

class DummyWindow : public QMainWindow {
public:
    QPushButton* button;
    DummyWindow() {
        auto *widget = new QWidget(this);
        auto *layout = new QVBoxLayout(widget);

        button = new QPushButton("Click me");
        layout->addWidget(button);

        widget->setLayout(layout);
        setCentralWidget(widget);
        setWindowTitle("Dummy Window");

        connect(button, &QPushButton::clicked, this, []() {
            qDebug("Button clicked!");
        });
    }
};

void TestMainWindow::initTestCase() {
    qDebug("Starting UI tests...");
}

void TestMainWindow::cleanupTestCase() {
    qDebug("Done.");
}

void TestMainWindow::test_windowTitle() {
    DummyWindow window;
    QCOMPARE(window.windowTitle(), QString("Dummy Window"));
}

void TestMainWindow::test_buttonClick() {
    DummyWindow window;
    window.show();
    QTest::qWaitForWindowExposed(&window);

    QPushButton* button = window.button;
    QVERIFY(button != nullptr);

    QSignalSpy spy(button, &QPushButton::clicked);
    QVERIFY(spy.isValid());

    QPoint center = button->rect().center();

    QMouseEvent pressEvent(QEvent::MouseButtonPress, center, Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(button, &pressEvent);

    QMouseEvent releaseEvent(QEvent::MouseButtonRelease, center, Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(button, &releaseEvent);

    QCOMPARE(spy.count(), 1);
}