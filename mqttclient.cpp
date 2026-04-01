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
    
    // Setup message batch timer (flush every 100ms)
    m_batchTimer = new QTimer(this);
    m_batchTimer->setSingleShot(true);
    m_batchTimer->setInterval(100);
    connect(m_batchTimer, &QTimer::timeout, this, &MqttClient::flushMessageBuffer);

    // Setup reconnection timer
    m_reconnectTimer->setSingleShot(true);
    connect(m_reconnectTimer, &QTimer::timeout, [this]() {
        if (m_autoReconnect && m_client->state() == QMqttClient::Disconnected) {
            emitStructuredLog("Attempting to reconnect to MQTT broker...", "connection", "info");
            m_client->setCleanSession(true);
            m_client->connectToHost();
        }
    });
    
    // Setup SSL configuration
    setupSslConfiguration();
    setupConnectionProperties();
    
    emitStructuredLog("MQTT Client initialized", "system", "info");
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
    
    emitStructuredLog(QString("Connecting to MQTT broker: %1:%2").arg(m_hostName).arg(m_port), "connection", "info");
    
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
    m_batchTimer->stop();
    flushMessageBuffer();
    
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
        emitStructuredLog("Disconnecting from broker", "connection", "info");
    }
}

void MqttClient::subscribe(const QString &topic, int qos)
{
    if (m_client->state() == QMqttClient::Connected) {
        // Validate topic filter
        if (!isValidTopicFilter(topic)) {
            emitStructuredLog(QString("Invalid topic filter: %1").arg(topic), "subscription", "error", topic);
            return;
        }

        // Check if already subscribed
        if (m_activeSubscriptions.contains(topic)) {
            emitStructuredLog(QString("Already subscribed to: %1").arg(topic), "subscription", "warning", topic);
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
            
            emitStructuredLog(QString("Subscribed to topic: %1%2").arg(topic, typeInfo), "subscription", "info", topic, QString(), "in", qos);
            emit subscriptionAdded(topic, qos);
        } else {
            emitStructuredLog(QString("Failed to subscribe to topic: %1").arg(topic), "subscription", "error", topic);
        }
    } else {
        emitStructuredLog("Cannot subscribe: client not connected", "subscription", "error");
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
            emitStructuredLog(QString("Unsubscribed from topic: %1").arg(topic), "subscription", "info", topic);
            emit subscriptionRemoved(topic);
        } else {
            emitStructuredLog("Cannot unsubscribe: client not connected", "subscription", "error");
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
        emitStructuredLog(QString("Unsubscribed from all %1 topics").arg(topics.size()), "subscription", "info");
    } else {
        emitStructuredLog("Cannot unsubscribe: client not connected", "subscription", "error");
    }
}

