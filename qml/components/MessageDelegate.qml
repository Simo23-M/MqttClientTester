import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

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

    signal clicked()
    signal deleteRetainedClicked(string topic)
    signal useAsPublishTopic(string topic)
    signal useAsSubscribeTopic(string topic)
    signal toggleExpand()

    width: parent ? parent.width : 200
    height: root.hasMessage
            ? Math.max(topicText.implicitHeight + messageText.implicitHeight + 20 * scaleFactor, 60 * scaleFactor)
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

                Text {
                    text: root.timestamp
                    color: Material.foreground
                    font.pixelSize: 10
                    opacity: 0.7
                    visible: root.hasMessage
                }
            }

            // Message preview - only for nodes with messages
            Text {
                id: messageText
                text: root.message
                color: Material.foreground
                font.family: root.fontFamily
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: root.hasMessage
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
