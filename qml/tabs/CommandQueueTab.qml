import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"
import "../dialogs"

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
                                width: presetListView.width
                                height: 70 * root.scaleFactor
                                color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                                border.color: Material.accent
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10 * root.scaleFactor
                                    spacing: 10 * root.scaleFactor

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5 * root.scaleFactor

                                        Text {
                                            text: model.name
                                            color: Material.accent
                                            font.family: root.fontFamily
                                            font.pixelSize: 13
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: "Click to view details"
                                            color: Material.foreground
                                            font.pixelSize: 10
                                            opacity: 0.6
                                        }
                                    }

                                    Button {
                                        text: "Add to Queue"
                                        Material.background: Material.Green
                                        font.pixelSize: 11
                                        implicitHeight: 30 * root.scaleFactor
                                        onClicked: {
                                            root.commandQueue.addPresetToQueue(model.name)
                                            root.updateQueueListRequested()
                                        }
                                    }

                                    Button {
                                        text: "Execute Now"
                                        Material.background: Material.Purple
                                        font.pixelSize: 11
                                        implicitHeight: 30 * root.scaleFactor
                                        enabled: root.mqttClient && root.mqttClient.connected
                                        onClicked: {
                                            root.commandQueue.addPresetToQueue(model.name)
                                            root.updateQueueListRequested()
                                            root.commandQueue.executeCommand(root.commandQueue.queueSize - 1)
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.showPresetDetail(model.name, root.commandQueue.getPresetData(model.name))
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

                    delegate: Rectangle {
                        width: queueListView.width
                        height: 90 * root.scaleFactor
                        color: root.commandQueue && index === root.commandQueue.currentIndex && root.commandQueue.isRunning ?
                               Qt.darker(Material.color(Material.Green), 1.8) :
                               index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                        border.color: root.commandQueue && index === root.commandQueue.currentIndex && root.commandQueue.isRunning ?
                                     Material.color(Material.Green) : Material.accent
                        border.width: root.commandQueue && index === root.commandQueue.currentIndex && root.commandQueue.isRunning ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10 * root.scaleFactor
                            spacing: 10 * root.scaleFactor

                            // Position indicator
                            Rectangle {
                                width: 35 * root.scaleFactor
                                height: 35 * root.scaleFactor
                                radius: 17.5 * root.scaleFactor
                                color: Material.accent

                                Label {
                                    text: (index + 1).toString()
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "white"
                                    anchors.centerIn: parent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4 * root.scaleFactor

                                Text {
                                    text: model.name
                                    color: Material.accent
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Topic: " + model.topic
                                    color: Material.foreground
                                    font.pixelSize: 10
                                    opacity: 0.8
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 10 * root.scaleFactor

                                    Text {
                                        text: "QoS: " + model.qos
                                        color: Material.foreground
                                        font.pixelSize: 9
                                        opacity: 0.6
                                    }

                                    Text {
                                        text: "Delay: " + model.delay + "ms"
                                        color: Material.foreground
                                        font.pixelSize: 9
                                        opacity: 0.6
                                    }

                                    Text {
                                        text: model.retain ? "RETAIN" : ""
                                        color: Material.color(Material.Orange)
                                        font.pixelSize: 9
                                        font.bold: true
                                        visible: model.retain
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 4 * root.scaleFactor

                                Button {
                                    text: "Up"
                                    enabled: index > 0 && root.commandQueue && !root.commandQueue.isRunning
                                    implicitWidth: 50 * root.scaleFactor
                                    implicitHeight: 32 * root.scaleFactor
                                    font.pixelSize: 11
                                    onClicked: {
                                        root.commandQueue.moveCommandUp(index)
                                        root.updateQueueListRequested()
                                    }
                                }

                                Button {
                                    text: "Down"
                                    enabled: index < root.queueListModel.count - 1 && root.commandQueue && !root.commandQueue.isRunning
                                    implicitWidth: 50 * root.scaleFactor
                                    implicitHeight: 32 * root.scaleFactor
                                    font.pixelSize: 11
                                    onClicked: {
                                        root.commandQueue.moveCommandDown(index)
                                        root.updateQueueListRequested()
                                    }
                                }
                            }

                            Button {
                                text: "Del"
                                Material.background: Material.Red
                                enabled: root.commandQueue && !root.commandQueue.isRunning
                                implicitWidth: 45 * root.scaleFactor
                                implicitHeight: 45 * root.scaleFactor
                                font.pixelSize: 11
                                onClicked: {
                                    root.commandQueue.removeCommandFromQueue(index)
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
