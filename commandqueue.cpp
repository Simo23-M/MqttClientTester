#include "commandqueue.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>
#include <QFileInfo>
#include <QDir>

CommandQueue::CommandQueue(QObject *parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
    , m_isRunning(false)
    , m_isPaused(false)
    , m_currentIndex(-1)
    , m_presetVersion(1)
{
    m_timer->setSingleShot(true);
    connect(m_timer, &QTimer::timeout, this, &CommandQueue::onTimerTimeout);

    emitLog("Command Queue initialized");
}

bool CommandQueue::isV2PresetFormat(const QJsonObject &json) const
{
    return json.contains("version") && json.value("version").toInt() >= 2;
}

QJsonObject CommandQueue::migrateV1ToV2(const QJsonObject &v1Json) const
{
    QJsonObject v2Json;
    v2Json["version"] = 2;

    // Add metadata
    QJsonObject metadata;
    metadata["name"] = "Migrated Presets";
    metadata["created"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    metadata["description"] = "Automatically migrated from v1 format";
    v2Json["metadata"] = metadata;

    // Convert presets
    QJsonArray presetsArray;
    for (const QString &key : v1Json.keys()) {
        QJsonObject v1Preset = v1Json.value(key).toObject();
        QJsonObject v2Preset;

        v2Preset["name"] = key;
        v2Preset["description"] = v1Preset.value("description").toString();

        // Create single command from v1 preset
        QJsonObject command;
        command["topic"] = v1Preset.value("topic").toString();
        command["payload"] = v1Preset.value("payload").toString();
        command["qos"] = v1Preset.value("qos").toInt(0);
        command["retain"] = v1Preset.value("retain").toBool(false);
        command["delay"] = v1Preset.value("delay").toInt(1000);

        QJsonArray commands;
        commands.append(command);
        v2Preset["commands"] = commands;

        presetsArray.append(v2Preset);
    }

    v2Json["presets"] = presetsArray;
    return v2Json;
}

bool CommandQueue::createBackupFile(const QString &filePath) const
{
    QFile originalFile(filePath);
    if (!originalFile.exists()) {
        return true; // No file to backup
    }

    QString backupPath = filePath + ".bak";
    QFile backupFile(backupPath);

    // Remove existing backup
    if (backupFile.exists()) {
        backupFile.remove();
    }

    return originalFile.copy(backupPath);
}

bool CommandQueue::loadPresetsFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        setLastError(QString("Cannot open preset file: %1").arg(filePath));
        emitLog(QString("❌ Failed to open preset file: %1").arg(filePath));
        emit errorOccurred("Cannot open preset file");
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        setLastError(QString("JSON parse error: %1").arg(parseError.errorString()));
        emitLog(QString("❌ JSON parse error: %1").arg(parseError.errorString()));
        emit errorOccurred("Invalid JSON format");
        return false;
    }

    if (!doc.isObject()) {
        setLastError("JSON root must be an object");
        emitLog("❌ JSON root must be an object");
        emit errorOccurred("Invalid JSON structure");
        return false;
    }

    QJsonObject rootObj = doc.object();

    // Check format version and migrate if needed
    if (isV2PresetFormat(rootObj)) {
        m_presetVersion = rootObj.value("version").toInt();
        emitLog(QString("📄 Loaded v%1 preset format").arg(m_presetVersion));

        // Convert v2 format to internal representation
        QJsonArray presetsArray = rootObj.value("presets").toArray();
        m_presets = QJsonObject();

        for (const QJsonValue &presetVal : presetsArray) {
            QJsonObject preset = presetVal.toObject();
            QString name = preset.value("name").toString();

            // For now, take the first command from the commands array
            QJsonArray commands = preset.value("commands").toArray();
            if (!commands.isEmpty()) {
                QJsonObject cmd = commands.first().toObject();
                QJsonObject internalPreset;
                internalPreset["topic"] = cmd.value("topic").toString();
                internalPreset["payload"] = cmd.value("payload").toString();
                internalPreset["qos"] = cmd.value("qos").toInt(0);
                internalPreset["retain"] = cmd.value("retain").toBool(false);
                internalPreset["delay"] = cmd.value("delay").toInt(1000);
                internalPreset["description"] = preset.value("description").toString();
                m_presets[name] = internalPreset;
            }
        }
    } else {
        // v1 format - migrate automatically
        emitLog("📄 Detected v1 preset format, migrating to v2...");

        // Create backup before migration
        if (createBackupFile(filePath)) {
            emitLog(QString("💾 Created backup: %1.bak").arg(filePath));
        }

        // Migrate to v2
        QJsonObject v2Json = migrateV1ToV2(rootObj);

        // Save migrated version
        QFile outFile(filePath);
        if (outFile.open(QIODevice::WriteOnly)) {
            QJsonDocument outDoc(v2Json);
            outFile.write(outDoc.toJson(QJsonDocument::Indented));
            outFile.close();
            emitLog("✅ Migrated preset file to v2 format");
        }

        // Load the migrated presets
        m_presets = rootObj; // Keep original v1 format internally for simplicity
        m_presetVersion = 2;
    }

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
        setLastError(QString("Cannot create preset file: %1").arg(filePath));
        emitLog(QString("❌ Failed to create preset file: %1").arg(filePath));
        emit errorOccurred("Cannot create preset file");
        return false;
    }

    // Always save in v2 format
    QJsonObject v2Json = migrateV1ToV2(m_presets);
    QJsonDocument doc(v2Json);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();

    m_loadedPresetFile = filePath;
    emit loadedPresetFileChanged();

    emitLog(QString("💾 Saved %1 presets to: %2 (v2 format)")
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

    m_commandList.append(cmd);  // O(1) amortized
    emit queueSizeChanged();

    emitLog(QString("➕ Added to queue: %1 [Topic: %2]").arg(name, topic));
}

