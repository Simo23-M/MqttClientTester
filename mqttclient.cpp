#include "mqttclient.h"
#include <QFile>
#include <QSslSocket>
#include <QUuid>
#include <QDateTime>
#include <QSslCipher>

MqttClient::MqttClient(QObject *parent)
    : QObject(parent)
    , m_client(new QMqttClient(this))
    , m_reconnectTimer(new QTimer(this))
    , m_hostName("localhost")
    , m_port(8883)
    , m_autoReconnect(true)
    , m_reconnectInterval(5000)
{
    // Setup MQTT client connections
    connect(m_client, &QMqttClient::connected, this, &MqttClient::onConnected);
    connect(m_client, &QMqttClient::disconnected, this, &MqttClient::onDisconnected);
    connect(m_client, &QMqttClient::stateChanged, this, &MqttClient::onStateChanged);
    connect(m_client, &QMqttClient::errorChanged, this, &MqttClient::onErrorChanged);
    connect(m_client, &QMqttClient::pingResponseReceived, this, &MqttClient::onPingResponseReceived);
    
    // Setup reconnection timer
    m_reconnectTimer->setSingleShot(true);
    connect(m_reconnectTimer, &QTimer::timeout, [this]() {
        if (m_autoReconnect && m_client->state() == QMqttClient::Disconnected) {
            emitLogMessage("Attempting to reconnect to MQTT broker...");
            m_client->connectToHost();
        }
    });
    
    // Setup SSL configuration
    setupSslConfiguration();
    setupConnectionProperties();
    
    emitLogMessage("MQTT Client initialized");
}

MqttClient::~MqttClient()
{
    if (m_client->state() == QMqttClient::Connected) {
        m_client->disconnectFromHost();
    }
}

bool MqttClient::isConnected() const
{
    return m_client->state() == QMqttClient::Connected;
}

QString MqttClient::connectionStateString() const
{
    switch (m_client->state()) {
    case QMqttClient::Disconnected:
        return "Disconnected";
    case QMqttClient::Connecting:
        return "Connecting";
    case QMqttClient::Connected:
        return "Connected";
    default:
        return "Unknown";
    }
}

void MqttClient::setHostName(const QString &hostName)
{
    if (m_hostName != hostName) {
        m_hostName = hostName;
        emit hostNameChanged();
    }
}

void MqttClient::setPort(int port)
{
    if (m_port != port) {
        m_port = port;
        emit portChanged();
    }
}

void MqttClient::setClientId(const QString &clientId)
{
    if (m_clientId != clientId) {
        m_clientId = clientId;
        emit clientIdChanged();
    }
}

void MqttClient::setUsername(const QString &username)
{
    if (m_username != username) {
        m_username = username;
        emit usernameChanged();
    }
}

void MqttClient::setPassword(const QString &password)
{
    if (m_password != password) {
        m_password = password;
        emit passwordChanged();
    }
}

void MqttClient::setCaCertPath(const QString &path)
{
    if (m_caCertPath != path) {
        m_caCertPath = path;
        emit caCertPathChanged();
    }
}

void MqttClient::setClientCertPath(const QString &path)
{
    if (m_clientCertPath != path) {
        m_clientCertPath = path;
        emit clientCertPathChanged();
    }
}

void MqttClient::setClientKeyPath(const QString &path)
{
    if (m_clientKeyPath != path) {
        m_clientKeyPath = path;
        emit clientKeyPathChanged();
    }
}

void MqttClient::connectToHost()
{
    QString finalClientId = m_clientId.isEmpty() ? QUuid::createUuid().toString() : m_clientId;
    
    emitLogMessage(QString("Connecting to MQTT broker: %1:%2").arg(m_hostName).arg(m_port));
    
    m_client->setHostname(m_hostName);
    m_client->setPort(static_cast<quint16>(m_port));
    m_client->setClientId(finalClientId);
    
    if (!m_username.isEmpty()) {
        m_client->setUsername(m_username);
    }
    
    if (!m_password.isEmpty()) {
        m_client->setPassword(m_password);
    }
    
    // Load certificates before connecting
    loadCertificates();
    
    // Connect with TLS
    m_client->connectToHostEncrypted(m_sslConfig);
}

