#include "commandqueue.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QProcessEnvironment>

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
        emitStructuredLog(QString("Failed to open preset file: %1").arg(filePath), "error");
        emit errorOccurred("Cannot open preset file");
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        setLastError(QString("JSON parse error: %1").arg(parseError.errorString()));
        emitStructuredLog(QString("JSON parse error: %1").arg(parseError.errorString()), "error");
        emit errorOccurred("Invalid JSON format");
        return false;
    }

    if (!doc.isObject()) {
        setLastError("JSON root must be an object");
        emitStructuredLog("JSON root must be an object", "error");
        emit errorOccurred("Invalid JSON structure");
        return false;
    }

    QJsonObject rootObj = doc.object();

    // Check format version and migrate if needed
    if (isV2PresetFormat(rootObj)) {
        m_presetVersion = rootObj.value("version").toInt();
        emitLog(QString("Loaded v%1 preset format").arg(m_presetVersion));

        // Convert v2 format to internal representation
        QJsonArray presetsArray = rootObj.value("presets").toArray();
        m_presets = QJsonObject();

        for (const QJsonValue &presetVal : presetsArray) {
            QJsonObject preset = presetVal.toObject();
            QString name = preset.value("name").toString();

            QJsonArray commands = preset.value("commands").toArray();
            if (!commands.isEmpty()) {
                // Store all commands in the preset, not just the first
                QJsonObject internalPreset;
                internalPreset["description"] = preset.value("description").toString();
                internalPreset["commands"] = commands;
                m_presets[name] = internalPreset;
            }
        }
    } else {
        // v1 format - migrate automatically
        emitLog("Detected v1 preset format, migrating to v2...");

        // Create backup before migration
        if (createBackupFile(filePath)) {
            emitLog(QString("Created backup: %1.bak").arg(filePath));
        }

        // Migrate to v2
        QJsonObject v2Json = migrateV1ToV2(rootObj);

        // Save migrated version
        QFile outFile(filePath);
        if (outFile.open(QIODevice::WriteOnly)) {
            QJsonDocument outDoc(v2Json);
            outFile.write(outDoc.toJson(QJsonDocument::Indented));
            outFile.close();
            emitLog("Migrated preset file to v2 format");
        }

        // Load the migrated presets
        m_presets = rootObj; // Keep original v1 format internally for simplicity
        m_presetVersion = 2;
    }

    m_loadedPresetFile = filePath;
    emit loadedPresetFileChanged();

    emitLog(QString("Loaded %1 presets from: %2")
                .arg(m_presets.keys().size()).arg(filePath));

    return true;
}

bool CommandQueue::savePresetsToFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        setLastError(QString("Cannot create preset file: %1").arg(filePath));
        emitStructuredLog(QString("Failed to create preset file: %1").arg(filePath), "error");
        emit errorOccurred("Cannot create preset file");
        return false;
    }

    // Save in v2 format
    QJsonObject v2Json;
    v2Json["version"] = 2;
    QJsonObject metadata;
    metadata["name"] = "Preset Collection";
    metadata["created"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    v2Json["metadata"] = metadata;

    QJsonArray presetsArray;
    for (const QString &key : m_presets.keys()) {
        QJsonObject internalPreset = m_presets.value(key).toObject();
        QJsonObject presetOut;
        presetOut["name"] = key;
        presetOut["description"] = internalPreset.value("description").toString();
        presetOut["commands"] = internalPreset.value("commands").toArray();
        presetsArray.append(presetOut);
    }
    v2Json["presets"] = presetsArray;

    QJsonDocument doc(v2Json);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();

    m_loadedPresetFile = filePath;
    emit loadedPresetFileChanged();

    emitLog(QString("Saved %1 presets to: %2 (v2 format)")
                .arg(m_presets.keys().size()).arg(filePath));

    return true;
}

QString CommandQueue::getPresetsJson() const
{
    QJsonObject v2Json;
    v2Json["version"] = 2;
    QJsonArray presetsArray;
    for (const QString &key : m_presets.keys()) {
        QJsonObject internalPreset = m_presets.value(key).toObject();
        QJsonObject presetOut;
        presetOut["name"] = key;
        presetOut["description"] = internalPreset.value("description").toString();
        presetOut["commands"] = internalPreset.value("commands").toArray();
        presetsArray.append(presetOut);
    }
    v2Json["presets"] = presetsArray;
    QJsonDocument doc(v2Json);
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
    cmd.commandType = CommandType::Publish;

    if (!validateCommand(cmd)) {
        emitStructuredLog(QString("Invalid command: %1").arg(name), "error");
        return;
    }

    m_commandList.append(cmd);  // O(1) amortized
    emit queueSizeChanged();

    emitLog(QString("Added to queue: %1 [Topic: %2]").arg(name, topic));
}