void MqttClient::publish(const QString &topic, const QString &message, int qos, bool retain)
{
    if (m_client->state() == QMqttClient::Connected) {
        // Validate topic (publishing topics cannot contain wildcards)
        if (topic.contains('+') || topic.contains('#')) {
            emitStructuredLog(QString("Cannot publish to wildcard topic: %1").arg(topic), "publish", "error", topic);
            return;
        }
        
        QByteArray data = message.toUtf8();
        auto result = m_client->publish(topic, data, static_cast<quint8>(qos), retain);
        if (result != -1) {
            m_messagesPublished++;
            QString retainInfo = retain ? " [RETAINED]" : "";
            emitStructuredLog(QString("Published message to topic: %1%2").arg(topic, retainInfo), "publish", "info", topic, message, "out", qos);
        } else {
            emitStructuredLog(QString("Failed to publish message to topic: %1").arg(topic), "publish", "error", topic);
        }
    } else {
        emitStructuredLog("Cannot publish: client not connected", "publish", "error");
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
    emitStructuredLog("Connected to MQTT broker", "connection", "info");
    emitStructuredLog(QString("Statistics: %1 messages received, %2 published")
                   .arg(m_messagesReceived).arg(m_messagesPublished), "system", "debug");
    m_reconnectTimer->stop();
    emit connected();
    emit connectedChanged();
}

void MqttClient::onDisconnected()
{
    emitStructuredLog("Disconnected from MQTT broker", "connection", "warning");
    
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
    emitStructuredLog(QString("State changed: %1").arg(connectionStateString()), "connection", "info");
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
    
    emitStructuredLog(QString("Error: %1").arg(errorString), "error", "error");
    emit errorOccurred(errorString);
}

void MqttClient::onMessageReceived(QMqttMessage message)
{
    m_messagesReceived++;
    QString topic = message.topic().name();
    QString messageText = QString::fromUtf8(message.payload());

    // Buffer the message for batch processing
    m_messageBuffer.append(qMakePair(topic, messageText));

    // Start the batch timer if not already running
    if (!m_batchTimer->isActive()) {
        m_batchTimer->start();
    }
}

void MqttClient::flushMessageBuffer()
{
    if (m_messageBuffer.isEmpty())
        return;

    QVariantList batch;
    batch.reserve(m_messageBuffer.size());
    for (const auto &pair : std::as_const(m_messageBuffer)) {
        QVariantMap entry;
        entry[QStringLiteral("topic")] = pair.first;
        entry[QStringLiteral("message")] = pair.second;
        batch.append(entry);
    }

    int count = m_messageBuffer.size();
    m_messageBuffer.clear();

    for (const QVariant &v : std::as_const(batch)) {
        const QVariantMap &m = v.toMap();
        emitStructuredLog(QString("Message received on: %1").arg(m.value(QStringLiteral("topic")).toString()),
                          "receive", "info",
                          m.value(QStringLiteral("topic")).toString().simplified(),
                          m.value(QStringLiteral("message")).toString().simplified(),
                          "in");
    }
    emitStructuredLog(QString("Batch received: %1 messages").arg(count), "receive", "debug", QString(), QString(), "in");
    emit messageBatchReceived(batch);
}

void MqttClient::onPingResponseReceived()
{
    emitStructuredLog("Ping response received", "connection", "debug");
}

void MqttClient::onSubscriptionStateChanged(QMqttSubscription::SubscriptionState state)
{
    QMqttSubscription *subscription = qobject_cast<QMqttSubscription*>(sender());
    if (!subscription) {
        return;
    }
    
    QString topic = subscription->topic().filter();
    
    switch (state) {
    case QMqttSubscription::UnsubscriptionPending:
        emitStructuredLog(QString("Subscription state: %1 - Pending").arg(topic), "subscription", "info", topic);
        break;
    case QMqttSubscription::Unsubscribed:
        emitStructuredLog(QString("Subscription state: %1 - Unsubscribed").arg(topic), "subscription", "info", topic);
        removeActiveSubscription(topic);
        break;
    case QMqttSubscription::SubscriptionPending:
        emitStructuredLog(QString("Subscription state: %1 - Pending").arg(topic), "subscription", "info", topic);
        break;
    case QMqttSubscription::Subscribed:
        emitStructuredLog(QString("Subscription state: %1 - Active").arg(topic), "subscription", "info", topic);
        break;
    case QMqttSubscription::Error:
        emitStructuredLog(QString("Subscription state: %1 - Error").arg(topic), "subscription", "error", topic);
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
        emitStructuredLog("SSL not supported on this system", "tls", "error");
        emitStructuredLog(QString("SSL build version: %1").arg(QSslSocket::sslLibraryBuildVersionString()), "tls", "debug");
        emitStructuredLog(QString("SSL runtime version: %1").arg(QSslSocket::sslLibraryVersionString()), "tls", "debug");
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

    emitStructuredLog(QString("SSL Info: Using %1 secure ciphers out of %2 total")
                       .arg(secureCiphers.size()).arg(allCiphers.size()), "tls", "info");

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
                emitStructuredLog("CA certificate loaded successfully", "tls", "info");
            } else {
                emitStructuredLog(QString("Failed to load CA certificate from: %1").arg(m_caCertPath), "tls", "error");
            }
            certFile.close();
        } else {
            emitStructuredLog(QString("Could not open CA certificate file: %1").arg(m_caCertPath), "tls", "error");
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
                emitStructuredLog("Client certificate loaded successfully", "tls", "info");
            } else {
                emitStructuredLog(QString("Failed to load client certificate from: %1").arg(m_clientCertPath), "tls", "error");
            }
            certFile.close();
        } else {
            emitStructuredLog(QString("Could not open client certificate file: %1").arg(m_clientCertPath), "tls", "error");
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
                emitStructuredLog("Private key loaded successfully", "tls", "info");
            } else {
                emitStructuredLog(QString("Failed to load private key from: %1").arg(m_clientKeyPath), "tls", "error");
            }
            keyFile.close();
        } else {
            emitStructuredLog(QString("Could not open private key file: %1").arg(m_clientKeyPath), "tls", "error");
        }
    }
}

void MqttClient::emitLogMessage(const QString &message)
{
    emitStructuredLog(message, "system", "info");
}

void MqttClient::emitStructuredLog(const QString &message, const QString &category,
                                     const QString &level, const QString &topic,
                                     const QString &payload, const QString &direction,
                                     int qos)
{
    QVariantMap entry;
    entry[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss.zzz"));
    entry[QStringLiteral("category")] = category;
    entry[QStringLiteral("level")] = level;
    entry[QStringLiteral("message")] = message;
    entry[QStringLiteral("topic")] = topic;
    entry[QStringLiteral("payload")] = payload.left(200);
    entry[QStringLiteral("direction")] = direction;
    entry[QStringLiteral("qos")] = qos;
    emit logMessage(entry);
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
