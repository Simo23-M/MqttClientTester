import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

Button {
    id: root

    property color buttonColor: Material.primary

    implicitHeight: 36
    font.pixelSize: 13

    Material.background: buttonColor

    contentItem: Text {
        text: root.text
        font: root.font
        color: root.enabled ? "white" : "#808080"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