void CommandQueue::removeCommandFromQueue(int index)
{
    if (index < 0 || index >= m_commandList.size()) {
        emitLog("❌ Invalid queue index");
        return;
    }

    QString name = m_commandList[index].name;
    m_commandList.removeAt(index);  // O(n) in worst case, but much better than previous implementation

    emit queueSizeChanged();
    emitLog(QString("➖ Removed from queue: %1").arg(name));
}

void CommandQueue::clearQueue()
{
    int count = m_commandList.size();
    m_commandList.clear();
    m_currentIndex = -1;

    emit queueSizeChanged();
    emit currentIndexChanged();

    emitLog(QString("🗑️  Queue cleared (%1 commands removed)").arg(count));
}

void CommandQueue::moveCommandUp(int index)
{
    if (index <= 0 || index >= m_commandList.size()) {
        return;
    }

    // O(1) swap operation
    m_commandList.swapItemsAt(index - 1, index);

    emitLog(QString("⬆️  Moved command up: %1").arg(m_commandList[index - 1].name));
}

void CommandQueue::moveCommandDown(int index)
{
    if (index < 0 || index >= m_commandList.size() - 1) {
        return;
    }

    // O(1) swap operation
    m_commandList.swapItemsAt(index, index + 1);

    emitLog(QString("⬇️  Moved command down: %1").arg(m_commandList[index + 1].name));
}

void CommandQueue::startQueue()
{
    if (m_commandList.isEmpty()) {
        setLastError("Cannot start: queue is empty");
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

    emitLog(QString("▶️  Starting queue execution (%1 commands)").arg(m_commandList.size()));

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
    if (m_commandList.isEmpty()) {
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
    if (index < 0 || index >= m_commandList.size()) {
        emitLog("❌ Invalid command index");
        return;
    }

    // O(1) direct access
    const MqttCommand &cmd = m_commandList[index];

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
    cmd.description = preset.value("description").toString();

    if (!validateCommand(cmd)) {
        emitLog(QString("❌ Invalid preset configuration: %1").arg(presetName));
        return;
    }

    m_commandList.append(cmd);  // O(1) amortized
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

    // O(n) conversion, but no extra copying of the queue
    for (const MqttCommand &cmd : m_commandList) {
        QVariantMap item;
        item["name"] = cmd.name;
        item["topic"] = cmd.topic;
        item["payload"] = cmd.payload;
        item["qos"] = cmd.qos;
        item["retain"] = cmd.retain;
        item["delay"] = cmd.delay;
        item["description"] = cmd.description;
        items.append(item);
    }

    return items;
}

QVariantMap CommandQueue::getCommandAtIndex(int index) const
{
    QVariantMap item;

    if (index >= 0 && index < m_commandList.size()) {
        // O(1) direct access
        const MqttCommand &cmd = m_commandList[index];
        item["name"] = cmd.name;
        item["topic"] = cmd.topic;
        item["payload"] = cmd.payload;
        item["qos"] = cmd.qos;
        item["retain"] = cmd.retain;
        item["delay"] = cmd.delay;
        item["description"] = cmd.description;
    }

    return item;
}

void CommandQueue::onTimerTimeout()
{
    if (!m_isRunning || m_isPaused) {
        return;
    }

    m_currentIndex++;
    emit currentIndexChanged();

    if (m_currentIndex >= m_commandList.size()) {
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
    if (m_currentIndex < 0 || m_currentIndex >= m_commandList.size()) {
        return;
    }

    // O(1) direct access
    const MqttCommand &cmd = m_commandList[m_currentIndex];

    emitLog(QString("🚀 Executing [%1/%2]: %3")
                .arg(m_currentIndex + 1)
                .arg(m_commandList.size())
                .arg(cmd.name));

    emit publishRequested(cmd.topic, cmd.payload, cmd.qos, cmd.retain);
    emit commandExecuted(cmd.name, cmd.topic, cmd.payload);

    scheduleNextCommand();
}

void CommandQueue::scheduleNextCommand()
{
    if (m_currentIndex < 0 || m_currentIndex >= m_commandList.size()) {
        return;
    }

    // O(1) direct access
    const MqttCommand &cmd = m_commandList[m_currentIndex];

    int delay = cmd.delay > 0 ? cmd.delay : 1000; // Default 1 second

    emitLog(QString("⏱️  Next command in %1ms").arg(delay));
    m_timer->start(delay);
}

void CommandQueue::emitLog(const QString &message)
{
    QString timestamp = QDateTime::currentDateTime().toString("hh:mm:ss");
    emit logMessage(QString("[%1] %2").arg(timestamp, message));
}

void CommandQueue::setLastError(const QString &error)
{
    if (m_lastError != error) {
        m_lastError = error;
        emit lastErrorChanged();
    }
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
