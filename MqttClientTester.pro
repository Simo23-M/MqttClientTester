QT += core network mqtt qml quick quickcontrols2 widgets

CONFIG += c++17

TARGET = mqtt_tls_client_qml
TEMPLATE = app

SOURCES += \
    main.cpp \
    mqttclient.cpp \
    applicationcontroller.cpp

HEADERS += \
    mqttclient.h \
    applicationcontroller.h

RESOURCES += \
    qml.qrc

# Enable SSL/TLS support
QT += network-private

# QML import path
QML_IMPORT_PATH =

# QML designer support
QML_DESIGNER_IMPORT_PATH =

# Version info
VERSION = 1.0.0
QMAKE_TARGET_COMPANY = "Your Company"
QMAKE_TARGET_PRODUCT = "MQTT TLS Client QML"
QMAKE_TARGET_DESCRIPTION = "Qt MQTT Client with TLS Support (QML)"
