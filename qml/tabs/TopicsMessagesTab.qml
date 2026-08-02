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
                            selected: msgWrapper.ListView.isCurrentItem

                            onToggleExpand: {
                                mqttTreeView.currentIndex = msgWrapper.index
                                root.mqttTreeModel.toggleExpanded(msgWrapper.index)
                            }

                            onClicked: {
                                mqttTreeView.currentIndex = msgWrapper.index
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

    // Right panel - Last Message Detail
    GroupBox {
        id: lastMessagePanel
        title: "Message Details"
        Layout.preferredWidth: 300 * root.scaleFactor
        Layout.fillHeight: true
        Material.elevation: 2

        readonly property bool liveHasMessage: mqttTreeView.currentItem
            ? (mqttTreeView.currentItem.model.hasMessage === true) : false
        readonly property string liveTopic: mqttTreeView.currentItem
            ? (mqttTreeView.currentItem.model.topic ?? "") : ""
        readonly property string liveMessage: mqttTreeView.currentItem
            ? (mqttTreeView.currentItem.model.message ?? "") : ""
        readonly property string liveTimestamp: mqttTreeView.currentItem
            ? (mqttTreeView.currentItem.model.timestamp ?? "") : ""
        readonly property string liveHistoryJson: mqttTreeView.currentItem
            ? (mqttTreeView.currentItem.model.historyJson ?? "") : ""
        readonly property string detectedFormat: liveMessage.length > 0
            ? Formatter.detectFormat(liveMessage) : "raw"
        property bool showFormatted: true
        readonly property string displayMessage: {
            if (!lastMessagePanel.liveMessage) return ""
            if (lastMessagePanel.showFormatted && lastMessagePanel.detectedFormat !== "raw") {
                var r = Formatter.beautify(lastMessagePanel.liveMessage, lastMessagePanel.detectedFormat)
                if (typeof r === "object" && r.error) return lastMessagePanel.liveMessage
                return r
            }
            return lastMessagePanel.liveMessage
        }
        readonly property var liveHistory: {
            var json = lastMessagePanel.liveHistoryJson
            if (!json || json === "") return []
            try { return JSON.parse(json) } catch(e) { return [] }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8 * root.scaleFactor

            // Empty state — no topic selected or no message
            EmptyStateView {
                visible: !lastMessagePanel.liveHasMessage
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "📨"
                title: "No message"
                subtitle: "Click a topic in the tree to view its last message"
                scaleFactor: root.scaleFactor
            }

            // Content
            ColumnLayout {
                visible: lastMessagePanel.liveHasMessage
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6 * root.scaleFactor

                // Topic
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36 * root.scaleFactor
                    color: Qt.darker(Material.backgroundColor, 1.3)
                    border.color: Material.accent
                    border.width: 1
                    radius: 4

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 4 * root.scaleFactor
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.policy: ScrollBar.Never

                        TextArea {
                            text: lastMessagePanel.liveTopic
                            readOnly: true
                            wrapMode: TextArea.NoWrap
                            selectByMouse: true
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Material.accent
                            padding: 6 * root.scaleFactor
                            background: Rectangle { color: "transparent" }
                        }
                    }
                }

                // Timestamp + format badge + raw/format toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6 * root.scaleFactor

                    Label {
                        text: lastMessagePanel.liveTimestamp
                        font.pixelSize: 10
                        opacity: 0.6
                        color: Material.foreground
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: lastMessagePanel.detectedFormat !== "raw"
                        color: lastMessagePanel.detectedFormat === "json"
                            ? Material.color(Material.Teal) : Material.color(Material.Purple)
                        radius: 3
                        implicitWidth: panelFmtText.implicitWidth + 8
                        implicitHeight: panelFmtText.implicitHeight + 4

                        Text {
                            id: panelFmtText
                            anchors.centerIn: parent
                            text: lastMessagePanel.detectedFormat.toUpperCase()
                            color: "white"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    Button {
                        visible: lastMessagePanel.detectedFormat !== "raw"
                        text: lastMessagePanel.showFormatted ? "Raw" : "Format"
                        flat: true
                        font.pixelSize: 10
                        implicitHeight: 24 * root.scaleFactor
                        onClicked: lastMessagePanel.showFormatted = !lastMessagePanel.showFormatted
                    }
                }

                // Message content
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 80 * root.scaleFactor
                    color: Qt.darker(Material.backgroundColor, 1.3)
                    border.color: Material.accent
                    border.width: 1
                    radius: 4

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 4 * root.scaleFactor
                        clip: true

                        TextArea {
                            text: lastMessagePanel.displayMessage
                            readOnly: true
                            wrapMode: TextArea.Wrap
                            selectByMouse: true
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            color: Material.foreground
                            padding: 6 * root.scaleFactor
                            background: Rectangle { color: "transparent" }
                        }
                    }
                }

                // History header
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "History (" + lastMessagePanel.liveHistory.length + ")"
                        font.bold: true
                        font.pixelSize: 11
                        color: Material.foreground
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Clear"
                        enabled: lastMessagePanel.liveHistory.length > 0
                        flat: true
                        font.pixelSize: 10
                        implicitHeight: 24 * root.scaleFactor
                        Material.foreground: Material.color(Material.Red)
                        onClicked: root.mqttTreeModel.clearHistory(lastMessagePanel.liveTopic)
                    }
                }

                // History list
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 60 * root.scaleFactor
                    clip: true

                    ListView {
                        id: miniHistoryView
                        model: lastMessagePanel.liveHistory
                        spacing: 4 * root.scaleFactor
                        property int selectedIndex: -1
                        onModelChanged: selectedIndex = -1

                        EmptyStateView {
                            visible: lastMessagePanel.liveHistory.length === 0
                            width: miniHistoryView.width
                            height: 80 * root.scaleFactor
                            icon: ""
                            title: "No history yet"
                            subtitle: ""
                            scaleFactor: root.scaleFactor
                        }

                        delegate: Rectangle {
                            id: histItem
                            required property var modelData
                            required property int index

                            property bool isSelected: miniHistoryView.selectedIndex === histItem.index
                            property string detectedFmt: {
                                var msg = modelData.message || ""
                                return msg.length > 0 ? Formatter.detectFormat(msg) : "raw"
                            }
                            property string formattedMsg: {
                                var msg = modelData.message || ""
                                if (!msg || detectedFmt === "raw") return msg
                                var r = Formatter.beautify(msg, detectedFmt)
                                return (typeof r === "object" && r.error) ? msg : r
                            }

                            width: miniHistoryView.width
                            height: miniHistCol.implicitHeight + 12 * root.scaleFactor
                            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            color: histItem.isSelected
                                ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.15)
                                : (index % 2 === 0
                                    ? Qt.darker(Material.backgroundColor, 1.4)
                                    : Qt.darker(Material.backgroundColor, 1.6))
                            Behavior on color { ColorAnimation { duration: 90 } }

                            border.color: histItem.isSelected
                                ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.6)
                                : Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.3)
                            border.width: histItem.isSelected ? 1.5 : 1
                            radius: 4

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: miniHistoryView.selectedIndex =
                                    (miniHistoryView.selectedIndex === histItem.index) ? -1 : histItem.index
                            }

                            ColumnLayout {
                                id: miniHistCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6 * root.scaleFactor
                                spacing: 3 * root.scaleFactor

                                // Header: badge + timestamp + format pill
                                RowLayout {
                                    Layout.fillWidth: true

                                    Rectangle {
                                        width: 22 * root.scaleFactor
                                        height: 14 * root.scaleFactor
                                        color: Material.accent
                                        radius: 2
                                        Label {
                                            text: "#" + (lastMessagePanel.liveHistory.length - histItem.index)
                                            font.bold: true
                                            font.pixelSize: 8
                                            color: "white"
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Label {
                                        text: modelData.timestamp || ""
                                        font.pixelSize: 9
                                        opacity: 0.6
                                        color: Material.foreground
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: histItem.detectedFmt !== "raw"
                                        color: histItem.detectedFmt === "json"
                                            ? Material.color(Material.Teal)
                                            : Material.color(Material.Purple)
                                        radius: 2
                                        implicitWidth: histFmtText.implicitWidth + 6
                                        implicitHeight: histFmtText.implicitHeight + 3
                                        Text {
                                            id: histFmtText
                                            anchors.centerIn: parent
                                            text: histItem.detectedFmt.toUpperCase()
                                            color: "white"
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }
                                }

                                // Collapsed: 2-line truncated preview
                                Text {
                                    visible: !histItem.isSelected
                                    text: modelData.message || ""
                                    color: Material.foreground
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                // Expanded: full formatted content
                                ScrollView {
                                    visible: histItem.isSelected
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(
                                        expandedText.implicitHeight + 12 * root.scaleFactor,
                                        180 * root.scaleFactor)
                                    clip: true

                                    TextArea {
                                        id: expandedText
                                        text: histItem.isSelected ? histItem.formattedMsg : ""
                                        readOnly: true
                                        wrapMode: TextArea.Wrap
                                        selectByMouse: true
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        color: Material.foreground
                                        padding: 4 * root.scaleFactor
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
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
