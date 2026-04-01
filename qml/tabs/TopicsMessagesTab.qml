import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../components"
import "../dialogs"
import "../utils/PayloadFormatter.js" as Formatter

RowLayout {
    id: root

    property var mqttClient
    property var mqttTreeModel
    property ListModel activeSubscriptionsModel
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    signal subscribeRequested(string topic, int qos)
    signal unsubscribeRequested(string topic)
    signal publishRequested(string topic, string message, int qos, bool retain)
    signal messageClicked(string topic, string message, string timestamp, var history)
    signal deleteRetainedRequested(string topic)
    signal useAsPublishTopic(string topic)
    signal useAsSubscribeTopic(string topic)
    signal treeClearRequested()

    spacing: 10 * scaleFactor

    // Left panel - Subscription and Publishing
    ScrollView {
        Layout.preferredWidth: 500 * root.scaleFactor
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width - 10
            spacing: 15 * root.scaleFactor

            // Subscription Settings
            GroupBox {
                title: "Subscription"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200 * root.scaleFactor
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

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
                            Layout.preferredWidth: 80 * root.scaleFactor
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Subscribe"
                            enabled: root.mqttClient && root.mqttClient.connected && subscribeTopicField.text.length > 0
                            Material.background: Material.Blue
                            onClicked: root.subscribeRequested(subscribeTopicField.text, subscribeQosSpinBox.value)
                        }

                        Button {
                            text: "Unsubscribe"
                            enabled: root.mqttClient && root.mqttClient.connected && subscribeTopicField.text.length > 0
                            Material.background: Material.Orange
                            onClicked: root.unsubscribeRequested(subscribeTopicField.text)
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
                Layout.minimumHeight: 300 * root.scaleFactor
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

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
                            Layout.preferredWidth: 80 * root.scaleFactor
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            id: retainCheckBox
                            text: "Retain"
                        }
                    }

                    Label { text: "Message:" }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.scaleFactor

                        ComboBox {
                            id: formatSelector
                            model: ["Raw", "JSON", "XML"]
                            Layout.preferredWidth: 100 * root.scaleFactor
                        }

                        Button {
                            text: "Beautify"
                            Material.background: Material.Teal
                            enabled: formatSelector.currentText !== "Raw" && publishMessageArea.text.length > 0
                            onClicked: {
                                var fmt = formatSelector.currentText.toLowerCase()
                                var result = Formatter.beautify(publishMessageArea.text, fmt)
                                if (result && typeof result === "object" && result.error) {
                                    validationLabel.text = "Error: " + result.error
                                    validationLabel.color = Material.color(Material.Red)
                                } else {
                                    publishMessageArea.text = result
                                    validationLabel.text = "Formatted"
                                    validationLabel.color = Material.color(Material.Green)
                                }
                            }
                        }

                        Label {
                            id: validationLabel
                            text: ""
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150 * root.scaleFactor
                        TextArea {
                            id: publishMessageArea
                            placeholderText: "Enter message to publish..."
                            wrapMode: TextArea.Wrap
                            onTextChanged: {
                                if (formatSelector.currentText === "JSON" && text.length > 0) {
                                    var result = Formatter.validateJson(text)
                                    validationLabel.text = result.message
                                    validationLabel.color = result.valid ? Material.color(Material.Green) : Material.color(Material.Red)
                                } else if (formatSelector.currentText === "XML" && text.length > 0) {
                                    var xmlResult = Formatter.validateXml(text)
                                    validationLabel.text = xmlResult.message
                                    validationLabel.color = xmlResult.valid ? Material.color(Material.Green) : Material.color(Material.Red)
                                } else {
                                    validationLabel.text = ""
                                }
                            }
                        }
                    }

                    Button {
                        text: "Publish"
                        enabled: root.mqttClient && root.mqttClient.connected && publishTopicField.text.length > 0
                        Material.background: Material.Purple
                        Layout.fillWidth: true
                        onClicked: root.publishRequested(publishTopicField.text, publishMessageArea.text, publishQosSpinBox.value, retainCheckBox.checked)
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
                    text: "Messages: " + root.mqttTreeModel.count
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Clear Tree"
                    onClicked: root.treeClearRequested()
                }
            }

            ListView {
                id: mqttTreeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.mqttTreeModel
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: MessageDelegate {
                        topic: model.topic
                        segment: model.segment || ""
                        message: model.message
                        timestamp: model.timestamp
                        received: model.received === true || model.received === "true"
                        historyJson: model.historyJson || ""
                        itemIndex: index
                        scaleFactor: root.scaleFactor
                        fontFamily: root.fontFamily
                        mqttConnected: root.mqttClient && root.mqttClient.connected
                        level: model.level || 0
                        expanded: model.expanded === true
                        hasChildren: model.hasChildren === true
                        hasMessage: model.hasMessage === true
                        subtopicCount: model.subtopicCount || 0
                        updateTick: model.updateTick || 0

                        onToggleExpand: {
                            root.mqttTreeModel.toggleExpanded(index)
                        }

                        onClicked: {
                            if (model.hasMessage) {
                                var history = []
                                if (historyJson && historyJson !== "") {
                                    try {
                                        history = JSON.parse(historyJson)
                                    } catch (e) {
                                        history = []
                                    }
                                }
                                root.messageClicked(model.topic, model.message, model.timestamp, history)
                            }
                        }

                        onDeleteRetainedClicked: function(topicToDelete) {
                            root.deleteRetainedRequested(topicToDelete)
                        }

                        onUseAsPublishTopic: function(topic) {
                            root.publishTopicField.text = topic
                        }

                        onUseAsSubscribeTopic: function(topic) {
                            root.subscribeTopicField.text = topic
                        }
                }
            }
        }
    }

    // Expose subscribe topic field for external access
    property alias subscribeTopicField: subscribeTopicField
    property alias publishTopicField: publishTopicField
    property alias publishMessageArea: publishMessageArea
}
