#include "mqtttreemodel.h"

MqttTreeModel::MqttTreeModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_root = new TreeNode;
    m_root->segment = QString();
    m_root->fullTopic = QString();
}

MqttTreeModel::~MqttTreeModel()
{
    delete m_root;
}

int MqttTreeModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_flatList.size();
}

QVariant MqttTreeModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_flatList.size())
        return QVariant();

    const TreeNode *node = m_flatList.at(index.row());

    switch (role) {
    case TopicRole:
        return node->fullTopic;
    case SegmentRole:
        return node->segment;
    case MessageRole:
        return node->message;
    case TimestampRole:
        return node->timestamp;
    case ReceivedRole:
        return node->received;
    case HistoryJsonRole:
        if (node->history.isEmpty())
            return QString();
        return QString::fromUtf8(QJsonDocument(node->history).toJson(QJsonDocument::Compact));
    case LevelRole: {
        // Compute depth: count parents up to root
        int depth = 0;
        TreeNode *p = node->parent;
        while (p && p != m_root) {
            ++depth;
            p = p->parent;
        }
        return depth;
    }
    case ExpandedRole:
        return node->expanded;
    case HasChildrenRole:
        return !node->children.isEmpty();
    case HasMessageRole:
        return node->hasMessage;
    case SubtopicCountRole:
        return node->subtopicCount;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> MqttTreeModel::roleNames() const
{
    return {
        {TopicRole, "topic"},
        {SegmentRole, "segment"},
        {MessageRole, "message"},
        {TimestampRole, "timestamp"},
        {ReceivedRole, "received"},
        {HistoryJsonRole, "historyJson"},
        {LevelRole, "level"},
        {ExpandedRole, "expanded"},
        {HasChildrenRole, "hasChildren"},
        {HasMessageRole, "hasMessage"},
        {SubtopicCountRole, "subtopicCount"}
    };
}

void MqttTreeModel::setMaxTopics(int max)
{
    if (m_maxTopics != max) {
        m_maxTopics = max;
        emit maxTopicsChanged();
    }
}

TreeNode *MqttTreeModel::findOrCreateNode(const QString &topic)
{
    const QStringList segments = topic.split(QLatin1Char('/'));
    TreeNode *current = m_root;
    QString path;

    for (int i = 0; i < segments.size(); ++i) {
        const QString &seg = segments.at(i);
        if (i > 0)
            path += QLatin1Char('/');
        path += seg;

        auto it = current->children.find(seg);
        if (it != current->children.end()) {
            current = it.value();
        } else {
            TreeNode *child = new TreeNode;
            child->segment = seg;
            child->fullTopic = path;
            child->parent = current;
            current->children.insert(seg, child);
            current = child;
        }
    }
    return current;
}

void MqttTreeModel::rebuildFlatList()
{
    m_flatList.clear();
    m_flatList.reserve(m_messageNodeCount * 2);
    for (auto it = m_root->children.constBegin(); it != m_root->children.constEnd(); ++it) {
        flattenNode(it.value(), m_flatList);
    }
}

void MqttTreeModel::flattenNode(TreeNode *node, QVector<TreeNode*> &list)
{
    list.append(node);
    if (node->expanded) {
        for (auto it = node->children.constBegin(); it != node->children.constEnd(); ++it) {
            flattenNode(it.value(), list);
        }
    }
}

void MqttTreeModel::applyFlatListDiff(QVector<TreeNode*> &newFlatList)
{
    int oldSize = m_flatList.size();
    int newSize = newFlatList.size();

    if (oldSize == 0 && newSize == 0)
        return;

    if (oldSize == 0) {
        beginInsertRows(QModelIndex(), 0, newSize - 1);
        m_flatList = std::move(newFlatList);
        endInsertRows();
        return;
    }

    if (newSize == 0) {
        beginRemoveRows(QModelIndex(), 0, oldSize - 1);
        m_flatList.clear();
        endRemoveRows();
        return;
    }

    if (newSize > oldSize) {
        // Signal new rows appended, then swap + refresh existing
        beginInsertRows(QModelIndex(), oldSize, newSize - 1);
        m_flatList = std::move(newFlatList);
        endInsertRows();
    } else if (newSize < oldSize) {
        beginRemoveRows(QModelIndex(), newSize, oldSize - 1);
        m_flatList = std::move(newFlatList);
        endRemoveRows();
    } else {
        m_flatList = std::move(newFlatList);
    }

    // Refresh all existing rows (content/position may have shifted)
    int minSize = qMin(oldSize, newSize);
    if (minSize > 0) {
        emit dataChanged(createIndex(0, 0), createIndex(minSize - 1, 0));
    }
}

void MqttTreeModel::updateSubtopicCounts(TreeNode *node, int delta)
{
    TreeNode *p = node->parent;
    while (p && p != m_root) {
        p->subtopicCount += delta;
        p = p->parent;
    }
    // Also update root's direct children subtopicCount is already handled
    // since we stop at m_root
}

int MqttTreeModel::countVisibleDescendants(TreeNode *node) const
{
    if (!node->expanded)
        return 0;
    int count = 0;
    for (auto it = node->children.constBegin(); it != node->children.constEnd(); ++it) {
        ++count;
        count += countVisibleDescendants(it.value());
    }
    return count;
}

void MqttTreeModel::collectVisibleDescendants(TreeNode *node, int depth, QVector<TreeNode*> &out)
{
    for (auto it = node->children.constBegin(); it != node->children.constEnd(); ++it) {
        out.append(it.value());
        if (it.value()->expanded) {
            collectVisibleDescendants(it.value(), depth + 1, out);
        }
    }
}

void MqttTreeModel::addMessageBatch(const QVariantList &messages)
{
    if (messages.isEmpty())
        return;

    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));

    bool hasNewNodes = false;
    QVector<int> updatedRows;

    for (const QVariant &v : messages) {
        const QVariantMap map = v.toMap();
        const QString topic = map.value(QStringLiteral("topic")).toString();
        const QString message = map.value(QStringLiteral("message")).toString();

        auto existing = m_topicNodeMap.constFind(topic);
        if (existing != m_topicNodeMap.constEnd()) {
            // Update existing node
            TreeNode *node = existing.value();

            QJsonObject histEntry;
            histEntry[QStringLiteral("message")] = node->message;
            histEntry[QStringLiteral("timestamp")] = node->timestamp;
            node->history.append(histEntry);
            if (node->history.size() > MAX_HISTORY)
                node->history.removeFirst();

            node->message = message;
            node->timestamp = timestamp;
            node->received = true;

            // Find row in flat list for dataChanged
            int row = m_flatList.indexOf(node);
            if (row >= 0)
                updatedRows.append(row);
        } else {
            // New topic - create node
            TreeNode *node = findOrCreateNode(topic);
            node->message = message;
            node->timestamp = timestamp;
            node->received = true;
            node->hasMessage = true;
            m_topicNodeMap.insert(topic, node);
            m_messageNodeCount++;
            updateSubtopicCounts(node, 1);
            hasNewNodes = true;
        }
    }

    // Evict if over cap
    if (m_messageNodeCount > m_maxTopics) {
        int toEvict = m_messageNodeCount - m_maxTopics;
        evictOldestMessageNodes(toEvict);
        hasNewNodes = true; // force rebuild
    }

    if (hasNewNodes) {
        QVector<TreeNode*> newFlat;
        newFlat.reserve(m_messageNodeCount * 2);
        for (auto it = m_root->children.constBegin(); it != m_root->children.constEnd(); ++it)
            flattenNode(it.value(), newFlat);
        applyFlatListDiff(newFlat);
    } else if (!updatedRows.isEmpty()) {
        // Emit dataChanged for updated rows
        for (int row : updatedRows) {
            emit dataChanged(
                createIndex(row, 0),
                createIndex(row, 0),
                {MessageRole, TimestampRole, HistoryJsonRole}
            );
        }
    }

    emit countChanged();
}

