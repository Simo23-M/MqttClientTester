#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSslSocket>
#include <QDebug>
#include <QSslCipher>
#include <QCommandLineParser>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include "mqttclient.h"
#include "applicationcontroller.h"
#include "commandqueue.h"
#include "mqtttreemodel.h"

// Structure to hold connection settings from args/config
struct ConnectionSettings {
    QString host;
    int port = 0;
    QString clientId;
    QString username;
    QString password;
    QString caCertPath;
    QString clientCertPath;
    QString clientKeyPath;
    bool autoConnect = false;
};

ConnectionSettings loadConfigFile(const QString &filePath) {
    ConnectionSettings settings;
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Cannot open config file:" << filePath;
        return settings;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "Config file JSON parse error:" << parseError.errorString();
        return settings;
    }

    if (!doc.isObject()) {
        qWarning() << "Config file must contain a JSON object";
        return settings;
    }

    QJsonObject obj = doc.object();
    if (obj.contains("host")) settings.host = obj.value("host").toString();
    if (obj.contains("port")) settings.port = obj.value("port").toInt();
    if (obj.contains("clientId")) settings.clientId = obj.value("clientId").toString();
    if (obj.contains("username")) settings.username = obj.value("username").toString();
    if (obj.contains("password")) settings.password = obj.value("password").toString();
    if (obj.contains("caCertPath")) settings.caCertPath = obj.value("caCertPath").toString();
    if (obj.contains("clientCertPath")) settings.clientCertPath = obj.value("clientCertPath").toString();
    if (obj.contains("clientKeyPath")) settings.clientKeyPath = obj.value("clientKeyPath").toString();
    if (obj.contains("autoConnect")) settings.autoConnect = obj.value("autoConnect").toBool();

    qDebug() << "Loaded config file:" << filePath;
    return settings;
}

// Singleton provider for ApplicationController
static QObject *applicationControllerProvider(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine)
    Q_UNUSED(scriptEngine)

    return new ApplicationController();
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Set application properties
    app.setApplicationName("MQTT TLS Client QML");
    app.setWindowIcon(QIcon(":/AppIcon.png"));
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Simone");
    app.setOrganizationDomain("simone dev");

    // Parse command line arguments
    QCommandLineParser parser;
    parser.setApplicationDescription("MQTT TLS Client - A Qt/QML MQTT client with TLS support");
    parser.addHelpOption();
    parser.addVersionOption();

    // Connection settings options
    QCommandLineOption hostOption(QStringList() << "H" << "host",
        "MQTT broker hostname or IP address", "host");
    QCommandLineOption portOption(QStringList() << "p" << "port",
        "MQTT broker port (default: 1883)", "port");
    QCommandLineOption clientIdOption(QStringList() << "i" << "client-id",
        "Client ID for MQTT connection", "clientId");
    QCommandLineOption usernameOption(QStringList() << "u" << "username",
        "Username for MQTT authentication", "username");
    QCommandLineOption passwordOption(QStringList() << "P" << "password",
        "Password for MQTT authentication", "password");
    QCommandLineOption caCertOption("ca-cert",
        "Path to CA certificate file for TLS", "path");
    QCommandLineOption clientCertOption("client-cert",
        "Path to client certificate file for TLS", "path");
    QCommandLineOption clientKeyOption("client-key",
        "Path to client private key file for TLS", "path");
    QCommandLineOption configOption(QStringList() << "c" << "config",
        "Path to JSON configuration file", "path");
    QCommandLineOption autoConnectOption(QStringList() << "a" << "auto-connect",
        "Automatically connect on startup");

    parser.addOption(hostOption);
    parser.addOption(portOption);
    parser.addOption(clientIdOption);
    parser.addOption(usernameOption);
    parser.addOption(passwordOption);
    parser.addOption(caCertOption);
    parser.addOption(clientCertOption);
    parser.addOption(clientKeyOption);
    parser.addOption(configOption);
    parser.addOption(autoConnectOption);

    parser.process(app);

    // Load settings from config file first (if specified)
    ConnectionSettings settings;
    if (parser.isSet(configOption)) {
        settings = loadConfigFile(parser.value(configOption));
    }

    // Command line arguments override config file settings
    if (parser.isSet(hostOption)) settings.host = parser.value(hostOption);
    if (parser.isSet(portOption)) settings.port = parser.value(portOption).toInt();
    if (parser.isSet(clientIdOption)) settings.clientId = parser.value(clientIdOption);
    if (parser.isSet(usernameOption)) settings.username = parser.value(usernameOption);
    if (parser.isSet(passwordOption)) settings.password = parser.value(passwordOption);
    if (parser.isSet(caCertOption)) settings.caCertPath = parser.value(caCertOption);
    if (parser.isSet(clientCertOption)) settings.clientCertPath = parser.value(clientCertOption);
    if (parser.isSet(clientKeyOption)) settings.clientKeyPath = parser.value(clientKeyOption);
    if (parser.isSet(autoConnectOption)) settings.autoConnect = true;

    // Set Quick Controls style
    QQuickStyle::setStyle("Material");

    // Register QML types
    qmlRegisterType<MqttClient>("MqttClient", 1, 0, "MqttClient");
    qmlRegisterType<CommandQueue>("CommandQueue", 1, 0, "CommandQueue");
    qmlRegisterType<MqttTreeModel>("MqttTreeModel", 1, 0, "MqttTreeModel");
    qmlRegisterSingletonType<ApplicationController>("AppController", 1, 0, "AppController",
                                                    applicationControllerProvider);

    // Create QML engine
    QQmlApplicationEngine engine;

    // Expose connection settings to QML
    engine.rootContext()->setContextProperty("startupHost", settings.host);
    engine.rootContext()->setContextProperty("startupPort", settings.port);
    engine.rootContext()->setContextProperty("startupClientId", settings.clientId);
    engine.rootContext()->setContextProperty("startupUsername", settings.username);
    engine.rootContext()->setContextProperty("startupPassword", settings.password);
    engine.rootContext()->setContextProperty("startupCaCertPath", settings.caCertPath);
    engine.rootContext()->setContextProperty("startupClientCertPath", settings.clientCertPath);
    engine.rootContext()->setContextProperty("startupClientKeyPath", settings.clientKeyPath);
    engine.rootContext()->setContextProperty("startupAutoConnect", settings.autoConnect);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
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
