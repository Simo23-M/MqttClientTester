#include "commandqueue.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>

CommandQueue::CommandQueue(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_isRunning(false)
    , m_isPaused(false)
    , m_currentIndex(-1)
{
    m_timer->setSingleShot(true);
    connect(m_timer, &QTimer::timeout, this, &CommandQueue::onTimerTimeout);

    emitLog("Command Queue initialized");
}

bool CommandQueue::loadPresetsFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emitLog(QString("❌ Failed to open preset file: %1").arg(filePath));
        emit errorOccurred("Cannot open preset file");
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        emitLog(QString("❌ JSON parse error: %1").arg(parseError.errorString()));
        emit errorOccurred("Invalid JSON format");
        return false;
    }

    if (!doc.isObject()) {
        emitLog("❌ JSON root must be an object");
        emit errorOccurred("Invalid JSON structure");
        return false;
    }

    m_presets = doc.object();
    m_loadedPresetFile = filePath;
    emit loadedPresetFileChanged();

    emitLog(QString("✅ Loaded %1 presets from: %2")
                .arg(m_presets.keys().size()).arg(filePath));

    return true;
}

bool CommandQueue::savePresetsToFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emitLog(QString("❌ Failed to create preset file: %1").arg(filePath));
        emit errorOccurred("Cannot create preset file");
        return false;
    }

    QJsonDocument doc(m_presets);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();

    m_loadedPresetFile = filePath;
    emit loadedPresetFileChanged();

    emitLog(QString("💾 Saved %1 presets to: %2")
                .arg(m_presets.keys().size()).arg(filePath));

    return true;
}