void MqttClient::disconnectFromHost()
{
    m_autoReconnect = false;
    m_reconnectTimer->stop();
    
    if (m_client->state() == QMqttClient::Connected) {
        m_client->disconnectFromHost();
        emitLogMessage("Disconnecting from broker");
    }
}

void MqttClient::subscribe(const QString &topic, int qos)
{
    if (m_client->state() == QMqttClient::Connected) {
        auto subscription = m_client->subscribe(topic, static_cast<quint8>(qos));
        if (subscription) {
            connect(subscription, &QMqttSubscription::messageReceived, 
                    this, &MqttClient::onMessageReceived);
            emitLogMessage(QString("Subscribed to topic: %1").arg(topic));
        } else {
            emitLogMessage(QString("Failed to subscribe to topic: %1").arg(topic));
        }
    } else {
        emitLogMessage("Cannot subscribe: client not connected");
    }
}

void MqttClient::unsubscribe(const QString &topic)
{
    if (m_client->state() == QMqttClient::Connected) {
        m_client->unsubscribe(topic);
        emitLogMessage(QString("Unsubscribed from topic: %1").arg(topic));
    } else {
        emitLogMessage("Cannot unsubscribe: client not connected");
    }
}

void MqttClient::publish(const QString &topic, const QString &message, int qos, bool retain)
{
    if (m_client->state() == QMqttClient::Connected) {
        QByteArray data = message.toUtf8();
        auto result = m_client->publish(topic, data, static_cast<quint8>(qos), retain);
        if (result != -1) {
            emitLogMessage(QString("Published message to topic: %1").arg(topic));
        } else {
            emitLogMessage(QString("Failed to publish message to topic: %1").arg(topic));
        }
    } else {
        emitLogMessage("Cannot publish: client not connected");
    }
}

void MqttClient::onConnected()
{
    emitLogMessage("✓ Connected to MQTT broker");
    m_reconnectTimer->stop();
    emit connected();
    emit connectedChanged();
}

void MqttClient::onDisconnected()
{
    emitLogMessage("✗ Disconnected from MQTT broker");
    emit disconnected();
    emit connectedChanged();
    
    if (m_autoReconnect) {
        m_reconnectTimer->start(m_reconnectInterval);
    }
}

void MqttClient::onStateChanged(QMqttClient::ClientState state)
{
    Q_UNUSED(state);

    emitLogMessage(QString("State changed: %1").arg(connectionStateString()));
    emit stateChanged();
    emit connectedChanged();
}

void MqttClient::onErrorChanged(QMqttClient::ClientError error)
{
    QString errorString;
    switch (error) {
    case QMqttClient::NoError:
        return; // No error, don't emit signal
    case QMqttClient::InvalidProtocolVersion:
        errorString = "Invalid protocol version";
        break;
    case QMqttClient::IdRejected:
        errorString = "Client ID rejected";
        break;
    case QMqttClient::ServerUnavailable:
        errorString = "Server unavailable";
        break;
    case QMqttClient::BadUsernameOrPassword:
        errorString = "Bad username or password";
        break;
    case QMqttClient::NotAuthorized:
        errorString = "Not authorized";
        break;
    case QMqttClient::TransportInvalid:
        errorString = "Transport invalid";
        break;
    case QMqttClient::ProtocolViolation:
        errorString = "Protocol violation";
        break;
    case QMqttClient::UnknownError:
    default:
        errorString = "Unknown error";
        break;
    }
    
    emitLogMessage(QString("X Error: %1").arg(errorString));
    emit errorOccurred(errorString);
}

void MqttClient::onMessageReceived(QMqttMessage message)
{
    QString messageText = QString::fromUtf8(message.payload());
    emitLogMessage(QString("📨 Message received on [%1]: %2").arg(message.topic().name(), messageText));
    emit messageReceived(message.topic().name(), messageText);
}

void MqttClient::onPingResponseReceived()
{
    emitLogMessage("Ping response received");
}