void MqttTreeModel::addMessage(const QString &topic, const QString &message, bool received)
{
    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));

    auto existing = m_topicNodeMap.constFind(topic);
    if (existing != m_topicNodeMap.constEnd()) {
        TreeNode *node = existing.value();

        QJsonObject histEntry;
        histEntry[QStringLiteral("message")] = node->message;
        histEntry[QStringLiteral("timestamp")] = node->timestamp;
        node->history.append(histEntry);
        if (node->history.size() > MAX_HISTORY)
            node->history.removeFirst();

        node->message = message;
        node->timestamp = timestamp;
        node->received = received;

        int row = m_flatList.indexOf(node);
        if (row >= 0) {
            emit dataChanged(
                createIndex(row, 0),
                createIndex(row, 0),
                {MessageRole, TimestampRole, ReceivedRole, HistoryJsonRole}
            );
        }
    } else {
        // Evict if at cap
        if (m_messageNodeCount >= m_maxTopics) {
            evictOldestMessageNodes(1);
        }

        TreeNode *node = findOrCreateNode(topic);
        node->message = message;
        node->timestamp = timestamp;
        node->received = received;
        node->hasMessage = true;
        m_topicNodeMap.insert(topic, node);
        m_messageNodeCount++;
        updateSubtopicCounts(node, 1);

        QVector<TreeNode*> newFlat;
        newFlat.reserve(m_messageNodeCount * 2);
        for (auto it = m_root->children.constBegin(); it != m_root->children.constEnd(); ++it)
            flattenNode(it.value(), newFlat);
        applyFlatListDiff(newFlat);
    }

    emit countChanged();
}

