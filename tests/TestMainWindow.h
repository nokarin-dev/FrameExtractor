#pragma once

#include <QObject>

class TestMainWindow : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void test_windowTitle();
    void test_buttonClick();
};