void CommandQueue::addScriptToQueue(const QString &name, const QString &scriptPath,
                                    const QString &scriptArgs, int delay)
{
    MqttCommand cmd;
    cmd.name = name.isEmpty() ? scriptPath.split('/').last() : name;
    cmd.scriptPath = scriptPath;
    cmd.scriptArgs = scriptArgs;
    cmd.delay = delay;
    cmd.commandType = CommandType::Script;

    if (!validateCommand(cmd)) {
        emitStructuredLog(QString("Invalid script command: %1").arg(name), "error");
        return;
    }

    m_commandList.append(cmd);
    emit queueSizeChanged();

    emitLog(QString("Added script to queue: %1 [%2]").arg(cmd.name, scriptPath));
}

void CommandQueue::executeScriptNow(const QString &scriptPath, const QString &scriptArgs)
{
    if (scriptPath.isEmpty()) {
        emitStructuredLog("executeScriptNow: empty script path", "error");
        return;
    }
    startProcess("immediate", scriptPath, scriptArgs, false);
}

void CommandQueue::removeCommandFromQueue(int index)
{
    if (index < 0 || index >= m_commandList.size()) {
        emitStructuredLog("Invalid queue index", "error");
        return;
    }

    QString name = m_commandList[index].name;
    m_commandList.removeAt(index);  // O(n) in worst case, but much better than previous implementation

    emit queueSizeChanged();
    emitLog(QString("Removed from queue: %1").arg(name));
}

void CommandQueue::clearQueue()
{
    int count = m_commandList.size();
    m_commandList.clear();
    m_currentIndex = -1;

    emit queueSizeChanged();
    emit currentIndexChanged();

    emitLog(QString("Queue cleared (%1 commands removed)").arg(count));
}

void CommandQueue::moveCommandUp(int index)
{
    if (index <= 0 || index >= m_commandList.size()) {
        return;
    }

    // O(1) swap operation
    m_commandList.swapItemsAt(index - 1, index);

    emitLog(QString("Moved command up: %1").arg(m_commandList[index - 1].name));
}

void CommandQueue::moveCommandDown(int index)
{
    if (index < 0 || index >= m_commandList.size() - 1) {
        return;
    }

    // O(1) swap operation
    m_commandList.swapItemsAt(index, index + 1);

    emitLog(QString("Moved command down: %1").arg(m_commandList[index + 1].name));
}

void CommandQueue::startQueue()
{
    if (m_commandList.isEmpty()) {
        setLastError("Cannot start: queue is empty");
        emitStructuredLog("Cannot start: queue is empty", "error");
        emit errorOccurred("Queue is empty");
        return;
    }

    if (m_isRunning) {
        emitStructuredLog("Queue is already running", "warning");
        return;
    }

    m_isRunning = true;
    m_isPaused = false;
    m_currentIndex = 0;

    emit isRunningChanged();
    emit currentIndexChanged();

    emitLog(QString("Starting queue execution (%1 commands)").arg(m_commandList.size()));

    executeCurrentCommand();
}

void CommandQueue::stopQueue()
{
    if (!m_isRunning) {
        return;
    }

    m_timer->stop();

    if (m_currentProcess) {
        m_currentProcess->kill();
        m_currentProcess->deleteLater();
        m_currentProcess = nullptr;
    }

    m_isRunning = false;
    m_isPaused = false;
    m_currentIndex = -1;

    emit isRunningChanged();
    emit currentIndexChanged();

    emitLog("Queue execution stopped");
}

void CommandQueue::pauseQueue()
{
    if (!m_isRunning || m_isPaused) {
        return;
    }

    m_timer->stop();
    m_isPaused = true;

    emitLog("Queue execution paused");
}

void CommandQueue::resumeQueue()
{
    if (!m_isRunning || !m_isPaused) {
        return;
    }

    m_isPaused = false;
    emitLog("Queue execution resumed");

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
        emitStructuredLog("Invalid command index", "error");
        return;
    }

    // O(1) direct access
    const MqttCommand &cmd = m_commandList[index];

    emitStructuredLog(QString("Executing command: %1").arg(cmd.name), "info", cmd.topic, cmd.payload, "out", cmd.qos);
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

    QJsonObject internalPreset = m_presets.value(name).toObject();
    QJsonObject out;
    out["name"] = name;
    out["description"] = internalPreset.value("description").toString();
    out["commands"] = internalPreset.value("commands").toArray();

    QJsonDocument doc(out);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

