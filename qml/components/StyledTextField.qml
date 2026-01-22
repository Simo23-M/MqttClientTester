import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

TextField {
    id: root

    implicitHeight: 40
    color: "#ffffff"
    placeholderTextColor: "#808080"
    font.family: "Consolas, Monaco, monospace"

    background: Rectangle {
        color: "#2d2d2d"
        border.color: root.activeFocus ? "#bb86fc" : "#404040"
        border.width: root.activeFocus ? 2 : 1
        radius: 4
    }
}
