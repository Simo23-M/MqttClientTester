import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string topic: ""
    property string message: ""
    property string timestamp: ""
    property bool received: true
    property string historyJson: ""
    property int itemIndex: 0
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool mqttConnected: false

    signal clicked()
    signal deleteRetainedClicked(string topic)

    width: parent ? parent.width : 200
    height: Math.max(topicText.implicitHeight + messageText.implicitHeight + 20 * scaleFactor, 70 * scaleFactor)
    color: itemIndex % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
    border.color: received ? Material.color(Material.Orange) : Material.accent
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8 * root.scaleFactor
        spacing: 8 * root.scaleFactor

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4 * root.scaleFactor

            RowLayout {
                Layout.fillWidth: true

                Text {
                    id: topicText
                    text: root.topic
                    color: Material.accent
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }

                Text {
                    text: root.timestamp
                    color: Material.foreground
                    font.pixelSize: 10
                    opacity: 0.7
                }
            }

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
            }
        }

        // Delete retained button
        Button {
            id: deleteButton
            text: "🗑️"
            font.pixelSize: 14
            implicitWidth: 36 * root.scaleFactor
            implicitHeight: 36 * root.scaleFactor
            Material.background: Material.Red
            enabled: root.mqttConnected
            visible: root.mqttConnected
            onClicked: root.deleteRetainedClicked(root.topic)
            ToolTip.visible: hovered
            ToolTip.text: "Delete retained message"
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: deleteButton.visible ? deleteButton.width + 16 * root.scaleFactor : 0
        onClicked: root.clicked()
    }
}