void CommandQueue::addPresetToQueue(const QString &presetName)
{
    if (!m_presets.contains(presetName)) {
        emitStructuredLog(QString("Preset not found: %1").arg(presetName), "error");
        return;
    }

    QJsonObject preset = m_presets.value(presetName).toObject();
    QJsonArray commands = preset.value("commands").toArray();
    QString description = preset.value("description").toString();

    if (commands.isEmpty()) {
        emitStructuredLog(QString("Preset has no commands: %1").arg(presetName), "error");
        return;
    }

    int added = 0;
    for (const QJsonValue &cmdVal : commands) {
        QJsonObject cmdObj = cmdVal.toObject();
        QString type = cmdObj.value("type").toString(QStringLiteral("publish"));

        MqttCommand cmd;
        cmd.description = description;

        if (type == QLatin1String("script")) {
            cmd.commandType = CommandType::Script;
            cmd.name = cmdObj.value("name").toString(presetName);
            cmd.scriptPath = cmdObj.value("script").toString();
            cmd.scriptArgs = cmdObj.value("args").toString();
            cmd.delay = cmdObj.value("delay").toInt(0);
        } else {
            cmd.commandType = CommandType::Publish;
            cmd.name = cmdObj.value("name").toString(presetName);
            cmd.topic = cmdObj.value("topic").toString();
            cmd.payload = cmdObj.value("payload").toString();
            cmd.qos = cmdObj.value("qos").toInt(0);
            cmd.retain = cmdObj.value("retain").toBool(false);
            cmd.delay = cmdObj.value("delay").toInt(1000);
            cmd.condition = cmdObj.value("condition").toString();
        }

        if (!validateCommand(cmd)) {
            emitStructuredLog(QString("Invalid command in preset '%1', skipping").arg(presetName), "error");
            continue;
        }

        m_commandList.append(cmd);
        added++;
    }

    emit queueSizeChanged();
    emitLog(QString("Added preset to queue: %1 (%2 commands)").arg(presetName).arg(added));
}

void CommandQueue::clearPresets()
{
    int count = m_presets.keys().size();
    m_presets = QJsonObject();
    m_loadedPresetFile.clear();

    emit loadedPresetFileChanged();

    emitLog(QString("Cleared %1 presets").arg(count));
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
        item["commandType"] = static_cast<int>(cmd.commandType);
        item["scriptPath"] = cmd.scriptPath;
        item["scriptArgs"] = cmd.scriptArgs;
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
        item["commandType"] = static_cast<int>(cmd.commandType);
        item["scriptPath"] = cmd.scriptPath;
        item["scriptArgs"] = cmd.scriptArgs;
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

        emitLog("Queue execution completed");
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

    if (cmd.commandType == CommandType::Script) {
        emitStructuredLog(QString("Executing script [%1/%2]: %3")
                    .arg(m_currentIndex + 1)
                    .arg(m_commandList.size())
                    .arg(cmd.name), "info");
        executeScriptCommand(cmd);
        // scheduleNextCommand() will be called by startProcess() on script finish
    } else {
        emitStructuredLog(QString("Executing [%1/%2]: %3")
                    .arg(m_currentIndex + 1)
                    .arg(m_commandList.size())
                    .arg(cmd.name), "info", cmd.topic, cmd.payload, "out", cmd.qos);

        emit publishRequested(cmd.topic, cmd.payload, cmd.qos, cmd.retain);
        emit commandExecuted(cmd.name, cmd.topic, cmd.payload);

        scheduleNextCommand();
    }
}

void CommandQueue::executeScriptCommand(const MqttCommand &cmd)
{
    startProcess(cmd.name, cmd.scriptPath, cmd.scriptArgs, true);
}

