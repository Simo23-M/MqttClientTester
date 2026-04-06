pragma ComponentBehavior: Bound
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"
import "../utils/PayloadFormatter.js" as Formatter

RowLayout {
    id: root

    property var mqttClient
    property var mqttTreeModel
    property var appController
    property var commandQueue
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

    FileDialog {
        id: triggerScriptBrowseDialog
        title: "Select Script File"
        nameFilters: Qt.platform.os === "windows"
            ? ["PowerShell Scripts (*.ps1)", "All Files (*)"]
            : ["Shell Scripts (*.sh)", "All Files (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: triggerScriptPathField.text = root.appController
            ? root.appController.urlToLocalFile(file)
            : file.toString().replace("file://", "")
    }

    FileDialog {
        id: triggerLoadDialog
        title: "Load Triggers File"
        nameFilters: ["JSON Files (*.json)", "All Files (*)"]
        fileMode: FileDialog.OpenFile
        folder: root.appController ? root.appController.localFileToUrl(root.appController.getDocumentsPath()) : ""
        onAccepted: {
            if (root.commandQueue)
                root.commandQueue.loadTriggersFromFile(
                    root.appController.urlToLocalFile(file))
        }
    }

    FileDialog {
        id: triggerSaveDialog
        title: "Save Triggers File"
        nameFilters: ["JSON Files (*.json)", "All Files (*)"]
        fileMode: FileDialog.SaveFile
        folder: root.appController ? root.appController.localFileToUrl(root.appController.getDocumentsPath()) : ""
        onAccepted: {
            if (root.commandQueue)
                root.commandQueue.saveTriggersToFile(
                    root.appController.urlToLocalFile(file))
        }
    }

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

            // Script Triggers
            GroupBox {
                title: "Script Triggers (" + (root.commandQueue ? root.commandQueue.triggerCount : 0) + ")"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8 * root.scaleFactor

                    // Load / Save buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.scaleFactor

                        Button {
                            text: "Load"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            onClicked: triggerLoadDialog.open()
                        }

                        Button {
                            text: "Save"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            enabled: root.commandQueue && root.commandQueue.triggerCount > 0
                            onClicked: triggerSaveDialog.open()
                        }
                    }

                    // Trigger list
                    ListView {
                        id: triggerListView
                        Layout.fillWidth: true
                        implicitHeight: Math.min(contentHeight, 200 * root.scaleFactor)
                        clip: true
                        visible: root.commandQueue && root.commandQueue.triggerCount > 0

                        model: root.commandQueue ? root.commandQueue.getTriggers() : []

                        delegate: Rectangle {
                            id: triggerDelegate
                            required property var modelData
                            required property int index

                            width: triggerListView.width
                            height: 56 * root.scaleFactor
                            color: triggerDelegate.index % 2 === 0
                                   ? Material.background : Qt.darker(Material.background, 1.1)
                            border.color: triggerDelegate.modelData.enabled
                                          ? Material.color(Material.Orange) : Material.accent
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 6 * root.scaleFactor
                                spacing: 6 * root.scaleFactor

                                Switch {
                                    checked: triggerDelegate.modelData.enabled
                                    implicitWidth: 44 * root.scaleFactor
                                    onToggled: root.commandQueue.setTriggerEnabled(
                                        triggerDelegate.modelData.id, checked)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2 * root.scaleFactor

                                    Text {
                                        text: triggerDelegate.modelData.name
                                        color: Material.accent
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        spacing: 6 * root.scaleFactor

                                        Rectangle {
                                            radius: 3
                                            color: triggerDelegate.modelData.eventType === "received"
                                                   ? Material.color(Material.Blue) : Material.color(Material.Green)
                                            implicitWidth: eventLabel.implicitWidth + 8 * root.scaleFactor
                                            implicitHeight: eventLabel.implicitHeight + 4 * root.scaleFactor
                                            Text {
                                                id: eventLabel
                                                anchors.centerIn: parent
                                                text: triggerDelegate.modelData.eventType
                                                color: "white"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: triggerDelegate.modelData.topicPattern
                                            color: Material.foreground
                                            font.pixelSize: 10
                                            opacity: 0.8
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: 4 * root.scaleFactor

                                    Button {
                                        text: "▶"
                                        font.pixelSize: 10
                                        implicitWidth: 32 * root.scaleFactor
                                        implicitHeight: 24 * root.scaleFactor
                                        Material.background: Material.Orange
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Execute now"
                                        onClicked: root.commandQueue.executeScriptNow(
                                            triggerDelegate.modelData.scriptPath,
                                            triggerDelegate.modelData.scriptArgs)
                                    }

                                    Button {
                                        text: "✕"
                                        font.pixelSize: 10
                                        implicitWidth: 32 * root.scaleFactor
                                        implicitHeight: 24 * root.scaleFactor
                                        Material.background: Material.Red
                                        onClicked: {
                                            root.commandQueue.removeTrigger(triggerDelegate.modelData.id)
                                            triggerListView.model = root.commandQueue.getTriggers()
                                        }
                                    }
                                }
                            }
                        }

                        Connections {
                            target: root.commandQueue
                            function onTriggersChanged() {
                                triggerListView.model = root.commandQueue
                                    ? root.commandQueue.getTriggers() : []
                            }
                        }
                    }

                    // Add trigger form
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.scaleFactor

                        TextField {
                            id: triggerNameField
                            placeholderText: "Trigger name (optional)"
                            Layout.fillWidth: true
                        }

                        TextField {
                            id: triggerPatternField
                            placeholderText: "Topic pattern (e.g. sensor/+/temp)"
                            Layout.fillWidth: true
                        }

                        ComboBox {
                            id: triggerEventCombo
                            model: ["received", "published"]
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6 * root.scaleFactor

                            TextField {
                                id: triggerScriptPathField
                                placeholderText: "Script path..."
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Browse"
                                font.pixelSize: 11
                                implicitHeight: 36 * root.scaleFactor
                                onClicked: triggerScriptBrowseDialog.open()
                            }
                        }

                        TextField {
                            id: triggerScriptArgsField
                            placeholderText: "Arguments (optional)"
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Add Trigger"
                            Material.background: Material.Orange
                            Layout.fillWidth: true
                            enabled: triggerPatternField.text.trim() !== ""
                                     && triggerScriptPathField.text.trim() !== ""
                            onClicked: {
                                root.commandQueue.addTrigger(
                                    triggerNameField.text.trim(),
                                    triggerPatternField.text.trim(),
                                    triggerEventCombo.currentText,
                                    triggerScriptPathField.text.trim(),
                                    triggerScriptArgsField.text.trim()
                                )
                                triggerNameField.clear()
                                triggerPatternField.clear()
                                triggerScriptPathField.clear()
                                triggerScriptArgsField.clear()
                            }
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

                delegate: Item {
                        id: msgWrapper
                        required property var model
                        required property int index

                        width: mqttTreeView.width
                        height: msgDelegate.height

                        MessageDelegate {
                            id: msgDelegate
                            width: parent.width
                            topic: msgWrapper.model.topic
                            segment: msgWrapper.model.segment || ""
                            message: msgWrapper.model.message
                            timestamp: msgWrapper.model.timestamp
                            received: msgWrapper.model.received === true || msgWrapper.model.received === "true"
                            historyJson: msgWrapper.model.historyJson || ""
                            itemIndex: msgWrapper.index
                            scaleFactor: root.scaleFactor
                            fontFamily: root.fontFamily
                            mqttConnected: root.mqttClient && root.mqttClient.connected
                            level: msgWrapper.model.level || 0
                            expanded: msgWrapper.model.expanded === true
                            hasChildren: msgWrapper.model.hasChildren === true
                            hasMessage: msgWrapper.model.hasMessage === true
                            subtopicCount: msgWrapper.model.subtopicCount || 0
                            updateTick: msgWrapper.model.updateTick || 0

                            onToggleExpand: {
                                root.mqttTreeModel.toggleExpanded(msgWrapper.index)
                            }

                            onClicked: {
                                if (msgWrapper.model.hasMessage) {
                                    var history = []
                                    if (historyJson && historyJson !== "") {
                                        try {
                                            history = JSON.parse(historyJson)
                                        } catch (e) {
                                            history = []
                                        }
                                    }
                                    root.messageClicked(msgWrapper.model.topic, msgWrapper.model.message, msgWrapper.model.timestamp, history)
                                }
                            }

                            onDeleteRetainedClicked: function(topicToDelete) {
                                root.deleteRetainedRequested(topicToDelete)
                            }

                            onUseAsPublishTopic: function(t) {
                                root.publishTopicField.text = t
                            }

                            onUseAsSubscribeTopic: function(t) {
                                root.subscribeTopicField.text = t
                            }
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
