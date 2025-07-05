#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSslSocket>
#include <QDebug>
#include <QSslCipher>
#include "mqttclient.h"
#include "applicationcontroller.h"

// Singleton provider for ApplicationController
static QObject *applicationControllerProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)
    
    return new ApplicationController();
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    // Set application properties
    app.setApplicationName("MQTT TLS Client QML");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Simone");
    app.setOrganizationDomain("simone dev");
    
    // Set Quick Controls style
    QQuickStyle::setStyle("Material");
    
    // Register QML types
    qmlRegisterType<MqttClient>("MqttClient", 1, 0, "MqttClient");
    qmlRegisterSingletonType<ApplicationController>("AppController", 1, 0, "AppController", 
                                                   applicationControllerProvider);
    
    // Create QML engine
    QQmlApplicationEngine engine;
    
    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    
    engine.load(url);
    
    // Print debug information
    qDebug() << "Application started";
    qDebug() << "Qt version:" << QT_VERSION_STR;
    qDebug() << "SSL support:" << QSslSocket::supportsSsl();
    qDebug() << "SSL library version:" << QSslSocket::sslLibraryVersionString();

    // Get and filter supported ciphers
    QList<QSslCipher> allCiphers = QSslConfiguration::supportedCiphers();
    QList<QSslCipher> secureCiphers;

    // Filter for strong ciphers only
    qDebug() << "Supported ciphers (strong only):";
    for (const QSslCipher &cipher : std::as_const(allCiphers)) {
        if (cipher.usedBits() >= 128 &&
            (cipher.protocol() == QSsl::TlsV1_2 || cipher.protocol() == QSsl::TlsV1_3)) {
            secureCiphers.append(cipher);
            qDebug() << cipher.name() << " - "
                     << cipher.usedBits() << " bits";
        }
    }

    qDebug() << QString("SSL Info: Using %1 secure ciphers out of %2 total")
                       .arg(secureCiphers.size()).arg(allCiphers.size());


    
    return app.exec();
}