void CommandQueue::startProcess(const QString &name, const QString &scriptPath,
                                const QString &scriptArgs, bool continueQueue,
                                const QVariantMap &envVars)
{
    // For queue commands we reuse m_currentProcess slot; for triggers we use a detached process
    if (continueQueue) {
        if (m_currentProcess) {
            m_currentProcess->kill();
            m_currentProcess->deleteLater();
            m_currentProcess = nullptr;
        }
    }

    auto *proc = new QProcess(this);
    if (continueQueue)
        m_currentProcess = proc;

    // Set environment
    if (!envVars.isEmpty()) {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        for (auto it = envVars.cbegin(); it != envVars.cend(); ++it)
            env.insert(it.key(), it.value().toString());
        proc->setProcessEnvironment(env);
    }

    QStringList args;
    QString program;

#ifdef Q_OS_WIN
    program = QStringLiteral("powershell.exe");
    args << QStringLiteral("-ExecutionPolicy") << QStringLiteral("Bypass")
         << QStringLiteral("-File") << scriptPath;
    if (!scriptArgs.isEmpty())
        args << scriptArgs.split(QLatin1Char(' '), Qt::SkipEmptyParts);
#else
    program = QStringLiteral("/bin/bash");
    QString fullCmd = scriptArgs.isEmpty() ? scriptPath : scriptPath + QLatin1Char(' ') + scriptArgs;
    args << QStringLiteral("-c") << fullCmd;
#endif

    emitStructuredLog(QString("Launching script: %1 %2").arg(scriptPath, scriptArgs), "info");

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc, name]() {
        QString out = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
        if (!out.isEmpty())
            emitStructuredLog(QString("[%1] %2").arg(name, out), "info");
    });
    connect(proc, &QProcess::readyReadStandardError, this, [this, proc, name]() {
        QString err = QString::fromUtf8(proc->readAllStandardError()).trimmed();
        if (!err.isEmpty())
            emitStructuredLog(QString("[%1][stderr] %2").arg(name, err), "warning");
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, name, continueQueue](int exitCode, QProcess::ExitStatus) {
        emitStructuredLog(QString("Script '%1' finished with exit code %2").arg(name).arg(exitCode),
                          exitCode == 0 ? "success" : "warning");
        emit scriptOutputReceived(name, QString(), exitCode);
        if (m_currentProcess == proc)
            m_currentProcess = nullptr;
        proc->deleteLater();
        if (continueQueue && m_isRunning && !m_isPaused)
            scheduleNextCommand();
    });

    proc->start(program, args);
    if (!proc->waitForStarted(3000)) {
        emitStructuredLog(QString("Failed to start script: %1").arg(scriptPath), "error");
        if (m_currentProcess == proc)
            m_currentProcess = nullptr;
        proc->deleteLater();
        if (continueQueue && m_isRunning && !m_isPaused)
            scheduleNextCommand();
    }
}

// --- Trigger management ---

QString CommandQueue::addTrigger(const QString &name, const QString &topicPattern,
                                 const QString &eventType, const QString &scriptPath,
                                 const QString &scriptArgs)
{
    ScriptTrigger t;
    t.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    t.name = name.isEmpty() ? topicPattern : name;
    t.topicPattern = topicPattern;
    t.eventType = eventType;
    t.scriptPath = scriptPath;
    t.scriptArgs = scriptArgs;
    t.enabled = true;

    m_triggers.append(t);
    emit triggersChanged();
    emitLog(QString("Trigger added: '%1' [%2 on %3]").arg(t.name, eventType, topicPattern));
    return t.id;
}

void CommandQueue::removeTrigger(const QString &id)
{
    for (int i = 0; i < m_triggers.size(); ++i) {
        if (m_triggers[i].id == id) {
            emitLog(QString("Trigger removed: '%1'").arg(m_triggers[i].name));
            m_triggers.removeAt(i);
            emit triggersChanged();
            return;
        }
    }
}

void CommandQueue::setTriggerEnabled(const QString &id, bool enabled)
{
    for (ScriptTrigger &t : m_triggers) {
        if (t.id == id) {
            t.enabled = enabled;
            emit triggersChanged();
            return;
        }
    }
}

QVariantList CommandQueue::getTriggers() const
{
    QVariantList list;
    for (const ScriptTrigger &t : m_triggers) {
        QVariantMap m;
        m["id"] = t.id;
        m["name"] = t.name;
        m["topicPattern"] = t.topicPattern;
        m["eventType"] = t.eventType;
        m["scriptPath"] = t.scriptPath;
        m["scriptArgs"] = t.scriptArgs;
        m["enabled"] = t.enabled;
        list.append(m);
    }
    return list;
}

bool CommandQueue::matchTopic(const QString &pattern, const QString &topic)
{
    const QStringList patParts = pattern.split(QLatin1Char('/'));
    const QStringList topParts = topic.split(QLatin1Char('/'));

    for (int i = 0; i < patParts.size(); ++i) {
        if (patParts[i] == QLatin1String("#"))
            return true; // matches everything remaining
        if (i >= topParts.size())
            return false;
        if (patParts[i] != QLatin1String("+") && patParts[i] != topParts[i])
            return false;
    }
    return patParts.size() == topParts.size();
}

