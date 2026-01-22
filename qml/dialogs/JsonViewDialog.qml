import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root

    property string jsonContent: ""
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    width: 700 * scaleFactor
    height: 600 * scaleFactor
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
                text: "Preset JSON Configuration"
                font.bold: true
                font.pixelSize: 16
                Layout.fillWidth: true
                color: Material.foreground
            }

            Button {
                text: "Copy"
                Material.background: Material.Blue
                onClicked: {
                    // Copy to clipboard - placeholder for platform integration
                }
            }

            Button {
                text: "✕"
                flat: true
                onClicked: root.close()
                Layout.preferredWidth: 32 * root.scaleFactor
                Layout.preferredHeight: 32 * root.scaleFactor
            }
        }

        Label {
            text: "All available presets in JSON format"
            font.pixelSize: 11
            opacity: 0.7
            color: Material.foreground
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                text: root.jsonContent
                readOnly: true
                wrapMode: TextArea.Wrap
                selectByMouse: true
                font.family: root.fontFamily
                font.pixelSize: 10
                color: Material.accent
                background: Rectangle {
                    color: Qt.darker(Material.backgroundColor, 1.4)
                    border.color: Material.accent
                    border.width: 1
                    radius: 4
                }
            }
        }

        Button {
            text: "Close"
            Material.background: Material.Grey
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.close()
        }
    }
}
