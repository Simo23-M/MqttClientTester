import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import MqttClient 1.0
import AppController 1.0
import CommandQueue 1.0
import "components"
import "tabs"
import "dialogs"

ApplicationWindow {
    id: window

    property double k: 1 // Scale factor for high DPI displays
    property string fontChosed: "Consolas, Monaco, monospace"
    property alias mqttClient: mqttClient
    property alias commandQueue: commandQueue

    width: 1200 * k
    height: 800 * k
    visible: true
    title: qsTr("MQTT TLS Client")

    Material.theme: Material.Dark
    Material.primary: Material.Blue
    Material.accent: Material.Cyan

    // Backend objects
    MqttClient {
        id: mqttClient
        onLogMessage: function(message) {
            logModel.append({"message": message})
        }
        onErrorOccurred: function(error) {
            toastNotification.show(error, "error")
        }
        onMessageReceived: function(topic, message) {
            addToMqttTree(topic, message, true)
        }
    }

    CommandQueue {
        id: commandQueue
        onLogMessage: function(message) {
            logModel.append({"message": message})
        }
        onPublishRequested: function(topic, payload, qos, retain) {
            mqttClient.publish(topic, payload, qos, retain)
        }
        onQueueFinished: toastNotification.show("Queue execution completed", "success")
        onErrorOccurred: function(error) {
            logModel.append({"message": "[ERROR] " + error})
            toastNotification.show(error, "error")
        }
    }

    // Models
    ListModel { id: logModel }
    ListModel { id: mqttTreeModel }
    ListModel { id: activeSubscriptionsModel }
    ListModel { id: presetListModel }
    ListModel { id: queueListModel }

    // Helper functions
    function addToMqttTree(topic, message, received) {
        var timestamp = new Date().toLocaleTimeString()
        var existingIndex = -1
        for (var i = 0; i < mqttTreeModel.count; i++) {
            if (mqttTreeModel.get(i).topic === topic) {
                existingIndex = i
                break
            }
        }
        if (existingIndex >= 0) {
            var existingItem = mqttTreeModel.get(existingIndex)
            var currentHistory = []
            if (existingItem.historyJson && existingItem.historyJson !== "") {
                try { currentHistory = JSON.parse(existingItem.historyJson) } catch (e) { currentHistory = [] }
            }
            currentHistory.push({"message": existingItem.message, "timestamp": existingItem.timestamp})
            if (currentHistory.length > 20) currentHistory = currentHistory.slice(-20)
            mqttTreeModel.setProperty(existingIndex, "message", message)
            mqttTreeModel.setProperty(existingIndex, "timestamp", timestamp)
            mqttTreeModel.setProperty(existingIndex, "historyJson", JSON.stringify(currentHistory))
        } else {
            mqttTreeModel.append({"topic": topic, "message": message, "timestamp": timestamp, "level": topic.split('/').length, "historyJson": "", "received": received})
        }
    }

    function addActiveSubscription(topic, qos) {
        for (var i = 0; i < activeSubscriptionsModel.count; i++) {
            if (activeSubscriptionsModel.get(i).topic === topic) {
                activeSubscriptionsModel.setProperty(i, "qos", qos)
                return
            }
        }
        activeSubscriptionsModel.append({"topic": topic, "qos": qos, "timestamp": new Date().toLocaleTimeString()})
    }

    function removeActiveSubscription(topic) {
        for (var i = 0; i < activeSubscriptionsModel.count; i++) {
            if (activeSubscriptionsModel.get(i).topic === topic) {
                activeSubscriptionsModel.remove(i)
                break
            }
        }
    }

    function updatePresetList() {
        presetListModel.clear()
        var presets = commandQueue.getPresetNames()
        for (var i = 0; i < presets.length; i++) presetListModel.append({"name": presets[i]})
    }

    function updateQueueList() {
        queueListModel.clear()
        var items = commandQueue.getQueueItems()
        for (var i = 0; i < items.length; i++) queueListModel.append(items[i])
    }

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10 * window.k
        spacing: 10 * window.k

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: "Broker & Logs"; font.pixelSize: 14 }
            TabButton { text: "Topics & Messages"; font.pixelSize: 14 }
            TabButton { text: "Topic Management"; font.pixelSize: 14 }
            TabButton { text: "Command Queue"; font.pixelSize: 14 }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            BrokerLogsTab {
                mqttClient: window.mqttClient
                appController: AppController
                logModel: logModel
                scaleFactor: window.k
                fontFamily: window.fontChosed
            }

            TopicsMessagesTab {
                mqttClient: window.mqttClient
                mqttTreeModel: mqttTreeModel
                activeSubscriptionsModel: activeSubscriptionsModel
                scaleFactor: window.k
                fontFamily: window.fontChosed
                onSubscribeRequested: function(topic, qos) {
                    mqttClient.subscribe(topic, qos)
                    addActiveSubscription(topic, qos)
                }
                onUnsubscribeRequested: function(topic) {
                    mqttClient.unsubscribe(topic)
                    removeActiveSubscription(topic)
                }
                onPublishRequested: function(topic, message, qos, retain) {
                    mqttClient.publish(topic, message, qos, retain)
                    addToMqttTree(topic, message, false)
                }
                onMessageClicked: function(topic, message, timestamp, history) {
                    messageDetailDialog.topic = topic
                    messageDetailDialog.message = message
                    messageDetailDialog.timestamp = timestamp
                    messageDetailDialog.history = history
                    messageDetailDialog.open()
                }
                onDeleteRetainedRequested: function(topic) {
                    mqttClient.publish(topic, "", 0, true)
                    toastNotification.show("Retained message deleted: " + topic, "success")
                }
            }

            TopicManagementTab {
                mqttClient: window.mqttClient
                activeSubscriptionsModel: activeSubscriptionsModel
                mqttTreeModel: mqttTreeModel
                scaleFactor: window.k
                fontFamily: window.fontChosed
                onSubscribeRequested: function(topic, qos) {
                    mqttClient.subscribe(topic, qos)
                    addActiveSubscription(topic, qos)
                }
                onUnsubscribeRequested: function(topic) {
                    mqttClient.unsubscribe(topic)
                    removeActiveSubscription(topic)
                }
            }

            CommandQueueTab {
                mqttClient: window.mqttClient
                commandQueue: window.commandQueue
                appController: AppController
                presetListModel: presetListModel
                queueListModel: queueListModel
                scaleFactor: window.k
                fontFamily: window.fontChosed
                onUpdatePresetListRequested: updatePresetList()
                onUpdateQueueListRequested: updateQueueList()
                onShowPresetDetail: function(name, data) {
                    presetDetailDialog.presetName = name
                    presetDetailDialog.presetData = data
                    presetDetailDialog.open()
                }
                onShowJsonView: function(content) {
                    jsonViewDialog.jsonContent = content
                    jsonViewDialog.open()
                }
            }
        }
    }

    // Dialogs
    MessageDetailDialog {
        id: messageDetailDialog
        scaleFactor: window.k
        fontFamily: window.fontChosed
        mqttConnected: mqttClient.connected
        onClearHistoryRequested: function(topic) {
            for (var i = 0; i < mqttTreeModel.count; i++) {
                if (mqttTreeModel.get(i).topic === topic) {
                    mqttTreeModel.setProperty(i, "historyJson", "")
                    break
                }
            }
        }
        onDeleteRetainedRequested: function(topic) {
            // Send empty message with QoS 0 and retain flag to delete retained message
            mqttClient.publish(topic, "", 0, true)
            toastNotification.show("Retained message deleted: " + topic, "success")
        }
    }

    PresetDetailDialog {
        id: presetDetailDialog
        scaleFactor: window.k
        fontFamily: window.fontChosed
        mqttConnected: mqttClient.connected
        onAddToQueueRequested: function(name) {
            commandQueue.addPresetToQueue(name)
            updateQueueList()
        }
        onExecuteNowRequested: function(name) {
            commandQueue.addPresetToQueue(name)
            updateQueueList()
            commandQueue.executeCommand(commandQueue.queueSize - 1)
        }
    }

    JsonViewDialog {
        id: jsonViewDialog
        scaleFactor: window.k
        fontFamily: window.fontChosed
    }

    TopicFilterHelpDialog {
        id: topicFilterHelpDialog
        scaleFactor: window.k
        fontFamily: window.fontChosed
    }

    // Toast notification
    ToastNotification {
        id: toastNotification
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80 * window.k
        scaleFactor: window.k
    }

    // Help button
    RoundButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20 * window.k
        width: 50 * window.k
        height: 50 * window.k
        text: "?"
        font.pixelSize: 18
        font.bold: true
        Material.background: Material.accent
        onClicked: topicFilterHelpDialog.open()
        ToolTip.visible: hovered
        ToolTip.text: "Topic Wildcards Help"
    }
}
