import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import MqttClient 1.0
import AppController 1.0

ApplicationWindow {
    property double k: 1 // Scale factor for high DPI displays

    id: window

    width: 1200 * window.k
    height: 800 * window.k
    visible: true
    title: qsTr("MQTT TLS Client")

    Material.theme: Material.Dark
    Material.primary: Material.Blue
    Material.accent: Material.Cyan

    property alias mqttClient: mqttClient
    property string fontChosed: "Consolas, Monaco, monospace"

    MqttClient {
        id: mqttClient

        onLogMessage: function(message) {
            logModel.append({"message": message})
            logView.positionViewAtEnd()
        }

        onErrorOccurred: function(error) {
            // todo implement error handling
        }

        onMessageReceived: function(topic, message) {
            // Add received message to tree view
            addToMqttTree(topic, message, true)
        }
    }

    // Function to add messages to MQTT tree
    function addToMqttTree(topic, message, received) {
        var timestamp = new Date().toLocaleTimeString()
        var topicParts = topic.split('/')

        // Check if topic already exists
        var existingIndex = -1
        for (var i = 0; i < mqttTreeModel.count; i++) {
            if (mqttTreeModel.get(i).topic === topic) {
                existingIndex = i
                break
            }
        }

        if (existingIndex >= 0) {
            // Topic exists, update it and add to history
            var existingItem = mqttTreeModel.get(existingIndex)

            // Get existing history as a JavaScript array
            var currentHistory = []
            if (existingItem.historyJson && existingItem.historyJson !== "") {
                try {
                    currentHistory = JSON.parse(existingItem.historyJson)
                } catch (e) {
                    currentHistory = []
                }
            }

            // Add current message to history
            currentHistory.push({
                "message": existingItem.message,
                "timestamp": existingItem.timestamp
            })

            // Keep only last 20 messages in history to avoid memory issues
            if (currentHistory.length > 20) {
                currentHistory = currentHistory.slice(-20)
            }

            // Update the existing item with new message and updated history
            mqttTreeModel.setProperty(existingIndex, "message", message)
            mqttTreeModel.setProperty(existingIndex, "timestamp", timestamp)
            mqttTreeModel.setProperty(existingIndex, "historyJson", JSON.stringify(currentHistory))
        } else {
            // New topic, add to tree model
            mqttTreeModel.append({
                "topic": topic,
                "message": message,
                "timestamp": timestamp,
                "level": topicParts.length,
                "historyJson": "",
                "received": received
            })
        }
    }

    // Function to add subscription to active list
    function addActiveSubscription(topic, qos) {
        // Check if subscription already exists
        for (var i = 0; i < activeSubscriptionsModel.count; i++) {
            if (activeSubscriptionsModel.get(i).topic === topic) {
                activeSubscriptionsModel.setProperty(i, "qos", qos)
                return
            }
        }

        // Add new subscription
        activeSubscriptionsModel.append({
            "topic": topic,
            "qos": qos,
            "timestamp": new Date().toLocaleTimeString()
        })
    }

    // Function to remove subscription from active list
    function removeActiveSubscription(topic) {
        for (var i = 0; i < activeSubscriptionsModel.count; i++) {
            if (activeSubscriptionsModel.get(i).topic === topic) {
                activeSubscriptionsModel.remove(i)
                break
            }
        }
    }

    // File dialogs
    FileDialog {
        id: caCertDialog
        title: "Select CA Certificate"
        nameFilters: ["Certificate Files (*.crt *.pem *.cert)", "All Files (*)"]
        folder: AppController.localFileToUrl(AppController.getDocumentsPath())
        onAccepted: {
            var filePath = AppController.urlToLocalFile(file)
            caCertField.text = filePath
            mqttClient.caCertPath = filePath
        }
    }

    FileDialog {
        id: clientCertDialog
        title: "Select Client Certificate"
        nameFilters: ["Certificate Files (*.crt *.pem *.cert)", "All Files (*)"]
        folder: AppController.localFileToUrl(AppController.getDocumentsPath())
        onAccepted: {
            var filePath = AppController.urlToLocalFile(file)
            clientCertField.text = filePath
            mqttClient.clientCertPath = filePath
        }
    }

    FileDialog {
        id: clientKeyDialog
        title: "Select Client Private Key"
        nameFilters: ["Key Files (*.key *.pem)", "All Files (*)"]
        folder: AppController.localFileToUrl(AppController.getDocumentsPath())
        onAccepted: {
            var filePath = AppController.urlToLocalFile(file)
            clientKeyField.text = filePath
            mqttClient.clientKeyPath = filePath
        }
    }

    // Main content with tabs
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10 * window.k
        spacing: 10 * window.k

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            TabButton {
                text: "Broker & Logs"
                font.pixelSize: 14
            }

            TabButton {
                text: "Topics & Messages"
                font.pixelSize: 14
            }

            TabButton {
                text: "Topic Management"
                font.pixelSize: 14
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // Tab 1: Broker Settings + Logs
            RowLayout {
                spacing: 10 * window.k

                // Left panel - Connection and TLS Settings
                ScrollView {
                    Layout.preferredWidth: 400 * window.k
                    Layout.fillHeight: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 15 * window.k

                        // Connection Settings
                        GroupBox {
                            title: "Connection Settings"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                GridLayout {
                                    columns: 2
                                    Layout.fillWidth: true

                                    Label { text: "Host:" }
                                    TextField {
                                        id: hostField
                                        text: mqttClient.hostName
                                        placeholderText: "localhost"
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.hostName = text
                                    }

                                    Label { text: "Port:" }
                                    SpinBox {
                                        id: portSpinBox
                                        from: 1
                                        to: 65535
                                        value: mqttClient.port
                                        onValueChanged: mqttClient.port = value
                                        editable: true
                                        Layout.fillWidth: true
                                    }

                                    Label { text: "Client ID:" }
                                    TextField {
                                        id: clientIdField
                                        text: mqttClient.clientId
                                        placeholderText: "Auto-generated if empty"
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.clientId = text
                                    }

                                    Label { text: "Username:" }
                                    TextField {
                                        id: usernameField
                                        text: mqttClient.username
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.username = text
                                    }

                                    Label { text: "Password:" }
                                    TextField {
                                        id: passwordField
                                        text: mqttClient.password
                                        echoMode: TextInput.Password
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.password = text
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Button {
                                        text: "Connect"
                                        enabled: !mqttClient.connected
                                        Material.background: Material.Green
                                        onClicked: mqttClient.connectToHost()
                                    }

                                    Button {
                                        text: "Disconnect"
                                        enabled: mqttClient.connected || mqttClient.connectionState === "Connecting"
                                        Material.background: Material.Red
                                        onClicked: mqttClient.disconnectFromHost()
                                    }

                                    Item { Layout.fillWidth: true }

                                    Label {
                                        text: mqttClient.connectionState
                                        font.bold: true
                                        color: mqttClient.connected ? Material.color(Material.Green) :
                                               mqttClient.connectionState === "Connecting" ? Material.color(Material.Orange) :
                                               Material.color(Material.Red)
                                    }
                                }
                            }
                        }

                        // TLS Settings
                        GroupBox {
                            title: "TLS Settings"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                // CA Certificate
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "CA Certificate:"
                                        Layout.minimumWidth: 100 * window.k
                                    }
                                    TextField {
                                        id: caCertField
                                        text: mqttClient.caCertPath
                                        placeholderText: "Path to CA certificate"
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.caCertPath = text
                                    }
                                    Button {
                                        text: "Browse"
                                        onClicked: caCertDialog.open()
                                    }
                                }

                                // Client Certificate
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "Client Certificate:"
                                        Layout.minimumWidth: 100 * window.k
                                    }
                                    TextField {
                                        id: clientCertField
                                        text: mqttClient.clientCertPath
                                        placeholderText: "Path to client certificate"
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.clientCertPath = text
                                    }
                                    Button {
                                        text: "Browse"
                                        onClicked: clientCertDialog.open()
                                    }
                                }

                                // Client Key
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "Client Key:"
                                        Layout.minimumWidth: 100 * window.k
                                    }
                                    TextField {
                                        id: clientKeyField
                                        text: mqttClient.clientKeyPath
                                        placeholderText: "Path to client private key"
                                        Layout.fillWidth: true
                                        onTextChanged: mqttClient.clientKeyPath = text
                                    }
                                    Button {
                                        text: "Browse"
                                        onClicked: clientKeyDialog.open()
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right panel - Activity Log
                GroupBox {
                    title: "Activity Log"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Material.elevation: 2

                    ColumnLayout {
                        anchors.fill: parent

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Clear Log"
                                onClicked: logModel.clear()
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: logView
                                model: ListModel {
                                    id: logModel
                                }

                                delegate: Rectangle {
                                    width: logView.width
                                    height: logText.implicitHeight + 10 * window.k
                                    color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)

                                    Text {
                                        id: logText
                                        text: model.message
                                        color: Material.foreground
                                        font.family: fontChosed
                                        font.pixelSize: 12
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 5
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tab 2: Subscription, Publishing, and MQTT Tree View
            RowLayout {
                spacing: 10 * window.k

                // Left panel - Subscription and Publishing
                ScrollView {
                    Layout.preferredWidth: 500 * window.k
                    Layout.fillHeight: true
                    contentWidth: 470 * window.k

                    ColumnLayout {
                        width: parent.width
                        spacing: 15 * window.k

                        // Subscription Settings
                        GroupBox {
                            title: "Subscription"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 200 * window.k
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: "Topic:" }
                                    TextField {
                                        id: subscribeTopicField
                                        text: "test/topic"
                                        placeholderText: "Enter topic to subscribe"
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: "QoS:" }
                                    SpinBox {
                                        id: subscribeQosSpinBox
                                        from: 0
                                        to: 2
                                        value: 0
                                        Layout.preferredWidth: 80 * window.k
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Subscribe"
                                        enabled: mqttClient.connected && subscribeTopicField.text.length > 0
                                        Material.background: Material.Blue
                                        onClicked: {
                                            mqttClient.subscribe(subscribeTopicField.text, subscribeQosSpinBox.value)
                                            addActiveSubscription(subscribeTopicField.text, subscribeQosSpinBox.value)
                                        }
                                    }

                                    Button {
                                        text: "Unsubscribe"
                                        enabled: mqttClient.connected && subscribeTopicField.text.length > 0
                                        Material.background: Material.Orange
                                        onClicked: {
                                            mqttClient.unsubscribe(subscribeTopicField.text)
                                            removeActiveSubscription(subscribeTopicField.text)
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        // Publishing Settings
                        GroupBox {
                            title: "Publishing"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 300 * window.k
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: "Topic:" }
                                    TextField {
                                        id: publishTopicField
                                        text: "test/topic"
                                        placeholderText: "Enter topic to publish"
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: "QoS:" }
                                    SpinBox {
                                        id: publishQosSpinBox
                                        from: 0
                                        to: 2
                                        value: 0
                                        Layout.preferredWidth: 80 * window.k
                                        Layout.fillWidth: true
                                    }

                                    CheckBox {
                                        id: retainCheckBox
                                        text: "Retain"
                                    }
                                }

                                Label { text: "Message:" }
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 150 * window.k
                                    TextArea {
                                        id: publishMessageArea
                                        placeholderText: "Enter message to publish..."
                                        wrapMode: TextArea.Wrap
                                    }
                                }

                                Button {
                                    text: "Publish"
                                    enabled: mqttClient.connected && publishTopicField.text.length > 0
                                    Material.background: Material.Purple
                                    Layout.fillWidth: true
                                    onClicked: {
                                        mqttClient.publish(publishTopicField.text, publishMessageArea.text, publishQosSpinBox.value, retainCheckBox.checked)
                                        addToMqttTree(publishTopicField.text, publishMessageArea.text, false)
                                        publishMessageArea.clear()
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right panel - MQTT Tree View
                GroupBox {
                    title: "MQTT Topic Tree"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Material.elevation: 2

                    ColumnLayout {
                        anchors.fill: parent

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: "Messages: " + mqttTreeModel.count
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: "Clear Tree"
                                onClicked: mqttTreeModel.clear()
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: mqttTreeView
                                model: ListModel {
                                    id: mqttTreeModel
                                }

                                delegate: Rectangle {
                                    width: mqttTreeView.width
                                    height: Math.max(topicText.implicitHeight + messageText.implicitHeight + 20 * window.k, 60 * window.k)
                                    color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                                    border.color: model.received === "true" ? Material.color(Material.Orange) : Material.accent
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8 * window.k
                                        spacing: 4 * window.k

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                id: topicText
                                                text: model.topic
                                                color: Material.accent
                                                font.family: fontChosed
                                                font.pixelSize: 12
                                                font.bold: true
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                text: model.timestamp
                                                color: Material.foreground
                                                font.pixelSize: 10
                                                opacity: 0.7
                                            }
                                        }

                                        Text {
                                            id: messageText
                                            text: model.message
                                            color: Material.foreground
                                            font.family: fontChosed
                                            font.pixelSize: 11
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            // Show message details in a popup
                                            messageDetailDialog.topic = model.topic
                                            messageDetailDialog.message = model.message
                                            messageDetailDialog.timestamp = model.timestamp

                                            // Parse history from JSON
                                            var history = []
                                            if (model.historyJson && model.historyJson !== "") {
                                                try {
                                                    history = JSON.parse(model.historyJson)
                                                } catch (e) {
                                                    history = []
                                                }
                                            }
                                            messageDetailDialog.history = history
                                            messageDetailDialog.open()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tab 3: Topic Management (New Tab)
            RowLayout {
                spacing: 10 * window.k

                // Left panel - Topic Presets and Quick Actions
                ScrollView {
                    Layout.preferredWidth: 500 * window.k
                    Layout.fillHeight: true
                    contentWidth: 470 * window.k

                    ColumnLayout {
                        width: parent.width
                        spacing: 15 * window.k

                        // Quick Subscription Presets
                        GroupBox {
                            title: "Quick Subscription Presets"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                Label {
                                    text: "Common MQTT Topic Patterns:"
                                    font.bold: true
                                    color: Material.accent
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "All Topics (#)"
                                        Material.background: Material.DeepPurple
                                        enabled: mqttClient.connected
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttClient.subscribe("#", 0)
                                            addActiveSubscription("#", 0)
                                            subscribeTopicField.text = "#"
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Subscribe to ALL topics (use with caution!)"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "All Sensors (+/sensors/+)"
                                        Material.background: Material.Teal
                                        enabled: mqttClient.connected
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttClient.subscribe("+/sensors/+", 0)
                                            addActiveSubscription("+/sensors/+", 0)
                                            subscribeTopicField.text = "+/sensors/+"
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Subscribe to all sensor topics from any device"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Home Automation (home/#)"
                                        Material.background: Material.Indigo
                                        enabled: mqttClient.connected
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttClient.subscribe("home/#", 0)
                                            addActiveSubscription("home/#", 0)
                                            subscribeTopicField.text = "home/#"
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Subscribe to all home automation topics"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Device Status (+/status)"
                                        Material.background: Material.Green
                                        enabled: mqttClient.connected
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttClient.subscribe("+/status", 0)
                                            addActiveSubscription("+/status", 0)
                                            subscribeTopicField.text = "+/status"
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Subscribe to status messages from all devices"
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "System Messages ($SYS/#)"
                                        Material.background: Material.Orange
                                        enabled: mqttClient.connected
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttClient.subscribe("$SYS/#", 0)
                                            addActiveSubscription("$SYS/#", 0)
                                            subscribeTopicField.text = "$SYS/#"
                                        }
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Subscribe to broker system messages"
                                    }
                                }
                            }
                        }

                        // Custom Topic Builder
                        GroupBox {
                            title: "Custom Topic Builder"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                Label {
                                    text: "Build custom topic patterns:"
                                    font.bold: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    TextField {
                                        id: customTopicField
                                        placeholderText: "device/+/sensors/#"
                                        Layout.fillWidth: true
                                    }
                                    Button {
                                        text: "Add to Field"
                                        enabled: customTopicField.text.length > 0
                                        onClicked: {
                                            subscribeTopicField.text = customTopicField.text
                                            customTopicField.clear()
                                        }
                                    }
                                }

                                Label {
                                    text: "Wildcards Help:"
                                    font.bold: true
                                    color: Material.accent
                                }

                                Text {
                                    text: "• '+' : Single level wildcard (device/+/temp)\n• '#' : Multi-level wildcard (sensors/#)\n• Mix them: home/+/sensors/#"
                                    color: Material.foreground
                                    font.family: fontChosed
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // Bulk Actions
                        GroupBox {
                            title: "Bulk Actions"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * window.k

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Unsubscribe All"
                                        Material.background: Material.Red
                                        enabled: mqttClient.connected && activeSubscriptionsModel.count > 0
                                        Layout.fillWidth: true
                                        onClicked: {
                                            for (var i = 0; i < activeSubscriptionsModel.count; i++) {
                                                var topic = activeSubscriptionsModel.get(i).topic
                                                mqttClient.unsubscribe(topic)
                                            }
                                            activeSubscriptionsModel.clear()
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Clear All Messages"
                                        Material.background: Material.DeepOrange
                                        Layout.fillWidth: true
                                        onClicked: {
                                            mqttTreeModel.clear()
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right panel - Active Subscriptions
                GroupBox {
                    title: "Active Subscriptions"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Material.elevation: 2

                    ColumnLayout {
                        anchors.fill: parent

                        RowLayout {
                            Layout.fillWidth: true

                            Label {
                                text: "Active: " + activeSubscriptionsModel.count
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: "Refresh Status"
                                enabled: mqttClient.connected
                                onClicked: {
                                    // This would ideally query the broker for active subscriptions
                                    // For now, we just log the current subscriptions
                                    for (var i = 0; i < activeSubscriptionsModel.count; i++) {
                                        var sub = activeSubscriptionsModel.get(i)
                                        mqttClient.logMessage("Active subscription: " + sub.topic + " (QoS " + sub.qos + ")")
                                    }
                                }
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: activeSubscriptionsView
                                model: ListModel {
                                    id: activeSubscriptionsModel
                                }

                                delegate: Rectangle {
                                    width: activeSubscriptionsView.width
                                    height: 60 * window.k
                                    color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                                    border.color: Material.accent
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10 * window.k
                                        spacing: 10 * window.k

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 5 * window.k

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: model.topic
                                                    color: Material.accent
                                                    font.family: fontChosed
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.Wrap
                                                }

                                                Rectangle {
                                                    width: 40 * window.k
                                                    height: 20 * window.k
                                                    color: model.qos === 0 ? Material.color(Material.Green) :
                                                           model.qos === 1 ? Material.color(Material.Orange) :
                                                           Material.color(Material.Red)
                                                    radius: 10 * window.k

                                                    Text {
                                                        text: "QoS " + model.qos
                                                        color: "white"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: "Subscribed at: " + model.timestamp
                                                    color: Material.foreground
                                                    font.pixelSize: 10
                                                    opacity: 0.7
                                                    Layout.fillWidth: true
                                                }

                                                Button {
                                                    text: "Unsubscribe"
                                                    Material.background: Material.Red
                                                    enabled: mqttClient.connected
                                                    font.pixelSize: 10
                                                    implicitHeight: 25 * window.k
                                                    implicitWidth: 80 * window.k
                                                    onClicked: {
                                                        mqttClient.unsubscribe(model.topic)
                                                        activeSubscriptionsModel.remove(index)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Visual indicator for wildcard topics
                                    Rectangle {
                                        width: 4 * window.k
                                        height: parent.height
                                        anchors.left: parent.left
                                        color: model.topic.includes('+') || model.topic.includes('#') ?
                                               Material.color(Material.Purple) : Material.color(Material.Blue)
                                    }
                                }

                                // Empty state
                                Rectangle {
                                    visible: activeSubscriptionsModel.count === 0
                                    width: activeSubscriptionsView.width
                                    height: 100 * window.k
                                    color: "transparent"
                                    border.color: Material.accent
                                    border.width: 1
                                    opacity: 0.5

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 10 * window.k

                                        Text {
                                            text: "📭"
                                            font.pixelSize: 32
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: "No active subscriptions"
                                            color: Material.foreground
                                            opacity: 0.7
                                            font.italic: true
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Message detail popup
    Popup {
        id: messageDetailDialog
        width: 650 * window.k
        height: 550 * window.k
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string topic: ""
        property string message: ""
        property string timestamp: ""
        property var history: []

        background: Rectangle {
            color: Material.backgroundColor
            border.color: Material.accent
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15 * window.k
            spacing: 12 * window.k

            // Header with title and close button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * window.k

                Label {
                    text: "Message Details"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    color: Material.foreground
                }

                Button {
                    text: "✕"
                    flat: true
                    onClicked: messageDetailDialog.close()
                    Layout.preferredWidth: 32 * window.k
                    Layout.preferredHeight: 32 * window.k
                }
            }

            // Topic section
            Label {
                text: "Topic:"
                font.bold: true
                color: Material.foreground
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60 * window.k
                color: Qt.darker(Material.backgroundColor, 1.3)
                border.color: Material.accent
                border.width: 1
                radius: 4

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4 * window.k
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        text: messageDetailDialog.topic
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        font.family: "Consolas, Monaco, monospace"
                        font.pixelSize: 15
                        font.bold: true
                        color: Material.accent
                        padding: 8 * window.k
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // Current message section
            Label {
                text: "Current Message (Last received: " + messageDetailDialog.timestamp + "):"
                font.bold: true
                color: Material.foreground
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 140 * window.k
                color: Qt.darker(Material.backgroundColor, 1.3)
                border.color: Material.accent
                border.width: 1
                radius: 4

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4 * window.k
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        text: messageDetailDialog.message
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        font.family: "Consolas, Monaco, monospace"
                        font.pixelSize: 11
                        color: Material.foreground
                        padding: 8 * window.k
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }

            // History header with clear button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * window.k

                Label {
                    text: "History (" + messageDetailDialog.history.length + " previous messages):"
                    font.bold: true
                    color: Material.foreground
                    Layout.fillWidth: true
                }

                Button {
                    text: "Clear History"
                    enabled: messageDetailDialog.history.length > 0
                    Material.background: Material.Red
                    font.pixelSize: 11
                    implicitHeight: 30 * window.k
                    onClicked: {
                        // Find the topic in the model and clear its history
                        for (var i = 0; i < mqttTreeModel.count; i++) {
                            if (mqttTreeModel.get(i).topic === messageDetailDialog.topic) {
                                mqttTreeModel.setProperty(i, "historyJson", "")
                                messageDetailDialog.history = []
                                break
                            }
                        }
                    }
                }
            }

            // History list or empty message
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // History ListView
                ScrollView {
                    anchors.fill: parent
                    visible: messageDetailDialog.history.length > 0
                    clip: true

                    ListView {
                        id: historyListView
                        model: messageDetailDialog.history
                        spacing: 4 * window.k

                        delegate: Rectangle {
                            width: historyListView.width
                            height: historyContent.implicitHeight + 16 * window.k
                            color: index % 2 === 0 ? Qt.darker(Material.backgroundColor, 1.4) : Qt.darker(Material.backgroundColor, 1.6)
                            border.color: Material.accent
                            border.width: 0.5
                            radius: 6

                            ColumnLayout {
                                id: historyContent
                                anchors.fill: parent
                                anchors.margins: 8 * window.k
                                spacing: 4 * window.k

                                // History item header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8 * window.k

                                    Rectangle {
                                        width: 24 * window.k
                                        height: 18 * window.k
                                        color: Material.accent
                                        radius: 3
                                        
                                        Label {
                                            text: "#" + (messageDetailDialog.history.length - index)
                                            font.bold: true
                                            font.pixelSize: 10
                                            color: "white"
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Label {
                                        text: modelData.timestamp || "Unknown time"
                                        font.pixelSize: 10
                                        opacity: 0.7
                                        color: Material.foreground
                                    }
                                }

                                // History message content
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(historyMessageText.implicitHeight + 10, 100 * window.k)
                                    clip: true

                                    TextArea {
                                        id: historyMessageText
                                        text: modelData.message || ""
                                        readOnly: true
                                        wrapMode: TextArea.Wrap
                                        selectByMouse: true
                                        font.family: "Consolas, Monaco, monospace"
                                        font.pixelSize: 10
                                        color: Material.foreground
                                        background: Rectangle {
                                            color: "transparent"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state message
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: messageDetailDialog.history.length === 0
                    spacing: 10 * window.k

                    Text {
                        text: "📝"
                        font.pixelSize: 48
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: "No previous messages"
                        color: Material.foreground
                        opacity: 0.6
                        font.italic: true
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: "Message history will appear here as new messages arrive"
                        color: Material.foreground
                        opacity: 0.4
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: 250 * window.k
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }


    // Topic Filter Dialog
    Popup {
        id: topicFilterDialog
        width: 500 * window.k
        height: 400 * window.k
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Rectangle {
            anchors.fill: parent
            color: Material.backgroundColor
            border.color: Material.accent
            border.width: 1
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15 * window.k
                spacing: 10 * window.k

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "MQTT Topic Filter Guide"
                        font.bold: true
                        font.pixelSize: 16
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "✕"
                        flat: true
                        onClicked: topicFilterDialog.close()
                        Layout.preferredWidth: 30 * window.k
                        Layout.preferredHeight: 30 * window.k
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        width: parent.parent.width
                        spacing: 15 * window.k

                        GroupBox {
                            title: "Single Level Wildcard (+)"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8 * window.k

                                Text {
                                    text: "The '+' wildcard matches exactly one topic level."
                                    color: Material.foreground
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    text: "Examples:\n• home/+/temperature → matches home/kitchen/temperature, home/bedroom/temperature\n• +/sensors/+ → matches device1/sensors/temp, device2/sensors/humidity\n• sport/+/player1 → matches sport/tennis/player1, sport/football/player1"
                                    color: Material.foreground
                                    font.family: fontChosed
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        GroupBox {
                            title: "Multi Level Wildcard (#)"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8 * window.k

                                Text {
                                    text: "The '#' wildcard matches zero or more topic levels and MUST be the last character."
                                    color: Material.foreground
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    text: "Examples:\n• home/# → matches home/kitchen/temp, home/bedroom/light/status\n• sensors/# → matches sensors/temp, sensors/humidity/room1\n• # → matches ALL topics (use with caution!)\n• sport/tennis/# → matches sport/tennis/player1, sport/tennis/score/set1"
                                    color: Material.foreground
                                    font.family: fontChosed
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        GroupBox {
                            title: "Combined Examples"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8 * window.k

                                Text {
                                    text: "Complex patterns using both wildcards:"
                                    color: Material.foreground
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }

                                Text {
                                    text: "• +/+/temperature → any device, any room, temperature\n• home/+/sensors/# → home automation sensor data\n• device/+/status → status from any device\n• $SYS/broker/+/# → broker system messages"
                                    color: Material.foreground
                                    font.family: fontChosed
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        GroupBox {
                            title: "Important Notes"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8 * window.k

                                Text {
                                    text: "⚠️ Performance Considerations:"
                                    color: Material.color(Material.Orange)
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "• '#' subscribes to ALL topics - can generate huge traffic!\n• Use specific patterns when possible\n• Monitor message count in high-traffic scenarios\n• Consider QoS levels for important subscriptions"
                                    color: Material.foreground
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Add help button to main interface
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
        onClicked: topicFilterDialog.open()
        ToolTip.visible: hovered
        ToolTip.text: "Topic Wildcards Help"
    }
}
