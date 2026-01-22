import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root

    property string presetName: ""
    property string presetData: ""
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool mqttConnected: false

    signal addToQueueRequested(string name)
    signal executeNowRequested(string name)

    width: 600 * scaleFactor
    height: 500 * scaleFactor
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

            Label {
                text: "Preset Details: " + root.presetName
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                text: root.presetData
                readOnly: true
                wrapMode: TextArea.Wrap
                selectByMouse: true
                font.family: root.fontFamily
                font.pixelSize: 11
                color: Material.foreground
                background: Rectangle {
                    color: Qt.darker(Material.backgroundColor, 1.3)
                    border.color: Material.accent
                    border.width: 1
                    radius: 4
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * root.scaleFactor

            Button {
                text: "Add to Queue"
                Material.background: Material.Green
                Layout.fillWidth: true
                onClicked: {
                    root.addToQueueRequested(root.presetName)
                    root.close()
                }
            }

            Button {
                text: "Execute Now"
                Material.background: Material.Purple
                enabled: root.mqttConnected
                Layout.fillWidth: true
                onClicked: {
                    root.executeNowRequested(root.presetName)
                    root.close()
                }
            }

            Button {
                text: "Close"
                Material.background: Material.Grey
                Layout.fillWidth: true
                onClicked: root.close()
            }
        }
    }
}