void CommandQueue::checkTriggers(const QString &topic, const QString &payload,
                                 const QString &eventType)
{
    for (const ScriptTrigger &t : m_triggers) {
        if (!t.enabled) continue;
        if (t.eventType != eventType) continue;
        if (!matchTopic(t.topicPattern, topic)) continue;

        emitStructuredLog(
            QString("Trigger '%1' fired [%2 on %3]").arg(t.name, eventType, topic),
            "info", topic, payload);
        emit triggerFired(t.name, topic, payload);

        QVariantMap env;
        env["MQTT_TOPIC"]   = topic;
        env["MQTT_PAYLOAD"] = payload;
        env["MQTT_EVENT"]   = eventType;

        // Triggers use detached processes (continueQueue = false)
        startProcess(t.name, t.scriptPath, t.scriptArgs, false, env);
    }
}

bool CommandQueue::loadTriggersFromFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emitStructuredLog(QString("Cannot open triggers file: %1").arg(filePath), "error");
        return false;
    }

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &err);
    file.close();

    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        emitStructuredLog(QString("Triggers file parse error: %1").arg(err.errorString()), "error");
        return false;
    }

    QJsonArray arr = doc.object().value("triggers").toArray();
    m_triggers.clear();

    for (const QJsonValue &v : arr) {
        QJsonObject obj = v.toObject();
        ScriptTrigger t;
        t.id          = obj.value("id").toString(QUuid::createUuid().toString(QUuid::WithoutBraces));
        t.name        = obj.value("name").toString();
        t.topicPattern = obj.value("topicPattern").toString();
        t.eventType   = obj.value("eventType").toString();
        t.scriptPath  = obj.value("scriptPath").toString();
        t.scriptArgs  = obj.value("scriptArgs").toString();
        t.enabled     = obj.value("enabled").toBool(true);
        m_triggers.append(t);
    }

    emit triggersChanged();
    emitLog(QString("Loaded %1 triggers from: %2").arg(m_triggers.size()).arg(filePath));
    return true;
}

bool CommandQueue::saveTriggersToFile(const QString &filePath) const
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        // Can't emit non-const log, use qWarning
        qWarning() << "Cannot save triggers file:" << filePath;
        return false;
    }

    QJsonArray arr;
    for (const ScriptTrigger &t : m_triggers) {
        QJsonObject obj;
        obj["id"]           = t.id;
        obj["name"]         = t.name;
        obj["topicPattern"] = t.topicPattern;
        obj["eventType"]    = t.eventType;
        obj["scriptPath"]   = t.scriptPath;
        obj["scriptArgs"]   = t.scriptArgs;
        obj["enabled"]      = t.enabled;
        arr.append(obj);
    }

    QJsonObject root;
    root["version"]  = 1;
    root["triggers"] = arr;

    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return true;
}

void CommandQueue::scheduleNextCommand()
{
    if (m_currentIndex < 0 || m_currentIndex >= m_commandList.size()) {
        return;
    }

    // O(1) direct access
    const MqttCommand &cmd = m_commandList[m_currentIndex];

    int delay = cmd.delay > 0 ? cmd.delay : 1000; // Default 1 second

    emitLog(QString("Next command in %1ms").arg(delay));
    m_timer->start(delay);
}

void CommandQueue::emitLog(const QString &message)
{
    emitStructuredLog(message, "info");
}

void CommandQueue::emitStructuredLog(const QString &message, const QString &level,
                                       const QString &topic, const QString &payload,
                                       const QString &direction, int qos)
{
    QVariantMap entry;
    entry[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss.zzz"));
    entry[QStringLiteral("category")] = QStringLiteral("queue");
    entry[QStringLiteral("level")] = level;
    entry[QStringLiteral("message")] = message;
    entry[QStringLiteral("topic")] = topic;
    entry[QStringLiteral("payload")] = payload.left(200);
    entry[QStringLiteral("direction")] = direction;
    entry[QStringLiteral("qos")] = qos;
    emit logMessage(entry);
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
    if (cmd.commandType == CommandType::Script) {
        if (cmd.scriptPath.isEmpty()) {
            emitStructuredLog("Script validation failed: empty script path", "error");
            return false;
        }
        return true;
    }

    if (cmd.topic.isEmpty()) {
        emitStructuredLog("Command validation failed: empty topic", "error");
        return false;
    }

    if (cmd.topic.contains('+') || cmd.topic.contains('#')) {
        emitStructuredLog("Command validation failed: wildcards not allowed in publish topics", "error");
        return false;
    }

    if ((cmd.qos < 0) || (cmd.qos > 2)) {
        emitStructuredLog(QString("Command validation failed: invalid QoS (%1)").arg(cmd.qos), "error");
        return false;
    }

    return true;
}
