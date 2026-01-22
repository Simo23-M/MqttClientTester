#include "mqttclient.h"
#include <QFile>
#include <QSslSocket>
#include <QUuid>
#include <QDateTime>
#include <QSslCipher>
#include <QRegularExpression>

MqttClient::MqttClient(QObject *parent)
    : QObject(parent)
    , m_client(new QMqttClient(this))
    , m_reconnectTimer(new QTimer(this))
    , m_hostName("localhost")
    , m_port(1883)
    , m_autoReconnect(true)
    , m_reconnectInterval(5000)
    , m_messagesReceived(0)
    , m_messagesPublished(0)
    , m_username("")
    , m_password("")
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
        // Clear all subscriptions
        for (auto it = m_activeSubscriptions.begin(); it != m_activeSubscriptions.end(); ++it) {
            if (it.value()) {
                it.value()->unsubscribe();
            }
        }
        m_activeSubscriptions.clear();
        m_subscriptionQos.clear();
        emit activeSubscriptionsChanged();
        
        m_client->disconnectFromHost();
        emitLogMessage("Disconnecting from broker");
    }
}

void MqttClient::subscribe(const QString &topic, int qos)
{
    if (m_client->state() == QMqttClient::Connected) {
        // Validate topic filter
        if (!isValidTopicFilter(topic)) {
            emitLogMessage(QString("? Invalid topic filter: %1").arg(topic));
            return;
        }
        
        // Check if already subscribed
        if (m_activeSubscriptions.contains(topic)) {
            emitLogMessage(QString("?? Already subscribed to: %1").arg(topic));
            return;
        }
        
        auto subscription = m_client->subscribe(topic, static_cast<quint8>(qos));
        if (subscription) {
            connect(subscription, &QMqttSubscription::messageReceived, 
                    this, &MqttClient::onMessageReceived);
            connect(subscription, &QMqttSubscription::stateChanged,
                    this, &MqttClient::onSubscriptionStateChanged);
            
            addActiveSubscription(topic, qos);
            
            QString typeInfo = isWildcardTopic(topic) ? 
                QString(" (Wildcard - Traffic Level: %1)").arg(estimateTrafficLevel(topic)) : "";
            
            emitLogMessage(QString("?? Subscribed to topic: %1%2").arg(topic, typeInfo));
            emit subscriptionAdded(topic, qos);
        } else {
            emitLogMessage(QString("? Failed to subscribe to topic: %1").arg(topic));
        }
    } else {
        emitLogMessage("? Cannot subscribe: client not connected");
    }
}

void MqttClient::unsubscribe(const QString &topic)
{
    if (m_client->state() == QMqttClient::Connected) {
        if (m_activeSubscriptions.contains(topic)) {
            auto subscription = m_activeSubscriptions.value(topic);
            if (subscription) {
                subscription->unsubscribe();
            }
            removeActiveSubscription(topic);
            m_client->unsubscribe(topic);
            emitLogMessage(QString("??? Unsubscribed from topic: %1").arg(topic));
            emit subscriptionRemoved(topic);
        } else {
            emitLogMessage("Cannot unsubscribe: client not connected");
        }
    }
}


void MqttClient::unsubscribeAll()
{
    if (m_client->state() == QMqttClient::Connected) {
        QStringList topics = m_activeSubscriptions.keys();
        for (const QString &topic : topics) {
            unsubscribe(topic);
        }
        emitLogMessage(QString("??? Unsubscribed from all %1 topics").arg(topics.size()));
    } else {
        emitLogMessage("? Cannot unsubscribe: client not connected");
    }
}

