import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../utils/PayloadFormatter.js" as Formatter

Popup {
    id: root

    property string topic: ""
    property string message: ""
    property string timestamp: ""
    property var history: []
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool mqttConnected: false
    property string detectedFormat: root.message ? Formatter.detectFormat(root.message) : "raw"
    property bool showFormatted: true
    property string displayMessage: {
        if (!root.message) return ""
        if (showFormatted && detectedFormat !== "raw") {
            var result = Formatter.beautify(root.message, detectedFormat)
            if (typeof result === "object" && result.error) return root.message
            return result
        }
        return root.message
    }

    signal clearHistoryRequested(string topic)
    signal deleteRetainedRequested(string topic)

    width: 650 * scaleFactor
    height: 550 * scaleFactor
    modal: true
    anchors.centerIn: parent
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Material.backgroundColor
        border.color: Material.accent
        border.width: 1
        radius: 8
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15 * root.scaleFactor
        spacing: 12 * root.scaleFactor

        // Header with title and close button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

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
                onClicked: root.close()
                Layout.preferredWidth: 32 * root.scaleFactor
                Layout.preferredHeight: 32 * root.scaleFactor
            }
        }

        // Topic section
        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

            Label {
                text: "Topic:"
                font.bold: true
                color: Material.foreground
                Layout.fillWidth: true
            }

            Button {
                text: "🗑️ Delete Retained"
                Material.background: Material.Red
                enabled: root.mqttConnected
                font.pixelSize: 11
                implicitHeight: 30 * root.scaleFactor
                onClicked: {
                    root.deleteRetainedRequested(root.topic)
                    root.close()
                }
                ToolTip.visible: hovered
                ToolTip.text: "Send empty message with retain flag to clear retained message"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60 * root.scaleFactor
            color: Qt.darker(Material.backgroundColor, 1.3)
            border.color: Material.accent
            border.width: 1
            radius: 4

            ScrollView {
                anchors.fill: parent
                anchors.margins: 4 * root.scaleFactor
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    text: root.topic
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.accent
                    padding: 8 * root.scaleFactor
                    background: Rectangle { color: "transparent" }
                }
            }
        }

        // Current message section
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.scaleFactor

            Label {
                text: "Current Message (Last received: " + root.timestamp + "):"
                font.bold: true
                color: Material.foreground
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.detectedFormat !== "raw"
                color: root.detectedFormat === "json" ? Material.color(Material.Teal) : Material.color(Material.Purple)
                radius: 3
                implicitWidth: detailFormatBadgeText.implicitWidth + 10
                implicitHeight: detailFormatBadgeText.implicitHeight + 6

                Text {
                    id: detailFormatBadgeText
                    anchors.centerIn: parent
                    text: root.detectedFormat.toUpperCase()
                    color: "white"
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Button {
                visible: root.detectedFormat !== "raw"
                text: root.showFormatted ? "Raw" : "Format"
                flat: true
                font.pixelSize: 11
                implicitHeight: 28 * root.scaleFactor
                onClicked: root.showFormatted = !root.showFormatted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140 * root.scaleFactor
            color: Qt.darker(Material.backgroundColor, 1.3)
            border.color: Material.accent
            border.width: 1
            radius: 4

            ScrollView {
                anchors.fill: parent
                anchors.margins: 4 * root.scaleFactor
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                TextArea {
                    text: root.displayMessage
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    color: Material.foreground
                    padding: 8 * root.scaleFactor
                    background: Rectangle { color: "transparent" }
                }
            }
        }

        // History header with clear button
        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

            Label {
                text: "History (" + root.history.length + " previous messages):"
                font.bold: true
                color: Material.foreground
                Layout.fillWidth: true
            }

            Button {
                text: "Clear History"
                enabled: root.history.length > 0
                Material.background: Material.Red
                font.pixelSize: 11
                implicitHeight: 30 * root.scaleFactor
                onClicked: {
                    root.clearHistoryRequested(root.topic)
                    root.history = []
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
                visible: root.history.length > 0
                clip: true

                ListView {
                    id: historyListView
                    model: root.history
                    spacing: 4 * root.scaleFactor

                    delegate: Rectangle {
                        width: historyListView.width
                        height: historyContent.implicitHeight + 16 * root.scaleFactor
                        color: index % 2 === 0 ? Qt.darker(Material.backgroundColor, 1.4) : Qt.darker(Material.backgroundColor, 1.6)
                        border.color: Material.accent
                        border.width: 0.5
                        radius: 6

                        ColumnLayout {
                            id: historyContent
                            anchors.fill: parent
                            anchors.margins: 8 * root.scaleFactor
                            spacing: 4 * root.scaleFactor

                            // History item header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8 * root.scaleFactor

                                Rectangle {
                                    width: 24 * root.scaleFactor
                                    height: 18 * root.scaleFactor
                                    color: Material.accent
                                    radius: 3

                                    Label {
                                        text: "#" + (root.history.length - index)
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
                                Layout.preferredHeight: Math.min(historyMessageText.implicitHeight + 10, 100 * root.scaleFactor)
                                clip: true

                                TextArea {
                                    id: historyMessageText
                                    text: {
                                        var msg = modelData.message || ""
                                        if (root.showFormatted && msg.length > 0) {
                                            var fmt = Formatter.detectFormat(msg)
                                            if (fmt !== "raw") {
                                                var result = Formatter.beautify(msg, fmt)
                                                if (typeof result !== "object") return result
                                            }
                                        }
                                        return msg
                                    }
                                    readOnly: true
                                    wrapMode: TextArea.Wrap
                                    selectByMouse: true
                                    font.family: root.fontFamily
                                    font.pixelSize: 10
                                    color: Material.foreground
                                    background: Rectangle { color: "transparent" }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state message
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.history.length === 0
                spacing: 10 * root.scaleFactor

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
                    Layout.maximumWidth: 250 * root.scaleFactor
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
