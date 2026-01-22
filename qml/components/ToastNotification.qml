import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string message: ""
    property string type: "info" // "info", "success", "warning", "error"
    property int duration: 3000
    property double scaleFactor: 1

    signal dismissed()

    width: Math.min(toastText.implicitWidth + 40 * scaleFactor, 400 * scaleFactor)
    height: 50 * scaleFactor
    radius: 8

    color: {
        switch(type) {
            case "success": return Material.color(Material.Green)
            case "warning": return Material.color(Material.Orange)
            case "error": return Material.color(Material.Red)
            default: return Material.color(Material.Blue)
        }
    }

    opacity: 0
    visible: opacity > 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10 * root.scaleFactor
        spacing: 10 * root.scaleFactor

        Text {
            text: {
                switch(root.type) {
                    case "success": return "✓"
                    case "warning": return "⚠"
                    case "error": return "✕"
                    default: return "ℹ"
                }
            }
            font.pixelSize: 16
            font.bold: true
            color: "white"
        }

        Text {
            id: toastText
            text: root.message
            color: "white"
            font.pixelSize: 13
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        MouseArea {
            width: 20 * root.scaleFactor
            height: 20 * root.scaleFactor
            onClicked: hide()

            Text {
                text: "✕"
                color: "white"
                font.pixelSize: 12
                anchors.centerIn: parent
            }
        }
    }

    Timer {
        id: hideTimer
        interval: root.duration
        onTriggered: hide()
    }

    NumberAnimation {
        id: showAnimation
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: hideAnimation
        target: root
        property: "opacity"
        from: 1
        to: 0
        duration: 200
        easing.type: Easing.InQuad
        onFinished: root.dismissed()
    }

    function show(msg, msgType) {
        message = msg
        type = msgType || "info"
        showAnimation.start()
        hideTimer.start()
    }

    function hide() {
        hideTimer.stop()
        hideAnimation.start()
    }
}