QString CommandQueue::getPresetsJson() const
{
    QJsonDocument doc(m_presets);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

void CommandQueue::addCommandToQueue(const QString &name, const QString &topic,
                                     const QString &payload, int qos, bool retain, int delay)
{
    MqttCommand cmd;
    cmd.name = name;
    cmd.topic = topic;
    cmd.payload = payload;
    cmd.qos = qos;
    cmd.retain = retain;
    cmd.delay = delay;

    if (!validateCommand(cmd)) {
        emitLog(QString("❌ Invalid command: %1").arg(name));
        return;
    }

    m_commandQueue.enqueue(cmd);
    emit queueSizeChanged();

    emitLog(QString("➕ Added to queue: %1 [Topic: %2]").arg(name, topic));
}

void CommandQueue::removeCommandFromQueue(int index)
{
    if (index < 0 || index >= m_commandQueue.size()) {
        emitLog("❌ Invalid queue index");
        return;
    }

    // Convert QQueue to QList for indexed access
    // Convert to vector for better performance with Qt 6
    // todo: check this part if I can do better than these loops, for now it works :)
    QList<MqttCommand> list;
    while (!m_commandQueue.isEmpty()) {
        list.append(m_commandQueue.dequeue());
    }

    QString name = list[index].name;
    list.removeAt(index);

    // Rebuild queue
    for (const auto &cmd : list) {
        m_commandQueue.enqueue(cmd);
    }

    emit queueSizeChanged();
    emitLog(QString("➖ Removed from queue: %1").arg(name));
}

void CommandQueue::clearQueue()
{
    int count = m_commandQueue.size();
    m_commandQueue.clear();
    m_currentIndex = -1;

    emit queueSizeChanged();
    emit currentIndexChanged();

    emitLog(QString("🗑️  Queue cleared (%1 commands removed)").arg(count));
}

void CommandQueue::moveCommandUp(int index)
{
    if (index <= 0 || index >= m_commandQueue.size()) {
        return;
    }

    QList<MqttCommand> list = m_commandQueue.toList();
    list.swapItemsAt(index - 1, index);

    m_commandQueue.clear();
    for (const auto &cmd : list) {
        m_commandQueue.enqueue(cmd);
    }

    emitLog(QString("⬆️  Moved command up: %1").arg(list[index - 1].name));
}

void CommandQueue::moveCommandDown(int index)
{
    if (index < 0 || index >= m_commandQueue.size() - 1) {
        return;
    }

    QList<MqttCommand> list = m_commandQueue.toList();
    list.swapItemsAt(index, index + 1);

    m_commandQueue.clear();
    for (const auto &cmd : list) {
        m_commandQueue.enqueue(cmd);
    }

    emitLog(QString("⬇️  Moved command down: %1").arg(list[index + 1].name));
}

void CommandQueue::startQueue()
{
    if (m_commandQueue.isEmpty()) {
        emitLog("❌ Cannot start: queue is empty");
        emit errorOccurred("Queue is empty");
        return;
    }

    if (m_isRunning) {
        emitLog("⚠️  Queue is already running");
        return;
    }

    m_isRunning = true;
    m_isPaused = false;
    m_currentIndex = 0;

    emit isRunningChanged();
    emit currentIndexChanged();

    emitLog(QString("▶️  Starting queue execution (%1 commands)").arg(m_commandQueue.size()));

    executeCurrentCommand();
}

void CommandQueue::stopQueue()
{
    if (!m_isRunning) {
        return;
    }

    m_timer->stop();
    m_isRunning = false;
    m_isPaused = false;
    m_currentIndex = -1;

    emit isRunningChanged();
    emit currentIndexChanged();

    emitLog("⏹️  Queue execution stopped");
}

void CommandQueue::pauseQueue()
{
    if (!m_isRunning || m_isPaused) {
        return;
    }

    m_timer->stop();
    m_isPaused = true;

    emitLog("⏸️  Queue execution paused");
}

void CommandQueue::resumeQueue()
{
    if (!m_isRunning || !m_isPaused) {
        return;
    }

    m_isPaused = false;
    emitLog("▶️  Queue execution resumed");

    scheduleNextCommand();
}

void CommandQueue::executeNext()
{
    if (m_commandQueue.isEmpty()) {
        return;
    }

    if (!m_isRunning) {
        m_isRunning = true;
        m_currentIndex = 0;
        emit isRunningChanged();
        emit currentIndexChanged();
    }

    executeCurrentCommand();
}

void CommandQueue::executeCommand(int index)
{
    if (index < 0 || index >= m_commandQueue.size()) {
        emitLog("❌ Invalid command index");
        return;
    }

    QList<MqttCommand> list = m_commandQueue.toList();
    const MqttCommand &cmd = list[index];

    emitLog(QString("🎯 Executing command: %1").arg(cmd.name));
    emit publishRequested(cmd.topic, cmd.payload, cmd.qos, cmd.retain);
    emit commandExecuted(cmd.name, cmd.topic, cmd.payload);
}

QStringList CommandQueue::getPresetNames() const
{
    return m_presets.keys();
}

QString CommandQueue::getPresetData(const QString &name) const
{
    if (!m_presets.contains(name)) {
        return QString();
    }

    QJsonDocument doc(m_presets.value(name).toObject());
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

void CommandQueue::addPresetToQueue(const QString &presetName)
{
    if (!m_presets.contains(presetName)) {
        emitLog(QString("❌ Preset not found: %1").arg(presetName));
        return;
    }

    QJsonObject preset = m_presets.value(presetName).toObject();

    MqttCommand cmd;
    cmd.name = presetName;
    cmd.topic = preset.value("topic").toString();
    cmd.payload = preset.value("payload").toString();
    cmd.qos = preset.value("qos").toInt(0);
    cmd.retain = preset.value("retain").toBool(false);
    cmd.delay = preset.value("delay").toInt(1000);
    cmd.condition = preset.value("condition").toString();

    if (!validateCommand(cmd)) {
        emitLog(QString("❌ Invalid preset configuration: %1").arg(presetName));
        return;
    }

    m_commandQueue.enqueue(cmd);
    emit queueSizeChanged();

    emitLog(QString("➕ Added preset to queue: %1").arg(presetName));
}

void CommandQueue::clearPresets()
{
    int count = m_presets.keys().size();
    m_presets = QJsonObject();
    m_loadedPresetFile.clear();

    emit loadedPresetFileChanged();

    emitLog(QString("🗑️  Cleared %1 presets").arg(count));
}

QVariantList CommandQueue::getQueueItems() const
{
    QVariantList items;
    QList<MqttCommand> tempList;

    // Create a temporary copy of the queue
    QQueue<MqttCommand> tempQueue = m_commandQueue;

    // Convert queue to list
    while (!tempQueue.isEmpty()) {
        tempList.append(tempQueue.dequeue());
    }

    // Convert to QVariantList for QML
    for (const MqttCommand &cmd : tempList) {
        QVariantMap item;
        item["name"] = cmd.name;
        item["topic"] = cmd.topic;
        item["payload"] = cmd.payload;
        item["qos"] = cmd.qos;
        item["retain"] = cmd.retain;
        item["delay"] = cmd.delay;
        items.append(item);
    }

    return items;
}

void CommandQueue::onTimerTimeout()
{
    if (!m_isRunning || m_isPaused) {
        return;
    }

    m_currentIndex++;
    emit currentIndexChanged();

    if (m_currentIndex >= m_commandQueue.size()) {
        // Queue finished
        m_isRunning = false;
        m_currentIndex = -1;

        emit isRunningChanged();
        emit currentIndexChanged();
        emit queueFinished();

        emitLog("✅ Queue execution completed");
        return;
    }

    executeCurrentCommand();
}

void CommandQueue::executeCurrentCommand()
{
    if (m_currentIndex < 0 || m_currentIndex >= m_commandQueue.size()) {
        return;
    }

    QList<MqttCommand> list = m_commandQueue.toList();
    const MqttCommand &cmd = list[m_currentIndex];

    emitLog(QString("🚀 Executing [%1/%2]: %3")
                .arg(m_currentIndex + 1)
                .arg(m_commandQueue.size())
                .arg(cmd.name));

    emit publishRequested(cmd.topic, cmd.payload, cmd.qos, cmd.retain);
    emit commandExecuted(cmd.name, cmd.topic, cmd.payload);

    scheduleNextCommand();
}

void CommandQueue::scheduleNextCommand()
{
    if (m_currentIndex < 0 || m_currentIndex >= m_commandQueue.size()) {
        return;
    }

    QList<MqttCommand> list = m_commandQueue.toList();
    const MqttCommand &cmd = list[m_currentIndex];

    int delay = cmd.delay > 0 ? cmd.delay : 1000; // Default 1 second

    emitLog(QString("⏱️  Next command in %1ms").arg(delay));
    m_timer->start(delay);
}

void CommandQueue::emitLog(const QString &message)
{
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    emit logMessage(QString("[%1] %2").arg(timestamp, message));
}

bool CommandQueue::validateCommand(const MqttCommand &cmd)
{
    if (cmd.topic.isEmpty()) {
        emitLog("❌ Command validation failed: empty topic");
        return false;
    }

    if (cmd.topic.contains('+') || cmd.topic.contains('#')) {
        emitLog("❌ Command validation failed: wildcards not allowed in publish topics");
        return false;
    }

    if ((cmd.qos < 0) || (cmd.qos > 2)) {
        emitLog(QString("❌ Command validation failed: invalid QoS (%1)").arg(cmd.qos));
        return false;
    }

    return true;
}
