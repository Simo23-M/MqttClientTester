#ifndef MQTTTREEMODEL_H
#define MQTTTREEMODEL_H

#include <QAbstractListModel>
#include <QHash>
#include <QMap>
#include <QVector>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlEngine>
#include <QDateTime>

struct TreeNode {
    QString segment;       // name of this level (e.g. "broker")
    QString fullTopic;     // complete path (e.g. "$SYS/broker")
    QString message;
    QString timestamp;
    bool received = true;
    QJsonArray history;
    bool hasMessage = false;
    bool expanded = false;
    quint64 updateTick = 0;

    TreeNode *parent = nullptr;
    QMap<QString, TreeNode*> children; // sorted alphabetically

    int subtopicCount = 0; // total topics with messages in subtree

    ~TreeNode() { qDeleteAll(children); }
};

class MqttTreeModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int maxTopics READ maxTopics WRITE setMaxTopics NOTIFY maxTopicsChanged)

public:
    enum Roles {
        TopicRole = Qt::UserRole + 1,
        SegmentRole,
        MessageRole,
        TimestampRole,
        ReceivedRole,
        HistoryJsonRole,
        LevelRole,
        ExpandedRole,
        HasChildrenRole,
        HasMessageRole,
        SubtopicCountRole,
        UpdateTickRole
    };

    explicit MqttTreeModel(QObject *parent = nullptr);
    ~MqttTreeModel();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int maxTopics() const { return m_maxTopics; }
    void setMaxTopics(int max);

    Q_INVOKABLE void addMessageBatch(const QVariantList &messages);
    Q_INVOKABLE void addMessage(const QString &topic, const QString &message, bool received);
    Q_INVOKABLE bool removeByTopic(const QString &topic);
    Q_INVOKABLE void clearHistory(const QString &topic);
    Q_INVOKABLE void clear();
    Q_INVOKABLE QVariantMap get(int index) const;
    Q_INVOKABLE void toggleExpanded(int row);

signals:
    void countChanged();
    void maxTopicsChanged();

private:
    TreeNode *findOrCreateNode(const QString &topic);
    void rebuildFlatList();
    void flattenNode(TreeNode *node, QVector<TreeNode*> &list);
    void applyFlatListDiff(QVector<TreeNode*> &newFlatList);
    void deleteSubtree(TreeNode *node);
    void updateSubtopicCounts(TreeNode *node, int delta);
    int countVisibleDescendants(TreeNode *node) const;
    void collectVisibleDescendants(TreeNode *node, int depth, QVector<TreeNode*> &out);
    void evictOldestMessageNodes(int count);

    TreeNode *m_root = nullptr;
    QVector<TreeNode*> m_flatList;
    QHash<QString, TreeNode*> m_topicNodeMap; // full topic -> leaf node (nodes with messages)
    int m_maxTopics = 10000;
    int m_messageNodeCount = 0; // nodes with hasMessage == true
    quint64 m_globalTick = 0;
    static const int MAX_HISTORY = 20;
};

#endif // MQTTTREEMODEL_H
