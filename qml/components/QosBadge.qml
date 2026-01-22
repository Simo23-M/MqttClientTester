import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

Rectangle {
    id: root

    property int qos: 0
    property double scaleFactor: 1

    width: 40 * scaleFactor
    height: 20 * scaleFactor
    color: qos === 0 ? Material.color(Material.Green) :
           qos === 1 ? Material.color(Material.Orange) :
           Material.color(Material.Red)
    radius: 10 * scaleFactor

    Text {
        text: "QoS " + root.qos
        color: "white"
        font.pixelSize: 9
        font.bold: true
        anchors.centerIn: parent
    }
}
