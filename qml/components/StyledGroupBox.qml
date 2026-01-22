import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

GroupBox {
    id: root

    Material.elevation: 2

    background: Rectangle {
        y: root.topPadding - root.bottomPadding
        width: parent.width
        height: parent.height - root.topPadding + root.bottomPadding
        color: Qt.darker(Material.backgroundColor, 1.1)
        border.color: Material.accent
        border.width: 1
        radius: 6
    }

    label: Label {
        x: root.leftPadding
        width: root.availableWidth
        text: root.title
        font.bold: true
        font.pixelSize: 13
        color: Material.accent
        elide: Text.ElideRight
    }
}
