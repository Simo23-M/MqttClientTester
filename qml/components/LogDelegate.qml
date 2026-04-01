import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property string timestamp: ""
    property string category: ""
    property string level: ""
    property string message: ""
    property string topic: ""
    property string payload: ""
    property string direction: ""
    property int qos: -1
    property int itemIndex: 0
    property bool verbose: false
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    width: ListView.view ? ListView.view.width : 200
    implicitHeight: contentLayout.implicitHeight + 10 * scaleFactor

    readonly property color categoryColor: {
        switch(category) {
            case "connection": return Material.color(Material.Green)
            case "subscription": return Material.color(Material.Blue)
            case "publish": return Material.color(Material.Blue)
            case "receive": return Material.color(Material.Orange)
            case "error": return Material.color(Material.Red)
            case "tls": return Material.color(Material.Cyan)
            case "queue": return Material.color(Material.Purple)
            default: return Material.color(Material.Grey)
        }
    }

    readonly property color levelColor: {
        switch(level) {
            case "error": return Material.color(Material.Red)
            case "warning": return Material.color(Material.Orange)
            default: return Material.foreground
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.itemIndex % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
    }

    RowLayout {
        id: contentLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 5 * root.scaleFactor
        spacing: 6 * root.scaleFactor

        // Direction arrow
        Text {
            text: root.direction === "in" ? "\u2190" : root.direction === "out" ? "\u2192" : " "
            color: root.direction === "in" ? Material.color(Material.Orange) : Material.color(Material.Cyan)
            font.pixelSize: 12
            font.bold: true
            Layout.preferredWidth: 14 * root.scaleFactor
            horizontalAlignment: Text.AlignHCenter
        }

        // Category badge
        Rectangle {
            color: root.categoryColor
            radius: 3
            implicitWidth: categoryText.implicitWidth + 8
            implicitHeight: categoryText.implicitHeight + 4

            Text {
                id: categoryText
                anchors.centerIn: parent
                text: root.category || "system"
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }

        // Timestamp
        Text {
            text: root.timestamp
            color: Material.foreground
            font.family: root.fontFamily
            font.pixelSize: 11
            opacity: 0.6
            Layout.preferredWidth: 80 * root.scaleFactor
        }

        // Message + topic
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: root.message
                color: root.levelColor
                font.family: root.fontFamily
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Text {
                text: root.topic
                color: Material.accent
                font.family: root.fontFamily
                font.pixelSize: 10
                opacity: 0.7
                visible: root.topic !== "" && !root.verbose
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: root.verbose && (root.topic !== "" || root.payload !== "")
                text: (root.topic !== "" ? "topic=" + root.topic : "")
                      + (root.topic !== "" && root.payload !== "" ? "  " : "")
                      + (root.payload !== "" ? "payload=" + root.payload : "")
                      + (root.qos >= 0 ? "  qos=" + root.qos : "")
                color: Material.foreground
                font.family: root.fontFamily
                font.pixelSize: 10
                opacity: 0.5
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
        }
    }
}
