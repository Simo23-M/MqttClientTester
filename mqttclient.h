#ifndef MQTTCLIENT_H
#define MQTTCLIENT_H

#include <QtMqtt/QMqttClient>
#include <QtMqtt/QMqttConnectionProperties>
#include <QtMqtt/QMqttSubscription>
#include <QObject>
#include <QSslConfiguration>
#include <QSslCertificate>
#include <QSslKey>
#include <QTimer>
#include <QDebug>
#include <QQmlEngine>
#include <QStringList>
#include <QHash>

class MqttClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString connectionState READ connectionStateString NOTIFY stateChanged)
    Q_PROPERTY(QString hostName READ hostName WRITE setHostName NOTIFY hostNameChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)
    Q_PROPERTY(QString clientId READ clientId WRITE setClientId NOTIFY clientIdChanged)
    Q_PROPERTY(QString username READ username WRITE setUsername NOTIFY usernameChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString caCertPath READ caCertPath WRITE setCaCertPath NOTIFY caCertPathChanged)
    Q_PROPERTY(QString clientCertPath READ clientCertPath WRITE setClientCertPath NOTIFY clientCertPathChanged)
    Q_PROPERTY(QString clientKeyPath READ clientKeyPath WRITE setClientKeyPath NOTIFY clientKeyPathChanged)
    Q_PROPERTY(int activeSubscriptionsCount READ activeSubscriptionsCount NOTIFY activeSubscriptionsChanged)

public:
    explicit MqttClient(QObject *parent = nullptr);
    ~MqttClient();

    // Property getters
    bool isConnected() const;
    QString connectionStateString() const;
    QString hostName() const { return m_hostName; }
    int port() const { return m_port; }
    QString clientId() const { return m_clientId; }
    QString username() const { return m_username; }
    QString password() const { return m_password; }
    QString caCertPath() const { return m_caCertPath; }
    QString clientCertPath() const { return m_clientCertPath; }
    QString clientKeyPath() const { return m_clientKeyPath; }
    int activeSubscriptionsCount() const { return m_activeSubscriptions.size(); }

    // Property setters
    void setHostName(const QString &hostName);
    void setPort(int port);
    void setClientId(const QString &clientId);
    void setUsername(const QString &username);
    void setPassword(const QString &password);
    void setCaCertPath(const QString &path);
    void setClientCertPath(const QString &path);
    void setClientKeyPath(const QString &path);

    QStringList getActiveSubscriptions() const;
    bool isSubscribedTo(const QString &topic) const;


public slots:
    void connectToHost();
    void disconnectFromHost();
    void subscribe(const QString &topic, int qos = 0);
    void unsubscribe(const QString &topic);
    void unsubscribeAll();
    void publish(const QString &topic, const QString &message, int qos = 0, bool retain = false);
    

    // Topic validation and helper functions
    Q_INVOKABLE bool isValidTopicFilter(const QString &topic) const;
    Q_INVOKABLE bool isWildcardTopic(const QString &topic) const;
    Q_INVOKABLE QString getTopicPattern(const QString &topic) const;
    Q_INVOKABLE int estimateTrafficLevel(const QString &topic) const;

signals:
    void connected();
    void disconnected();
    void connectedChanged();
    void stateChanged();
    void messageReceived(const QString &topic, const QString &message);
    void errorOccurred(const QString &error);
    void logMessage(const QString &message);
    void subscriptionAdded(const QString &topic, int qos);
    void subscriptionRemoved(const QString &topic);
    void activeSubscriptionsChanged();
    
    // Property change signals
    void hostNameChanged();
    void portChanged();
    void clientIdChanged();
    void usernameChanged();
    void passwordChanged();
    void caCertPathChanged();
    void clientCertPathChanged();
    void clientKeyPathChanged();

private slots:
    void onConnected();
    void onDisconnected();
    void onStateChanged(QMqttClient::ClientState state);
    void onErrorChanged(QMqttClient::ClientError error);
    void onMessageReceived(QMqttMessage message);
    void onPingResponseReceived();
    void onSubscriptionStateChanged(QMqttSubscription::SubscriptionState state);

private:
    void setupSslConfiguration();
    void setupConnectionProperties();
    void loadCertificates();
    void emitLogMessage(const QString &message);
    void addActiveSubscription(const QString &topic, int qos);
    void removeActiveSubscription(const QString &topic);
    
    QMqttClient *m_client;
    QSslConfiguration m_sslConfig;
    QTimer *m_reconnectTimer;
    
    // Connection parameters
    QString m_hostName;
    int m_port;
    QString m_clientId;
    QString m_username;
    QString m_password;
    
    // TLS certificate paths
    QString m_caCertPath;
    QString m_clientCertPath;
    QString m_clientKeyPath;
    
    // Subscription management
    QHash<QString, QMqttSubscription*> m_activeSubscriptions;
    QHash<QString, int> m_subscriptionQos;
    
    bool m_autoReconnect;
    int m_reconnectInterval;
    
    // Statistics
    quint64 m_messagesReceived;
    quint64 m_messagesPublished;
};

#endif // MQTTCLIENT_H
