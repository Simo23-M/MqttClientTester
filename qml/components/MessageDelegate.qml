import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../utils/PayloadFormatter.js" as Formatter

Rectangle {
    id: root

    property string topic: ""
    property string segment: ""
    property string message: ""
    property string timestamp: ""
    property bool received: true
    property string historyJson: ""
    property int itemIndex: 0
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool mqttConnected: false
    property int level: 0
    property bool expanded: false
    property bool hasChildren: false
    property bool hasMessage: false
    property int subtopicCount: 0
    property var updateTick: 0

    // History navigation
    property var parsedHistory: {
        if (!historyJson || historyJson === "") return []
        try { return JSON.parse(historyJson) } catch(e) { return [] }
    }
    property int historyCount: parsedHistory.length
    property int historyViewIndex: 0  // 0 = latest (current message), 1+ = history items

    property string displayedMessage: {
        if (historyViewIndex === 0) return root.message
        var idx = historyViewIndex - 1
        if (idx >= 0 && idx < parsedHistory.length) {
            return parsedHistory[parsedHistory.length - 1 - idx].message || ""
        }
        return root.message
    }
    property string displayedTimestamp: {
        if (historyViewIndex === 0) return root.timestamp
        var idx = historyViewIndex - 1
        if (idx >= 0 && idx < parsedHistory.length) {
            return parsedHistory[parsedHistory.length - 1 - idx].timestamp || ""
        }
        return root.timestamp
    }

    property string detectedFormat: displayedMessage ? Formatter.detectFormat(displayedMessage) : "raw"
    property string formattedMessage: {
        if (!displayedMessage) return ""
        if (detectedFormat === "json") {
            var result = Formatter.beautifyJson(displayedMessage)
            if (typeof result === "object" && result.error) return displayedMessage
            return result
        }
        return displayedMessage
    }

    onMessageChanged: historyViewIndex = 0

    property bool _initialized: false
    Component.onCompleted: _initialized = true

    onUpdateTickChanged: {
        if (_initialized && updateTick > 0) {
            flashAnimation.restart()
        }
    }

    signal clicked()
    signal deleteRetainedClicked(string topic)
    signal useAsPublishTopic(string topic)
    signal useAsSubscribeTopic(string topic)
    signal toggleExpand()

    width: parent ? parent.width : 200
    height: root.hasMessage
            ? Math.max(topicText.implicitHeight + messageText.implicitHeight + (root.historyCount > 0 ? 28 * scaleFactor : 0) + 20 * scaleFactor, 60 * scaleFactor)
            : 32 * scaleFactor
    color: itemIndex % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
    border.color: root.hasMessage
                  ? (received ? Material.color(Material.Orange) : Material.accent)
                  : Qt.darker(Material.background, 1.3)
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.hasMessage ? 8 * root.scaleFactor : 4 * root.scaleFactor
        spacing: 4 * root.scaleFactor

        // Indentation spacer
        Item {
            width: root.level * 20 * root.scaleFactor
            height: 1
        }

        // Expand/collapse arrow
        Text {
            text: root.expanded ? "\u25BC" : "\u25B6"
            color: Material.accent
            font.pixelSize: 10 * root.scaleFactor
            visible: root.hasChildren
            Layout.preferredWidth: visible ? 14 * root.scaleFactor : 0

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: root.toggleExpand()
            }
        }

        // Invisible spacer when no arrow (keep alignment)
        Item {
            width: 14 * root.scaleFactor
            height: 1
            visible: !root.hasChildren
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.hasMessage ? 4 * root.scaleFactor : 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 6 * root.scaleFactor

                Text {
                    id: topicText
                    text: root.segment
                    color: root.hasMessage ? Material.accent : Material.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                // Subtopic count badge
                Rectangle {
                    visible: root.hasChildren && root.subtopicCount > 0
                    color: Qt.darker(Material.background, 1.4)
                    radius: 3
                    implicitWidth: badgeText.implicitWidth + 8
                    implicitHeight: badgeText.implicitHeight + 4

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.subtopicCount
                        color: Material.foreground
                        font.pixelSize: 9
                        opacity: 0.8
                    }
                }

                // Format badge
                Rectangle {
                    visible: root.hasMessage && root.detectedFormat !== "raw"
                    color: root.detectedFormat === "json" ? Material.color(Material.Teal) : Material.color(Material.Purple)
                    radius: 3
                    implicitWidth: formatBadgeText.implicitWidth + 8
                    implicitHeight: formatBadgeText.implicitHeight + 4

                    Text {
                        id: formatBadgeText
                        anchors.centerIn: parent
                        text: root.detectedFormat.toUpperCase()
                        color: "white"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                // History count badge
                Rectangle {
                    visible: root.hasMessage && root.historyCount > 0
                    color: Material.color(Material.DeepOrange)
                    radius: width / 2
                    implicitWidth: Math.max(historyCountText.implicitWidth + 6, 18)
                    implicitHeight: 18

                    Text {
                        id: historyCountText
                        anchors.centerIn: parent
                        text: root.historyCount
                        color: "white"
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Text {
                    text: root.displayedTimestamp
                    color: Material.foreground
                    font.pixelSize: 10
                    opacity: 0.7
                    visible: root.hasMessage
                }
            }

            // Message preview - only for nodes with messages
            Text {
                id: messageText
                text: root.formattedMessage
                color: Material.foreground
                font.family: root.fontFamily
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: root.hasMessage
            }

            // History navigation row
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasMessage && root.historyCount > 0
                spacing: 4 * root.scaleFactor

                Button {
                    text: "\u25C0"
                    flat: true
                    font.pixelSize: 10
                    implicitWidth: 24 * root.scaleFactor
                    implicitHeight: 20 * root.scaleFactor
                    enabled: root.historyViewIndex < root.historyCount
                    onClicked: root.historyViewIndex++
                }

                Text {
                    text: root.historyViewIndex === 0 ? "latest" : ("-%1 of %2".arg(root.historyViewIndex).arg(root.historyCount + 1))
                    color: Material.foreground
                    font.pixelSize: 9
                    opacity: 0.7
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    text: "\u25B6"
                    flat: true
                    font.pixelSize: 10
                    implicitWidth: 24 * root.scaleFactor
                    implicitHeight: 20 * root.scaleFactor
                    enabled: root.historyViewIndex > 0
                    onClicked: root.historyViewIndex--
                }
            }
        }

        // Delete retained button
        Button {
            id: deleteButton
            text: "\uD83D\uDDD1\uFE0F"
            font.pixelSize: 14
            implicitWidth: 36 * root.scaleFactor
            implicitHeight: 36 * root.scaleFactor
            Material.background: Material.Red
            enabled: root.mqttConnected && root.hasMessage
            visible: root.mqttConnected && root.hasMessage
            onClicked: root.deleteRetainedClicked(root.topic)
            ToolTip.visible: hovered
            ToolTip.text: "Delete retained message"
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: deleteButton.visible ? deleteButton.width + 16 * root.scaleFactor : 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (root.hasMessage) {
                    contextMenu.popup()
                }
            } else {
                if (root.hasChildren) {
                    root.toggleExpand()
                } else if (root.hasMessage) {
                    root.clicked()
                }
            }
        }
    }

    // Flash overlay for new message highlight
    Rectangle {
        id: flashOverlay
        anchors.fill: parent
        color: Material.color(Material.Amber)
        opacity: 0
        z: 10
        radius: 0

        SequentialAnimation {
            id: flashAnimation
            NumberAnimation { target: flashOverlay; property: "opacity"; from: 0; to: 0.4; duration: 100 }
            NumberAnimation { target: flashOverlay; property: "opacity"; from: 0.4; to: 0; duration: 400 }
        }
    }

    Menu {
        id: contextMenu
        MenuItem {
            text: "Use as Publish Topic"
            onTriggered: root.useAsPublishTopic(root.topic)
        }
        MenuItem {
            text: "Use as Subscribe Topic"
            onTriggered: root.useAsSubscribeTopic(root.topic)
        }
    }
}
