QT += core gui qml quick quickcontrols2 dbus network concurrent testlib
CONFIG += c++17 testcase
TARGET = lensdesk_tests
TEMPLATE = app
INCLUDEPATH += ../src
HEADERS += ../src/backend.h ../src/theme.h ../src/translator.h
SOURCES += lensdesk_tests.cpp ../src/backend.cpp ../src/theme.cpp ../src/translator.cpp
RESOURCES += ../src/resources.qrc