void MqttClient::publish(const QString &topic, const QString &message, int qos, bool retain)
{
    if (m_client->state() == QMqttClient::Connected) {
        // Validate topic (publishing topics cannot contain wildcards)
        if (topic.contains('+') || topic.contains('#')) {
            emitLogMessage(QString("? Cannot publish to wildcard topic: %1").arg(topic));
            return;
        }
        
        QByteArray data = message.toUtf8();
        auto result = m_client->publish(topic, data, static_cast<quint8>(qos), retain);
        if (result != -1) {
            m_messagesPublished++;
            QString retainInfo = retain ? " [RETAINED]" : "";
            emitLogMessage(QString("?? Published message to topic: %1%2").arg(topic, retainInfo));
        } else {
            emitLogMessage(QString("? Failed to publish message to topic: %1").arg(topic));
        }
    } else {
        emitLogMessage("? Cannot publish: client not connected");
    }
}

QStringList MqttClient::getActiveSubscriptions() const
{
    return m_activeSubscriptions.keys();
}

bool MqttClient::isSubscribedTo(const QString &topic) const
{
    return m_activeSubscriptions.contains(topic);
}

bool MqttClient::isValidTopicFilter(const QString &topic) const
{
    if (topic.isEmpty()) {
        return false;
    }
    
    // Check for invalid characters
    if (topic.contains('\0')) {
        return false;
    }
    
    // Check wildcard rules
    QStringList levels = topic.split('/');
    for (int i = 0; i < levels.size(); ++i) {
        const QString &level = levels[i];
        
        // Single level wildcard rules
        if (level.contains('+')) {
            if (level != "+") {
                return false; // + must be alone in the level
            }
        }
        
        // Multi level wildcard rules  
        if (level.contains('#')) {
            if (level != "#") {
                return false; // # must be alone in the level
            }
            if (i != levels.size() - 1) {
                return false; // # must be the last level
            }
        }
    }
    
    return true;
}

bool MqttClient::isWildcardTopic(const QString &topic) const
{
    return topic.contains('+') || topic.contains('#');
}

QString MqttClient::getTopicPattern(const QString &topic) const
{
    if (topic.contains('#')) {
        return "Multi-level wildcard";
    } else if (topic.contains('+')) {
        return "Single-level wildcard";
    } else {
        return "Exact topic";
    }
}

int MqttClient::estimateTrafficLevel(const QString &topic) const
{
    // Simple heuristic to estimate potential traffic level
    // 1 = Low, 2 = Medium, 3 = High, 4 = Very High, 5 = Extreme
    
    if (topic == "#") {
        return 5; // All topics - extreme traffic
    }
    
    if (topic.startsWith("$SYS/#")) {
        return 3; // System messages - high traffic
    }
    
    int wildcardCount = topic.count('+') + topic.count('#');
    int levelCount = topic.split('/').size();
    
    if (wildcardCount == 0) {
        return 1; // Exact topic - low traffic
    }
    
    if (topic.contains('#')) {
        if (levelCount <= 2) {
            return 4; // Short multi-level wildcard - very high traffic
        } else {
            return 3; // Longer multi-level wildcard - high traffic
        }
    }
    
    if (wildcardCount >= 3) {
        return 4; // Multiple single-level wildcards - very high traffic
    }
    
    return 2; // Single or few wildcards - medium traffic
}

void MqttClient::onConnected()
{
    emitLogMessage("? Connected to MQTT broker");
    emitLogMessage(QString("?? Statistics: %1 messages received, %2 published")
                   .arg(m_messagesReceived).arg(m_messagesPublished));
    m_reconnectTimer->stop();
    emit connected();
    emit connectedChanged();
}

void MqttClient::onDisconnected()
{
    emitLogMessage("? Disconnected from MQTT broker");
    
    // Clear subscriptions but keep the list for potential reconnection
    for (auto it = m_activeSubscriptions.begin(); it != m_activeSubscriptions.end(); ++it) {
        if (it.value()) {
            // Subscription object will be invalid after disconnect
            it.value() = nullptr;
        }
    }
    
    emit disconnected();
    emit connectedChanged();
    
    if (m_autoReconnect) {
        m_reconnectTimer->start(m_reconnectInterval);
    }
}

void MqttClient::onStateChanged(QMqttClient::ClientState state)
{
    Q_UNUSED(state);
    emitLogMessage(QString("?? State changed: %1").arg(connectionStateString()));
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
    
    emitLogMessage(QString("? Error: %1").arg(errorString));
    emit errorOccurred(errorString);
}

