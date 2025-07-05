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

    // Main content
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10 * k
        spacing: 10 * k

        // Left panel - Controls
        ScrollView {
            // Layout.preferredWidth: 400 * k
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
                            Button {
                                text: "Subscribe"
                                enabled: mqttClient.connected && subscribeTopicField.text.length > 0
                                Material.background: Material.Blue
                                onClicked: mqttClient.subscribe(subscribeTopicField.text, 0)
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
                        
                        Label { text: "Message:" }
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100 * k
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
                                mqttClient.publish(publishTopicField.text, publishMessageArea.text, 0, false)
                                publishMessageArea.clear()
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Right panel - Log
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
}
