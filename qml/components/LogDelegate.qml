import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

Rectangle {
    id: root

    property string message: ""
    property int itemIndex: 0
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    width: parent ? parent.width : 200
    height: logText.implicitHeight + 10 * scaleFactor
    color: itemIndex % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)

    Text {
        id: logText
        text: root.message
        color: Material.foreground
        font.family: root.fontFamily
        font.pixelSize: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 5
        wrapMode: Text.Wrap
    }
}