void MqttClient::setupSslConfiguration()
{
    m_sslConfig = QSslConfiguration::defaultConfiguration();
    m_sslConfig.setProtocol(QSsl::TlsV1_2OrLater);
    m_sslConfig.setPeerVerifyMode(QSslSocket::VerifyPeer);

    // Debug SSL information
    if (!QSslSocket::supportsSsl()) {
        emitLogMessage("❌ SSL not supported on this system");
        emitLogMessage(QString("SSL build version: %1").arg(QSslSocket::sslLibraryBuildVersionString()));
        emitLogMessage(QString("SSL runtime version: %1").arg(QSslSocket::sslLibraryVersionString()));
        return;
    }

    // Get and filter supported ciphers
    QList<QSslCipher> allCiphers = QSslConfiguration::supportedCiphers();
    QList<QSslCipher> secureCiphers;

    // Filter for strong ciphers only
    for (const QSslCipher &cipher : std::as_const(allCiphers)) {
        if (cipher.usedBits() >= 128 &&
            (cipher.protocol() == QSsl::TlsV1_2 || cipher.protocol() == QSsl::TlsV1_3)) {
            secureCiphers.append(cipher);
        }
    }

    emitLogMessage(QString("SSL Info: Using %1 secure ciphers out of %2 total")
                       .arg(secureCiphers.size()).arg(allCiphers.size()));

    m_sslConfig.setCiphers(secureCiphers.isEmpty() ? allCiphers : secureCiphers);
}

void MqttClient::setupConnectionProperties()
{
    m_client->setKeepAlive(60);
    m_client->setCleanSession(true);
    m_client->setProtocolVersion(QMqttClient::MQTT_5_0);
}

void MqttClient::loadCertificates()
{
    // Load CA certificate
    if (!m_caCertPath.isEmpty()) {
        QFile certFile(m_caCertPath);
        if (certFile.open(QIODevice::ReadOnly)) {
            QList<QSslCertificate> caCerts = QSslCertificate::fromDevice(&certFile);
            if (!caCerts.isEmpty()) {
                m_sslConfig.setCaCertificates(caCerts);
                emitLogMessage("CA certificate loaded successfully");
            } else {
                emitLogMessage(QString("Failed to load CA certificate from: %1").arg(m_caCertPath));
            }
            certFile.close();
        } else {
            emitLogMessage(QString("Could not open CA certificate file: %1").arg(m_caCertPath));
        }
    }
    
    // Load client certificate and key
    if (!m_clientCertPath.isEmpty() && !m_clientKeyPath.isEmpty()) {
        // Load client certificate
        QFile certFile(m_clientCertPath);
        if (certFile.open(QIODevice::ReadOnly)) {
            QSslCertificate cert(&certFile);
            if (!cert.isNull()) {
                m_sslConfig.setLocalCertificate(cert);
                emitLogMessage("Client certificate loaded successfully");
            } else {
                emitLogMessage(QString("Failed to load client certificate from: %1").arg(m_clientCertPath));
            }
            certFile.close();
        } else {
            emitLogMessage(QString("Could not open client certificate file: %1").arg(m_clientCertPath));
        }
        
        // Load private key
        QFile keyFile(m_clientKeyPath);
        if (keyFile.open(QIODevice::ReadOnly)) {
            QSslKey key(&keyFile, QSsl::Rsa);
            if (key.isNull()) {
                keyFile.seek(0);
                key = QSslKey(&keyFile, QSsl::Ec);
            }
            if (key.isNull()) {
                keyFile.seek(0);
                key = QSslKey(&keyFile, QSsl::Dsa);
            }
            
            if (!key.isNull()) {
                m_sslConfig.setPrivateKey(key);
                emitLogMessage("Private key loaded successfully");
            } else {
                emitLogMessage(QString("Failed to load private key from: %1").arg(m_clientKeyPath));
            }
            keyFile.close();
        } else {
            emitLogMessage(QString("Could not open private key file: %1").arg(m_clientKeyPath));
        }
    }
}

void MqttClient::emitLogMessage(const QString &message)
{
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    emit logMessage(QString("[%1] %2").arg(timestamp, message));
}