void MqttClient::onMessageReceived(QMqttMessage message)
{
    m_messagesReceived++;
    QString messageText = QString::fromUtf8(message.payload());
    
    // Enhanced logging with message info
    QString retainInfo = message.retain() ? " [RETAINED]" : "";
    QString qosInfo = QString(" [QoS %1]").arg(message.qos());
    
    emitLogMessage(QString("?? Message received on [%1]%2%3: %4")
                   .arg(message.topic().name(), qosInfo, retainInfo, 
                        messageText.left(100))); // Limit preview to 100 chars
    
    emit messageReceived(message.topic().name(), messageText);
}

void MqttClient::onPingResponseReceived()
{
    emitLogMessage("?? Ping response received");
}

void MqttClient::onSubscriptionStateChanged(QMqttSubscription::SubscriptionState state)
{
    QMqttSubscription *subscription = qobject_cast<QMqttSubscription*>(sender());
    if (!subscription) {
        return;
    }
    
    QString topic = subscription->topic().filter();
    
    switch (state) {
    case QMqttSubscription::Unsubscribed:
        emitLogMessage(QString("??? Subscription state: %1 - Unsubscribed").arg(topic));
        removeActiveSubscription(topic);
        break;
    case QMqttSubscription::SubscriptionPending:
        emitLogMessage(QString("??? Subscription state: %1 - Pending").arg(topic));
        break;
    case QMqttSubscription::Subscribed:
        emitLogMessage(QString("??? Subscription state: %1 - Active").arg(topic));
        break;
    case QMqttSubscription::Error:
        emitLogMessage(QString("??? Subscription state: %1 - Error").arg(topic));
        removeActiveSubscription(topic);
        break;
    }
}

void MqttClient::setupSslConfiguration()
{
    m_sslConfig = QSslConfiguration::defaultConfiguration();
    m_sslConfig.setProtocol(QSsl::TlsV1_2OrLater);
    m_sslConfig.setPeerVerifyMode(QSslSocket::VerifyPeer);

    // Debug SSL information
    if (!QSslSocket::supportsSsl()) {
        emitLogMessage("? SSL not supported on this system");
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

    emitLogMessage(QString("?? SSL Info: Using %1 secure ciphers out of %2 total")
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
                emitLogMessage("?? CA certificate loaded successfully");
            } else {
                emitLogMessage(QString("? Failed to load CA certificate from: %1").arg(m_caCertPath));
            }
            certFile.close();
        } else {
            emitLogMessage(QString("? Could not open CA certificate file: %1").arg(m_caCertPath));
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
                emitLogMessage("?? Client certificate loaded successfully");
            } else {
                emitLogMessage(QString("? Failed to load client certificate from: %1").arg(m_clientCertPath));
            }
            certFile.close();
        } else {
            emitLogMessage(QString("? Could not open client certificate file: %1").arg(m_clientCertPath));
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
                emitLogMessage("?? Private key loaded successfully");
            } else {
                emitLogMessage(QString("? Failed to load private key from: %1").arg(m_clientKeyPath));
            }
            keyFile.close();
        } else {
            emitLogMessage(QString("? Could not open private key file: %1").arg(m_clientKeyPath));
        }
    }
}

void MqttClient::emitLogMessage(const QString &message)
{
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    emit logMessage(QString("[%1] %2").arg(timestamp, message));
}

void MqttClient::addActiveSubscription(const QString &topic, int qos)
{
    if (!m_activeSubscriptions.contains(topic)) {
        m_subscriptionQos[topic] = qos;
        // The actual QMqttSubscription object will be set when subscription succeeds
        m_activeSubscriptions[topic] = nullptr;
        emit activeSubscriptionsChanged();
    }
}

void MqttClient::removeActiveSubscription(const QString &topic)
{
    if (m_activeSubscriptions.contains(topic)) {
        m_activeSubscriptions.remove(topic);
        m_subscriptionQos.remove(topic);
        emit activeSubscriptionsChanged();
    }
}
