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

    width: 1200 * k
    height: 800 * k
    visible: true
    title: qsTr("MQTT TLS Client")

    Material.theme: Material.Dark
    Material.primary: Material.Blue
    Material.accent: Material.Cyan

    property alias mqttClient: mqttClient

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
            addToMqttTree(topic, message)
        }
    }

    // Function to add messages to MQTT tree
    function addToMqttTree(topic, message) {
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
                "historyJson": ""
            })
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
        anchors.margins: 10 * k
        spacing: 10 * k

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
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // Tab 1: Broker Settings + Logs
            RowLayout {
                spacing: 10 * k

                // Left panel - Connection and TLS Settings
                ScrollView {
                    Layout.preferredWidth: 400 * k
                    Layout.fillHeight: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 15 * k

                        // Connection Settings
                        GroupBox {
                            title: "Connection Settings"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * k

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
                                        enabled: mqttClient.connected
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
                                        Layout.minimumWidth: 100 * k
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
                                        Layout.minimumWidth: 100 * k
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
                                        Layout.minimumWidth: 100 * k
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
                                    height: logText.implicitHeight + 10 * k
                                    color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)

                                    Text {
                                        id: logText
                                        text: model.message
                                        color: Material.foreground
                                        font.family: "Consolas, Monaco, monospace"
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
                spacing: 10 * k

                // Left panel - Subscription and Publishing
                ScrollView {
                    Layout.preferredWidth: 400 * k
                    Layout.fillHeight: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 15 * k

                        // Subscription Settings
                        GroupBox {
                            title: "Subscription"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * k

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
                                        Layout.preferredWidth: 80 * k
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Button {
                                        text: "Subscribe"
                                        enabled: mqttClient.connected && subscribeTopicField.text.length > 0
                                        Material.background: Material.Blue
                                        onClicked: mqttClient.subscribe(subscribeTopicField.text, subscribeQosSpinBox.value)
                                    }

                                    Button {
                                        text: "Unsubscribe"
                                        enabled: mqttClient.connected && subscribeTopicField.text.length > 0
                                        Material.background: Material.Orange
                                        onClicked: mqttClient.unsubscribe(subscribeTopicField.text)
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }

                        // Publishing Settings
                        GroupBox {
                            title: "Publishing"
                            Layout.fillWidth: true
                            Material.elevation: 2

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10 * k

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
                                        Layout.preferredWidth: 80 * k
                                    }

                                    Item { Layout.fillWidth: true }

                                    CheckBox {
                                        id: retainCheckBox
                                        text: "Retain"
                                    }
                                }

                                Label { text: "Message:" }
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 150 * k
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
                                    height: Math.max(topicText.implicitHeight + messageText.implicitHeight + 20 * k, 60 * k)
                                    color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                                    border.color: Material.accent
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8 * k
                                        spacing: 4 * k

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                id: topicText
                                                text: model.topic
                                                color: Material.accent
                                                font.family: "Consolas, Monaco, monospace"
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
                                            font.family: "Consolas, Monaco, monospace"
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
        }
    }

    // Message detail popup
    Popup {
        id: messageDetailDialog
        width: 600 * k
        height: 500 * k
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string topic: ""
        property string message: ""
        property string timestamp: ""
        property var history: []

        Rectangle {
            anchors.fill: parent
            color: Material.backgroundColor
            border.color: Material.accent
            border.width: 1
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15 * k
                spacing: 10 * k

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "Message Details"
                        font.bold: true
                        font.pixelSize: 16
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "✕"
                        flat: true
                        onClicked: messageDetailDialog.close()
                        Layout.preferredWidth: 30 * k
                        Layout.preferredHeight: 30 * k
                    }
                }

                Label {
                    text: "Topic:"
                    font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50 * k

                    TextArea {
                        text: messageDetailDialog.topic
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        font.family: "Consolas, Monaco, monospace"
                        background: Rectangle {
                            color: Qt.darker(Material.backgroundColor, 1.2)
                            border.color: Material.accent
                            border.width: 1
                            radius: 4
                        }
                    }
                }

                Label {
                    text: "Current Message (Last received: " + messageDetailDialog.timestamp + "):"
                    font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120 * k

                    TextArea {
                        text: messageDetailDialog.message
                        readOnly: true
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        font.family: "Consolas, Monaco, monospace"
                        background: Rectangle {
                            color: Qt.darker(Material.backgroundColor, 1.2)
                            border.color: Material.accent
                            border.width: 1
                            radius: 4
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "History (" + messageDetailDialog.history.length + " previous messages):"
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Clear History"
                        enabled: messageDetailDialog.history.length > 0
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

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: messageDetailDialog.history.length > 0

                    ListView {
                        id: historyListView
                        model: messageDetailDialog.history

                        delegate: Rectangle {
                            width: historyListView.width
                            height: Math.max(historyMessageText.implicitHeight + 20 * k, 50 * k)
                            color: index % 2 === 0 ? Qt.darker(Material.backgroundColor, 1.3) : Qt.darker(Material.backgroundColor, 1.5)
                            border.color: Material.accent
                            border.width: 0.5
                            radius: 4

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8 * k
                                spacing: 4 * k

                                RowLayout {
                                    Layout.fillWidth: true

                                    Label {
                                        text: "#" + (messageDetailDialog.history.length - index)
                                        font.bold: true
                                        color: Material.accent
                                        Layout.minimumWidth: 30 * k
                                    }

                                    Item { Layout.fillWidth: true }

                                    Label {
                                        text: modelData.timestamp
                                        font.pixelSize: 10
                                        opacity: 0.7
                                        color: Material.foreground
                                    }
                                }

                                Text {
                                    id: historyMessageText
                                    text: modelData.message
                                    color: Material.foreground
                                    font.family: "Consolas, Monaco, monospace"
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 5
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Label {
                    text: "No history available"
                    visible: messageDetailDialog.history.length === 0
                    opacity: 0.7
                    font.italic: true
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}
