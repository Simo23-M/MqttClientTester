#ifndef COMMANDQUEUE_H
#define COMMANDQUEUE_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QList>
#include <QQmlEngine>
#include <QVariantMap>
#include <QProcess>
#include <QUuid>

enum class CommandType { Publish = 0, Script = 1 };

struct MqttCommand {
    QString name;
    QString topic;
    QString payload;
    int qos;
    bool retain;
    int delay; // milliseconds
    QString condition;
    QString description;
    CommandType commandType = CommandType::Publish;
    QString scriptPath;
    QString scriptArgs;
};
Q_DECLARE_METATYPE(MqttCommand)

struct ScriptTrigger {
    QString id;
    QString name;
    QString topicPattern;   // MQTT wildcard pattern (+ and #)
    QString eventType;      // "received" | "published"
    QString scriptPath;
    QString scriptArgs;
    bool enabled = true;
};

class CommandQueue : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(int queueSize READ queueSize NOTIFY queueSizeChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString loadedPresetFile READ loadedPresetFile NOTIFY loadedPresetFileChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int triggerCount READ triggerCount NOTIFY triggersChanged)


public:
    explicit CommandQueue(QObject *parent = nullptr);

    bool isRunning() const { return m_isRunning; }
    int queueSize() const { return m_commandList.size(); }
    int currentIndex() const { return m_currentIndex; }
    QString loadedPresetFile() const { return m_loadedPresetFile; }
    QString lastError() const { return m_lastError; }
    int triggerCount() const { return m_triggers.size(); }

public slots:
    // Preset management
    Q_INVOKABLE bool loadPresetsFromFile(const QString &filePath);
    Q_INVOKABLE bool savePresetsToFile(const QString &filePath);
    Q_INVOKABLE QString getPresetsJson() const;

    // Queue management - O(1) operations with QList
    Q_INVOKABLE void addCommandToQueue(const QString &name, const QString &topic,
                           const QString &payload, int qos, bool retain, int delay);
    Q_INVOKABLE void removeCommandFromQueue(int index);
    Q_INVOKABLE void clearQueue();
    Q_INVOKABLE void moveCommandUp(int index);
    Q_INVOKABLE void moveCommandDown(int index);

    // Execution control
    Q_INVOKABLE void startQueue();
    Q_INVOKABLE void stopQueue();
    Q_INVOKABLE void pauseQueue();
    Q_INVOKABLE void resumeQueue();
    Q_INVOKABLE void executeNext();
    Q_INVOKABLE void executeCommand(int index);

    // Preset operations
    Q_INVOKABLE QStringList getPresetNames() const;
    Q_INVOKABLE QString getPresetData(const QString &name) const;
    Q_INVOKABLE void addPresetToQueue(const QString &presetName);
    Q_INVOKABLE void clearPresets();

    // Script execution (immediate / queue)
    Q_INVOKABLE void addScriptToQueue(const QString &name, const QString &scriptPath,
                                      const QString &scriptArgs, int delay);
    Q_INVOKABLE void executeScriptNow(const QString &scriptPath, const QString &scriptArgs);

    // Script triggers
    Q_INVOKABLE QString addTrigger(const QString &name, const QString &topicPattern,
                                   const QString &eventType, const QString &scriptPath,
                                   const QString &scriptArgs);
    Q_INVOKABLE void removeTrigger(const QString &id);
    Q_INVOKABLE void setTriggerEnabled(const QString &id, bool enabled);
    Q_INVOKABLE QVariantList getTriggers() const;
    Q_INVOKABLE void checkTriggers(const QString &topic, const QString &payload,
                                   const QString &eventType);
    Q_INVOKABLE bool loadTriggersFromFile(const QString &filePath);
    Q_INVOKABLE bool saveTriggersToFile(const QString &filePath) const;

    // Queue inspection - O(1) access
    Q_INVOKABLE QVariantList getQueueItems() const;
    Q_INVOKABLE QVariantMap getCommandAtIndex(int index) const;

signals:
    void isRunningChanged();
    void queueSizeChanged();
    void currentIndexChanged();
    void loadedPresetFileChanged();
    void lastErrorChanged();
    void commandExecuted(const QString &name, const QString &topic, const QString &payload);
    void queueFinished();
    void errorOccurred(const QString &error);
    void logMessage(const QVariantMap &entry);
    void publishRequested(const QString &topic, const QString &payload, int qos, bool retain);
    void scriptOutputReceived(const QString &name, const QString &output, int exitCode);
    void triggersChanged();
    void triggerFired(const QString &name, const QString &topic, const QString &payload);


private:
    // Member variables - ordered to match initialization order in constructor
    QTimer *m_timer;
    bool m_isRunning;
    bool m_isPaused;
    int m_currentIndex;
    int m_presetVersion; // Track preset format version
    QString m_loadedPresetFile;
    QString m_lastError;
    QList<MqttCommand> m_commandList;  // Changed from QQueue for O(1) indexed access
    QJsonObject m_presets;
    QProcess *m_currentProcess = nullptr;
    QList<ScriptTrigger> m_triggers;

private slots:
    void onTimerTimeout();

private:
    void executeCurrentCommand();
    void scheduleNextCommand();
    void executeScriptCommand(const MqttCommand &cmd);
    void startProcess(const QString &name, const QString &scriptPath,
                      const QString &scriptArgs, bool continueQueue,
                      const QVariantMap &envVars = QVariantMap());
    static bool matchTopic(const QString &pattern, const QString &topic);
    void emitLog(const QString &message);
    void emitStructuredLog(const QString &message, const QString &level,
                           const QString &topic = QString(), const QString &payload = QString(),
                           const QString &direction = QString(), int qos = -1);
    void setLastError(const QString &error);
    bool validateCommand(const MqttCommand &cmd);

    // Preset format handling
    bool isV2PresetFormat(const QJsonObject &json) const;
    QJsonObject migrateV1ToV2(const QJsonObject &v1Json) const;
    bool createBackupFile(const QString &filePath) const;
};

#endif // COMMANDQUEUE_H
