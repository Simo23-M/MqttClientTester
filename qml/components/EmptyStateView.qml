import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property double scaleFactor: 1

    color: "transparent"
    border.color: Material.accent
    border.width: 1
    opacity: 0.5

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10 * root.scaleFactor

        Text {
            text: root.icon
            font.pixelSize: 40
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: root.title
            color: Material.foreground
            opacity: 0.7
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Material.foreground
            opacity: 0.5
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 250 * root.scaleFactor
            wrapMode: Text.WordWrap
        }
    }
}