void MqttTreeModel::toggleExpanded(int row)
{
    if (row < 0 || row >= m_flatList.size())
        return;

    TreeNode *node = m_flatList[row];
    if (node->children.isEmpty())
        return;

    if (node->expanded) {
        // Collapse: remove all visible descendants
        int descendantCount = countVisibleDescendants(node);
        if (descendantCount > 0) {
            beginRemoveRows(QModelIndex(), row + 1, row + descendantCount);
            m_flatList.remove(row + 1, descendantCount);
            endRemoveRows();
        }
        node->expanded = false;
    } else {
        // Expand: insert direct children (and their expanded subtrees)
        node->expanded = true;
        QVector<TreeNode*> toInsert;
        collectVisibleDescendants(node, 0, toInsert);
        if (!toInsert.isEmpty()) {
            beginInsertRows(QModelIndex(), row + 1, row + toInsert.size());
            for (int i = 0; i < toInsert.size(); ++i) {
                m_flatList.insert(row + 1 + i, toInsert.at(i));
            }
            endInsertRows();
        }
    }

    // Notify the row itself changed (expanded state)
    emit dataChanged(createIndex(row, 0), createIndex(row, 0), {ExpandedRole});
}

bool MqttTreeModel::removeByTopic(const QString &topic)
{
    auto it = m_topicNodeMap.constFind(topic);
    if (it == m_topicNodeMap.constEnd())
        return false;

    TreeNode *node = it.value();
    m_topicNodeMap.erase(it);
    m_messageNodeCount--;
    updateSubtopicCounts(node, -1);

    // Clear message data but keep node if it has children
    node->message.clear();
    node->timestamp.clear();
    node->history = QJsonArray();
    node->hasMessage = false;

    // Clean up empty branch nodes going up
    TreeNode *current = node;
    while (current != m_root && current->children.isEmpty() && !current->hasMessage) {
        TreeNode *parent = current->parent;
        parent->children.remove(current->segment);
        delete current;
        current = parent;
    }

    QVector<TreeNode*> newFlat;
    newFlat.reserve(m_messageNodeCount * 2);
    for (auto it = m_root->children.constBegin(); it != m_root->children.constEnd(); ++it)
        flattenNode(it.value(), newFlat);
    applyFlatListDiff(newFlat);
    emit countChanged();
    return true;
}

void MqttTreeModel::clearHistory(const QString &topic)
{
    auto it = m_topicNodeMap.constFind(topic);
    if (it == m_topicNodeMap.constEnd())
        return;

    TreeNode *node = it.value();
    node->history = QJsonArray();

    int row = m_flatList.indexOf(node);
    if (row >= 0) {
        emit dataChanged(createIndex(row, 0), createIndex(row, 0), {HistoryJsonRole});
    }
}

void MqttTreeModel::clear()
{
    if (m_root->children.isEmpty())
        return;

    beginResetModel();
    qDeleteAll(m_root->children);
    m_root->children.clear();
    m_flatList.clear();
    m_topicNodeMap.clear();
    m_messageNodeCount = 0;
    endResetModel();
    emit countChanged();
}

QVariantMap MqttTreeModel::get(int index) const
{
    QVariantMap result;
    if (index < 0 || index >= m_flatList.size())
        return result;

    const TreeNode *node = m_flatList.at(index);
    result[QStringLiteral("topic")] = node->fullTopic;
    result[QStringLiteral("segment")] = node->segment;
    result[QStringLiteral("message")] = node->message;
    result[QStringLiteral("timestamp")] = node->timestamp;
    result[QStringLiteral("received")] = node->received;
    result[QStringLiteral("hasMessage")] = node->hasMessage;
    result[QStringLiteral("hasChildren")] = !node->children.isEmpty();
    result[QStringLiteral("subtopicCount")] = node->subtopicCount;

    // Compute level
    int depth = 0;
    TreeNode *p = node->parent;
    while (p && p != m_root) {
        ++depth;
        p = p->parent;
    }
    result[QStringLiteral("level")] = depth;

    if (!node->history.isEmpty())
        result[QStringLiteral("historyJson")] = QString::fromUtf8(QJsonDocument(node->history).toJson(QJsonDocument::Compact));
    else
        result[QStringLiteral("historyJson")] = QString();
    return result;
}

void MqttTreeModel::deleteSubtree(TreeNode *node)
{
    // Remove all message nodes in the subtree from the map
    if (node->hasMessage) {
        m_topicNodeMap.remove(node->fullTopic);
        m_messageNodeCount--;
    }
    for (auto it = node->children.constBegin(); it != node->children.constEnd(); ++it) {
        deleteSubtree(it.value());
    }
}

void MqttTreeModel::evictOldestMessageNodes(int count)
{
    // Simple eviction: remove the first 'count' message nodes found in topicNodeMap
    // This is a rough approach - iterate the map and remove oldest by insertion order
    // QHash doesn't preserve order, so we just remove arbitrary ones
    auto it = m_topicNodeMap.begin();
    int removed = 0;
    while (it != m_topicNodeMap.end() && removed < count) {
        TreeNode *node = it.value();
        it = m_topicNodeMap.erase(it);
        m_messageNodeCount--;
        updateSubtopicCounts(node, -1);

        node->message.clear();
        node->timestamp.clear();
        node->history = QJsonArray();
        node->hasMessage = false;

        // Clean up empty branch nodes
        TreeNode *current = node;
        while (current != m_root && current->children.isEmpty() && !current->hasMessage) {
            TreeNode *parent = current->parent;
            parent->children.remove(current->segment);
            delete current;
            current = parent;
        }
        removed++;
    }
}
