pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"

RowLayout {
    id: root

    property var mqttClient
    property var appController
    property ListModel logModel
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool autoScroll: autoScrollCheckbox.checked
    property int maxLogEntries: maxEntriesSpinBox.value

    spacing: 10 * scaleFactor

    // File dialogs
    FileDialog {
        id: caCertDialog
        title: "Select CA Certificate"
        nameFilters: ["Certificate Files (*.crt *.pem *.cert)", "All Files (*)"]
        folder: root.appController.localFileToUrl(root.appController.getDocumentsPath())
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            root.caCertField.text = filePath
            root.mqttClient.caCertPath = filePath
        }
    }

    FileDialog {
        id: clientCertDialog
        title: "Select Client Certificate"
        nameFilters: ["Certificate Files (*.crt *.pem *.cert)", "All Files (*)"]
        folder: root.appController.localFileToUrl(root.appController.getDocumentsPath())
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            root.clientCertField.text = filePath
            root.mqttClient.clientCertPath = filePath
        }
    }

    FileDialog {
        id: clientKeyDialog
        title: "Select Client Private Key"
        nameFilters: ["Key Files (*.key *.pem)", "All Files (*)"]
        folder: root.appController.localFileToUrl(root.appController.getDocumentsPath())
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            root.clientKeyField.text = filePath
            root.mqttClient.clientKeyPath = filePath
        }
    }

    // Left panel - Connection and TLS Settings
    ScrollView {
        Layout.preferredWidth: 400 * root.scaleFactor
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width - 10
            spacing: 15 * root.scaleFactor

            // Connection Settings
            GroupBox {
                title: "Connection Settings"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    GridLayout {
                        columns: 2
                        Layout.fillWidth: true

                        Label { text: "Host:" }
                        TextField {
                            id: hostField
                            text: root.mqttClient ? root.mqttClient.hostName : ""
                            placeholderText: "localhost"
                            Layout.fillWidth: true
                            onTextChanged: if (root.mqttClient) root.mqttClient.hostName = text
                        }

                        Label { text: "Port:" }
                        SpinBox {
                            id: portSpinBox
                            from: 1
                            to: 65535
                            value: root.mqttClient ? root.mqttClient.port : 1883
                            onValueChanged: if (root.mqttClient) root.mqttClient.port = value
                            editable: true
                            Layout.fillWidth: true
                        }

                        Label { text: "Client ID:" }
                        TextField {
                            id: clientIdField
                            text: root.mqttClient ? root.mqttClient.clientId : ""
                            placeholderText: "Auto-generated if empty"
                            Layout.fillWidth: true
                            onTextChanged: if (root.mqttClient) root.mqttClient.clientId = text
                        }

                        Label { text: "Username:" }
                        TextField {
                            id: usernameField
                            text: root.mqttClient ? root.mqttClient.username : ""
                            Layout.fillWidth: true
                            onTextChanged: if (root.mqttClient) root.mqttClient.username = text
                        }

                        Label { text: "Password:" }
                        TextField {
                            id: passwordField
                            text: root.mqttClient ? root.mqttClient.password : ""
                            echoMode: TextInput.Password
                            Layout.fillWidth: true
                            onTextChanged: if (root.mqttClient) root.mqttClient.password = text
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: "Connect"
                            enabled: root.mqttClient && !root.mqttClient.connected
                            Material.background: Material.Green
                            onClicked: root.mqttClient.connectToHost()
                        }

                        Button {
                            text: "Disconnect"
                            enabled: root.mqttClient && (root.mqttClient.connected || root.mqttClient.connectionState === "Connecting")
                            Material.background: Material.Red
                            onClicked: root.mqttClient.disconnectFromHost()
                        }

                        Item { Layout.fillWidth: true }

                        Label {
                            text: root.mqttClient ? root.mqttClient.connectionState : "Unknown"
                            font.bold: true
                            color: root.mqttClient && root.mqttClient.connected ? Material.color(Material.Green) :
                                   root.mqttClient && root.mqttClient.connectionState === "Connecting" ? Material.color(Material.Orange) :
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
                    FilePickerRow {
                        id: caCertRow
                        label: "CA Certificate:"
                        text: root.mqttClient ? root.mqttClient.caCertPath : ""
                        placeholderText: "Path to CA certificate"
                        scaleFactor: root.scaleFactor
                        onFieldTextChanged: function(newText) {
                            if (root.mqttClient) root.mqttClient.caCertPath = newText
                        }
                        onBrowseClicked: caCertDialog.open()
                    }

                    // Client Certificate
                    FilePickerRow {
                        id: clientCertRow
                        label: "Client Certificate:"
                        text: root.mqttClient ? root.mqttClient.clientCertPath : ""
                        placeholderText: "Path to client certificate"
                        scaleFactor: root.scaleFactor
                        onFieldTextChanged: function(newText) {
                            if (root.mqttClient) root.mqttClient.clientCertPath = newText
                        }
                        onBrowseClicked: clientCertDialog.open()
                    }

                    // Client Key
                    FilePickerRow {
                        id: clientKeyRow
                        label: "Client Key:"
                        text: root.mqttClient ? root.mqttClient.clientKeyPath : ""
                        placeholderText: "Path to client private key"
                        scaleFactor: root.scaleFactor
                        onFieldTextChanged: function(newText) {
                            if (root.mqttClient) root.mqttClient.clientKeyPath = newText
                        }
                        onBrowseClicked: clientKeyDialog.open()
                    }
                }
            }

            // Log Settings
            GroupBox {
                title: "Log Settings"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    GridLayout {
                        columns: 2
                        Layout.fillWidth: true

                        Label { text: "Category:" }
                        ComboBox {
                            id: categoryFilter
                            model: ["All", "connection", "subscription", "publish", "receive", "tls", "error", "system", "queue"]
                            Layout.fillWidth: true
                        }

                        Label { text: "Level:" }
                        ComboBox {
                            id: levelFilter
                            model: ["All", "info", "warning", "error", "debug"]
                            Layout.fillWidth: true
                        }

                        Label { text: "Max entries:" }
                        SpinBox {
                            id: maxEntriesSpinBox
                            from: 50
                            to: 10000
                            stepSize: 50
                            value: 500
                            editable: true
                            Layout.fillWidth: true
                        }
                    }

                    CheckBox {
                        id: verboseToggle
                        text: "Verbose"
                    }

                    CheckBox {
                        id: autoScrollCheckbox
                        text: "Auto-scroll"
                        checked: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: "Export"
                            Layout.fillWidth: true
                            onClicked: exportLogDialog.open()
                            enabled: root.logModel.count > 0
                        }

                        Button {
                            text: "Clear Log"
                            Layout.fillWidth: true
                            onClicked: root.logModel.clear()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Export file dialog
    FileDialog {
        id: exportLogDialog
        title: "Export Logs"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV Files (*.csv)", "JSON Files (*.json)", "All Files (*)"]
        folder: root.appController.localFileToUrl(root.appController.getDocumentsPath())
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            var isJson = filePath.endsWith(".json")
            var content = ""

            if (isJson) {
                var arr = []
                for (var i = 0; i < root.logModel.count; i++) {
                    var item = root.logModel.get(i)
                    arr.push({
                        timestamp: item.timestamp || "",
                        category: item.category || "",
                        level: item.level || "",
                        message: item.message || "",
                        topic: item.topic || "",
                        payload: item.payload || "",
                        direction: item.direction || "",
                        qos: item.qos !== undefined ? item.qos : -1
                    })
                }
                content = JSON.stringify(arr, null, 2)
            } else {
                content = "timestamp,category,level,direction,topic,qos,message\n"
                for (var j = 0; j < root.logModel.count; j++) {
                    var row = root.logModel.get(j)
                    var msg = (row.message || "").replace(/"/g, '""')
                    var tp = (row.topic || "").replace(/"/g, '""')
                    content += '"' + (row.timestamp || "") + '",'
                    content += '"' + (row.category || "") + '",'
                    content += '"' + (row.level || "") + '",'
                    content += '"' + (row.direction || "") + '",'
                    content += '"' + tp + '",'
                    content += (row.qos !== undefined ? row.qos : -1) + ','
                    content += '"' + msg + '"\n'
                }
            }

            root.appController.saveTextToFile(filePath, content)
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

            ListView {
                id: logView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.logModel
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                // Auto-scroll to bottom on new entries
                onCountChanged: {
                    if (autoScrollCheckbox.checked && (atYEnd || contentHeight <= height)) {
                        Qt.callLater(function() { logView.positionViewAtEnd() })
                    }
                }

                delegate: LogDelegate {
                    required property var model
                    required property int index

                    timestamp: model.timestamp || ""
                    category: model.category || ""
                    level: model.level || ""
                    message: model.message || ""
                    topic: model.topic || ""
                    payload: model.payload || ""
                    direction: model.direction || ""
                    qos: model.qos !== undefined ? model.qos : -1
                    itemIndex: index
                    verbose: verboseToggle.checked
                    scaleFactor: root.scaleFactor
                    fontFamily: root.fontFamily

                    visible: {
                        var catOk = categoryFilter.currentText === "All" || (model.category || "") === categoryFilter.currentText
                        var lvlOk = levelFilter.currentText === "All" || (model.level || "") === levelFilter.currentText
                        return catOk && lvlOk
                    }
                    height: visible ? implicitHeight : 0
                }
            }
        }
    }

    // Expose caCertField, clientCertField, clientKeyField for external access
    property alias caCertField: caCertRow
    property alias clientCertField: clientCertRow
    property alias clientKeyField: clientKeyRow
    property alias logView: logView
}
