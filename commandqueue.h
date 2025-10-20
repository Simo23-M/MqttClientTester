#ifndef COMMANDQUEUE_H
#define COMMANDQUEUE_H

#include <QObject>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>
#include <QQueue>
#include <QQmlEngine>


struct MqttCommand {
    QString name;
    QString topic;
    QString payload;
    int qos;
    bool retain;
    int delay; // milliseconds
    QString condition;
};
Q_DECLARE_METATYPE(MqttCommand)


class CommandQueue : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(int queueSize READ queueSize NOTIFY queueSizeChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString loadedPresetFile READ loadedPresetFile NOTIFY loadedPresetFileChanged)


public:
    explicit CommandQueue(QObject *parent = nullptr);

    bool isRunning() const { return m_isRunning; }
    int queueSize() const { return m_queueSize; }
    int currentIndex() const { return m_currentIndex; }
    QString loadedPresetFile() const { return m_loadedPresetFile; }

public slots:
    // Preset management
    bool loadPresetsFromFile(const QString &filePath);
    bool savePresetsToFile(const QString &filePath);
    Q_INVOKABLE QString getPresetsJson() const;

    // Queue management
    void addCommandToQueue(const QString &name, const QString &topic,
                           const QString &payload, int qos, bool retain, int delay);
    void removeCommandFromQueue(int index);
    void clearQueue();
    void moveCommandUp(int index);
    void moveCommandDown(int index);

    // Execution control
    void startQueue();
    void stopQueue();
    void pauseQueue();
    void resumeQueue();
    void executeNext();
    void executeCommand(int index);

    // Preset operations
    Q_INVOKABLE QStringList getPresetNames() const;
    Q_INVOKABLE QString getPresetData(const QString &name) const;
    void addPresetToQueue(const QString &presetName);
    void clearPresets();

    // Queue inspection
    Q_INVOKABLE QVariantList getQueueItems() const;

signals:
    void isRunningChanged();
    void queueSizeChanged();
    void currentIndexChanged();
    void loadedPresetFileChanged();
    void commandExecuted(const QString &name, const QString &topic, const QString &payload);
    void queueFinished();
    void errorOccurred(const QString &error);
    void logMessage(const QString &message);
    void publishRequested(const QString &topic, const QString &payload, int qos, bool retain);


private:
    bool m_isRunning;
    int m_queueSize;
    int m_currentIndex;
    QString m_loadedPresetFile;

    bool m_isPaused;

private slots:
    void onTimerTimeout();

private:
    void executeCurrentCommand();
    void scheduleNextCommand();
    void emitLog(const QString &message);
    bool validateCommand(const MqttCommand &cmd);

    QTimer *m_timer;
    QQueue<MqttCommand> m_commandQueue;
    QJsonObject m_presets;
};

#endif // COMMANDQUEUE_H
