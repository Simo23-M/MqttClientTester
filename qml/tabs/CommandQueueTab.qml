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
    property var commandQueue
    property var appController
    property ListModel presetListModel
    property ListModel queueListModel
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    signal updatePresetListRequested()
    signal updateQueueListRequested()
    signal showPresetDetail(string name, string data)
    signal showJsonView(string content)

    spacing: 10 * scaleFactor

    // File dialogs
    FileDialog {
        id: presetFileDialog
        title: "Select Preset JSON File"
        nameFilters: ["JSON Files (*.json)", "All Files (*)"]
        folder: root.appController ? root.appController.localFileToUrl(root.appController.getDocumentsPath()) : ""
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            if (root.commandQueue.loadPresetsFromFile(filePath)) {
                root.updatePresetListRequested()
            }
        }
    }

    FileDialog {
        id: savePresetFileDialog
        title: "Save Preset JSON File"
        nameFilters: ["JSON Files (*.json)", "All Files (*)"]
        folder: root.appController ? root.appController.localFileToUrl(root.appController.getDocumentsPath()) : ""
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var filePath = root.appController.urlToLocalFile(file)
            root.commandQueue.savePresetsToFile(filePath)
        }
    }

    FileDialog {
        id: scriptBrowseDialog
        title: "Select Script File"
        nameFilters: Qt.platform.os === "windows"
            ? ["PowerShell Scripts (*.ps1)", "All Files (*)"]
            : ["Shell Scripts (*.sh)", "All Files (*)"]
        folder: root.appController ? root.appController.localFileToUrl(root.appController.getHomePath()) : ""
        fileMode: FileDialog.OpenFile
        onAccepted: scriptPathField.text = root.appController.urlToLocalFile(file)
    }

    // Left panel - Preset Management and Queue Builder
    ScrollView {
        Layout.preferredWidth: 500 * root.scaleFactor
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width - 10
            spacing: 15 * root.scaleFactor

            // Preset File Management
            GroupBox {
                title: "Preset File Management"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    Label {
                        text: root.commandQueue && root.commandQueue.loadedPresetFile !== "" ?
                              "Loaded: " + root.commandQueue.loadedPresetFile.split('/').pop() :
                              "No preset file loaded"
                        font.pixelSize: 11
                        color: root.commandQueue && root.commandQueue.loadedPresetFile !== "" ?
                               Material.accent : Material.color(Material.Orange)
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.scaleFactor

                        Button {
                            text: "Load Presets"
                            Material.background: Material.Blue
                            Layout.fillWidth: true
                            onClicked: presetFileDialog.open()
                        }

                        Button {
                            text: "Save Presets"
                            Material.background: Material.Green
                            enabled: root.commandQueue && root.commandQueue.getPresetNames().length > 0
                            Layout.fillWidth: true
                            onClicked: savePresetFileDialog.open()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.scaleFactor

                        Button {
                            text: "View JSON"
                            Material.background: Material.Indigo
                            enabled: root.commandQueue && root.commandQueue.getPresetNames().length > 0
                            Layout.fillWidth: true
                            onClicked: root.showJsonView(root.commandQueue.getPresetsJson())
                        }

                        Button {
                            text: "Clear All"
                            Material.background: Material.Red
                            enabled: root.commandQueue && root.commandQueue.getPresetNames().length > 0
                            Layout.fillWidth: true
                            onClicked: {
                                root.commandQueue.clearPresets()
                                root.updatePresetListRequested()
                            }
                        }
                    }
                }
            }

            // Available Presets
            GroupBox {
                title: "Available Presets (" + root.presetListModel.count + ")"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 300 * root.scaleFactor
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            id: presetSearchField
                            placeholderText: "Search presets..."
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "🔄"
                            onClicked: root.updatePresetListRequested()
                            ToolTip.visible: hovered
                            ToolTip.text: "Refresh preset list"
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: presetListView
                            model: root.presetListModel

                            delegate: Rectangle {
                                id: presetDelegate
                                required property var model
                                required property int index

                                width: presetListView.width
                                height: 58 * root.scaleFactor
                                color: presetHover.hovered
                                       ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.08)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 90 } }

                                HoverHandler { id: presetHover }

                                // hairline separator
                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 1
                                    color: Qt.rgba(Material.foreground.r, Material.foreground.g, Material.foreground.b, 0.05)
                                }

                                // left accent stripe
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: 3 * root.scaleFactor
                                    color: Material.accent
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12 * root.scaleFactor
                                    anchors.rightMargin: 8 * root.scaleFactor
                                    anchors.topMargin: 6 * root.scaleFactor
                                    anchors.bottomMargin: 6 * root.scaleFactor
                                    spacing: 8 * root.scaleFactor

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2 * root.scaleFactor

                                        Text {
                                            text: presetDelegate.model.name
                                            color: Material.accent
                                            font.family: root.fontFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "Click to view details"
                                            color: Material.foreground
                                            font.pixelSize: 10
                                            opacity: 0.55
                                        }
                                    }

                                    Button {
                                        text: "Add to Queue"
                                        flat: true
                                        Material.foreground: Material.color(Material.Green)
                                        font.pixelSize: 11
                                        implicitHeight: 30 * root.scaleFactor
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: {
                                            root.commandQueue.addPresetToQueue(presetDelegate.model.name)
                                            root.updateQueueListRequested()
                                        }
                                    }

                                    Button {
                                        text: "Execute"
                                        flat: true
                                        Material.foreground: Material.accent
                                        font.pixelSize: 11
                                        implicitHeight: 30 * root.scaleFactor
                                        Layout.alignment: Qt.AlignVCenter
                                        enabled: root.mqttClient && root.mqttClient.connected
                                        onClicked: {
                                            root.commandQueue.addPresetToQueue(presetDelegate.model.name)
                                            root.updateQueueListRequested()
                                            root.commandQueue.executeCommand(root.commandQueue.queueSize - 1)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.showPresetDetail(presetDelegate.model.name, root.commandQueue.getPresetData(presetDelegate.model.name))
                                    propagateComposedEvents: true
                                    z: -1
                                }
                            }

                            // Empty state
                            EmptyStateView {
                                visible: root.presetListModel.count === 0
                                width: presetListView.width
                                height: 150 * root.scaleFactor
                                icon: "📋"
                                title: "No presets loaded"
                                subtitle: "Load a JSON preset file to get started"
                                scaleFactor: root.scaleFactor
                            }
                        }
                    }
                }
            }

            // Add Script to Queue
            GroupBox {
                title: "Add Script to Queue"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8 * root.scaleFactor

                    TextField {
                        id: scriptNameField
                        placeholderText: "Script name (optional)"
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6 * root.scaleFactor

                        TextField {
                            id: scriptPathField
                            placeholderText: "Script path..."
                            Layout.fillWidth: true
                        }

                        Button {
                            text: "Browse"
                            font.pixelSize: 11
                            implicitHeight: 36 * root.scaleFactor
                            onClicked: scriptBrowseDialog.open()
                        }
                    }

                    TextField {
                        id: scriptArgsField
                        placeholderText: "Arguments (optional)"
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * root.scaleFactor

                        Label {
                            text: "Delay (ms):"
                            font.pixelSize: 12
                        }

                        SpinBox {
                            id: scriptDelaySpinBox
                            from: 0
                            to: 60000
                            value: 0
                            stepSize: 500
                            Layout.fillWidth: true
                        }
                    }

                    Button {
                        text: "Add Script to Queue"
                        Material.background: Material.Orange
                        Layout.fillWidth: true
                        enabled: scriptPathField.text.trim() !== ""
                        onClicked: {
                            root.commandQueue.addScriptToQueue(
                                scriptNameField.text.trim(),
                                scriptPathField.text.trim(),
                                scriptArgsField.text.trim(),
                                scriptDelaySpinBox.value
                            )
                            root.updateQueueListRequested()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Right panel - Command Queue
    GroupBox {
        title: "Command Queue"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Material.elevation: 2

        ColumnLayout {
            anchors.fill: parent
            spacing: 10 * root.scaleFactor

            // Queue Controls
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 100 * root.scaleFactor
                implicitHeight: queueControlsLayout.implicitHeight + 20 * root.scaleFactor
                color: Qt.darker(Material.backgroundColor, 1.2)
                radius: 8
                border.color: Material.accent
                border.width: 1

                ColumnLayout {
                    id: queueControlsLayout
                    anchors.fill: parent
                    anchors.margins: 10 * root.scaleFactor
                    spacing: 8 * root.scaleFactor

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.scaleFactor

                        Label {
                            text: "Queue Size: " + (root.commandQueue ? root.commandQueue.queueSize : 0)
                            font.bold: true
                            color: Material.foreground
                        }

                        Label {
                            text: root.commandQueue && root.commandQueue.isRunning ?
                                  "● Running [" + (root.commandQueue.currentIndex + 1) + "/" + root.commandQueue.queueSize + "]" :
                                  "○ Idle"
                            font.bold: true
                            color: root.commandQueue && root.commandQueue.isRunning ?
                                   Material.color(Material.Green) :
                                   Material.color(Material.Grey)
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Clear Queue"
                            Material.background: Material.Red
                            font.pixelSize: 12
                            implicitHeight: 32 * root.scaleFactor
                            enabled: root.commandQueue && root.commandQueue.queueSize > 0 && !root.commandQueue.isRunning
                            onClicked: {
                                root.commandQueue.clearQueue()
                                root.updateQueueListRequested()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10 * root.scaleFactor

                        Button {
                            text: "▶️ Start"
                            Material.background: Material.Green
                            enabled: root.mqttClient && root.mqttClient.connected &&
                                     root.commandQueue && root.commandQueue.queueSize > 0 && !root.commandQueue.isRunning
                            Layout.fillWidth: true
                            onClicked: root.commandQueue.startQueue()
                        }

                        Button {
                            text: "⏹️ Stop"
                            Material.background: Material.Red
                            enabled: root.commandQueue && root.commandQueue.isRunning
                            Layout.fillWidth: true
                            onClicked: root.commandQueue.stopQueue()
                        }

                        Button {
                            text: "⏭️ Next"
                            Material.background: Material.Orange
                            enabled: root.mqttClient && root.mqttClient.connected &&
                                     root.commandQueue && root.commandQueue.queueSize > 0
                            Layout.fillWidth: true
                            onClicked: root.commandQueue.executeNext()
                        }
                    }
                }
            }

            // Queue List
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: queueListView
                    model: root.queueListModel
                    property int dragFromIndex: -1
                    property int dragToIndex: -1

                    delegate: Rectangle {
                        id: queueDelegate
                        required property var model
                        required property int index
                        readonly property bool running: root.commandQueue
                                                         && queueDelegate.index === root.commandQueue.currentIndex
                                                         && root.commandQueue.isRunning
                        readonly property bool isScript: queueDelegate.model.commandType === 1
                        readonly property color typeColor: queueDelegate.isScript ? Material.color(Material.Orange)
                                                                                   : Material.accent

                        width: queueListView.width
                        height: 84 * root.scaleFactor
                        opacity: (queueListView.dragFromIndex === queueDelegate.index && queueListView.dragFromIndex !== -1) ? 0.35 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 80 } }

                        color: queueDelegate.running
                               ? Qt.rgba(Material.color(Material.Green).r, Material.color(Material.Green).g,
                                         Material.color(Material.Green).b, 0.16)
                               : (queueListView.dragToIndex === queueDelegate.index
                                  && queueListView.dragFromIndex !== -1
                                  && queueListView.dragFromIndex !== queueDelegate.index)
                                 ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.22)
                                 : (queueHover.hovered
                                    ? Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.08)
                                    : "transparent")
                        Behavior on color { ColorAnimation { duration: 90 } }

                        HoverHandler { id: queueHover }

                        // hairline separator
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: Qt.rgba(Material.foreground.r, Material.foreground.g, Material.foreground.b, 0.05)
                        }

                        // left stripe: running / script / publish
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3 * root.scaleFactor
                            color: queueDelegate.running ? Material.color(Material.Green) : queueDelegate.typeColor
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12 * root.scaleFactor
                            anchors.rightMargin: 8 * root.scaleFactor
                            anchors.topMargin: 8 * root.scaleFactor
                            anchors.bottomMargin: 8 * root.scaleFactor
                            spacing: 10 * root.scaleFactor

                            // Position indicator
                            Rectangle {
                                implicitWidth: 30 * root.scaleFactor
                                implicitHeight: 30 * root.scaleFactor
                                radius: height / 2
                                Layout.alignment: Qt.AlignVCenter
                                color: queueDelegate.running
                                       ? Material.color(Material.Green)
                                       : Qt.rgba(Material.accent.r, Material.accent.g, Material.accent.b, 0.18)

                                Label {
                                    text: (queueDelegate.index + 1).toString()
                                    font.bold: true
                                    font.pixelSize: 13
                                    color: queueDelegate.running ? "white" : Material.accent
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3 * root.scaleFactor

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6 * root.scaleFactor

                                    Text {
                                        text: queueDelegate.model.name
                                        color: queueDelegate.typeColor
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    // type pill
                                    Rectangle {
                                        color: Qt.rgba(queueDelegate.typeColor.r, queueDelegate.typeColor.g,
                                                       queueDelegate.typeColor.b, 0.20)
                                        border.color: Qt.rgba(queueDelegate.typeColor.r, queueDelegate.typeColor.g,
                                                              queueDelegate.typeColor.b, 0.55)
                                        border.width: 1
                                        radius: height / 2
                                        implicitWidth: typeText.implicitWidth + 12
                                        implicitHeight: 16
                                        Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            id: typeText
                                            anchors.centerIn: parent
                                            text: queueDelegate.isScript ? "SCRIPT" : "PUBLISH"
                                            color: queueDelegate.typeColor
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    text: queueDelegate.isScript
                                          ? "Script: " + queueDelegate.model.scriptPath
                                          : "Topic: " + queueDelegate.model.topic
                                    color: Material.foreground
                                    opacity: 0.7
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 8 * root.scaleFactor

                                    Text {
                                        visible: !queueDelegate.isScript
                                        text: "QoS " + queueDelegate.model.qos
                                        color: Material.foreground
                                        font.pixelSize: 9
                                        opacity: 0.55
                                    }

                                    Text {
                                        text: queueDelegate.model.delay + "ms"
                                        color: Material.foreground
                                        font.pixelSize: 9
                                        opacity: 0.55
                                    }

                                    Text {
                                        visible: !queueDelegate.isScript && queueDelegate.model.retain
                                        text: "RETAIN"
                                        color: Material.color(Material.Orange)
                                        font.pixelSize: 9
                                        font.bold: true
                                    }

                                    Text {
                                        visible: queueDelegate.isScript && queueDelegate.model.scriptArgs !== ""
                                        text: "Args: " + queueDelegate.model.scriptArgs
                                        color: Material.foreground
                                        font.pixelSize: 9
                                        opacity: 0.55
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // drag handle
                            Item {
                                id: gripHandle
                                implicitWidth: 28 * root.scaleFactor
                                implicitHeight: 28 * root.scaleFactor
                                Layout.alignment: Qt.AlignVCenter
                                visible: root.commandQueue && !root.commandQueue.isRunning

                                HoverHandler {
                                    cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⠿"
                                    color: Material.foreground
                                    opacity: 0.45
                                    font.pixelSize: 16
                                }

                                DragHandler {
                                    id: dragHandler
                                    target: null
                                    enabled: root.commandQueue && !root.commandQueue.isRunning

                                    onActiveChanged: {
                                        if (active) {
                                            queueListView.dragFromIndex = queueDelegate.index
                                            queueListView.dragToIndex = queueDelegate.index
                                        } else {
                                            var from = queueListView.dragFromIndex
                                            var to = queueListView.dragToIndex
                                            queueListView.dragFromIndex = -1
                                            queueListView.dragToIndex = -1
                                            if (from !== -1 && to !== -1 && from !== to) {
                                                root.commandQueue.moveCommand(from, to)
                                                root.updateQueueListRequested()
                                            }
                                        }
                                    }

                                    onCentroidChanged: {
                                        if (!active) return
                                        var viewPos = queueListView.mapFromItem(
                                            null,
                                            centroid.scenePosition.x,
                                            centroid.scenePosition.y)
                                        var idx = queueListView.indexAt(
                                            viewPos.x + queueListView.contentX,
                                            viewPos.y + queueListView.contentY)
                                        if (idx !== -1) queueListView.dragToIndex = idx
                                    }
                                }
                            }

                            // delete
                            Button {
                                text: "✕"
                                flat: true
                                Material.foreground: Material.color(Material.Red)
                                enabled: root.commandQueue && !root.commandQueue.isRunning
                                implicitWidth: 30 * root.scaleFactor
                                implicitHeight: 30 * root.scaleFactor
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: 12
                                ToolTip.visible: hovered
                                ToolTip.text: "Remove from queue"
                                onClicked: {
                                    root.commandQueue.removeCommandFromQueue(queueDelegate.index)
                                    root.updateQueueListRequested()
                                }
                            }
                        }
                    }

                    // Empty state
                    EmptyStateView {
                        visible: root.queueListModel.count === 0
                        width: queueListView.width
                        height: 200 * root.scaleFactor
                        icon: "📝"
                        title: "Queue is empty"
                        subtitle: "Add commands from presets or create custom ones"
                        scaleFactor: root.scaleFactor
                    }
                }
            }
        }
    }
}
