import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../utils/PayloadFormatter.js" as Formatter

Rectangle {
    id: root

    property string topic: ""
    property string segment: ""
    property string message: ""
    property string timestamp: ""
    property bool received: true
    property string historyJson: ""
    property int itemIndex: 0
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"
    property bool mqttConnected: false
    property int level: 0
    property bool expanded: false
    property bool hasChildren: false
    property bool hasMessage: false
    property int subtopicCount: 0
    property var updateTick: 0
    property bool selected: false

    // ---- derived palette (dark Material theme) ----
    readonly property color dirColor: received ? Material.color(Material.Amber)
                                                : Material.accent
    readonly property color guideColor: Qt.rgba(Material.foreground.r, Material.foreground.g,
                                                 Material.foreground.b, 0.12)
    readonly property color hoverColor: Qt.rgba(Material.accent.r, Material.accent.g,
                                                Material.accent.b, 0.08)
    readonly property color selColor: Qt.rgba(Material.accent.r, Material.accent.g,
                                              Material.accent.b, 0.16)

    // History navigation
    property var parsedHistory: {
        if (!historyJson || historyJson === "") return []
        try { return JSON.parse(historyJson) } catch(e) { return [] }
    }
    property int historyCount: parsedHistory.length
    property int historyViewIndex: 0  // 0 = latest (current message), 1+ = history items

    property string displayedMessage: {
        if (historyViewIndex === 0) return root.message
        var idx = historyViewIndex - 1
        if (idx >= 0 && idx < parsedHistory.length) {
            return parsedHistory[parsedHistory.length - 1 - idx].message || ""
        }
        return root.message
    }
    property string displayedTimestamp: {
        if (historyViewIndex === 0) return root.timestamp
        var idx = historyViewIndex - 1
        if (idx >= 0 && idx < parsedHistory.length) {
            return parsedHistory[parsedHistory.length - 1 - idx].timestamp || ""
        }
        return root.timestamp
    }

    property string detectedFormat: displayedMessage ? Formatter.detectFormat(displayedMessage) : "raw"
    property string formattedMessage: {
        if (!displayedMessage) return ""
        if (detectedFormat === "json") {
            var result = Formatter.beautifyJson(displayedMessage)
            if (typeof result === "object" && result.error) return displayedMessage
            return result
        }
        return displayedMessage
    }

    onMessageChanged: historyViewIndex = 0

    property bool _initialized: false
    Component.onCompleted: _initialized = true

    onUpdateTickChanged: {
        if (_initialized && updateTick > 0) {
            flashAnimation.restart()
        }
    }

    signal clicked()
    signal deleteRetainedClicked(string topic)
    signal useAsPublishTopic(string topic)
    signal useAsSubscribeTopic(string topic)
    signal toggleExpand()

    // ---- geometry ----
    readonly property real rowIndent: 8 * scaleFactor + root.level * 18 * scaleFactor
    width: parent ? parent.width : 200
    height: root.hasMessage
            ? Math.max(contentCol.implicitHeight + 14 * scaleFactor, 52 * scaleFactor)
            : 30 * scaleFactor

    // flat background: no per-row border, no zebra — just hover / selection
    color: mouseArea.containsMouse ? hoverColor
                                    : (root.selected ? selColor : "transparent")
    Behavior on color { ColorAnimation { duration: 90 } }

    // hairline row separator (very subtle)
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.rgba(Material.foreground.r, Material.foreground.g, Material.foreground.b, 0.05)
    }

    // ---- indentation guide lines (drawn behind content) ----
    Item {
        id: guideContainer
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        anchors.leftMargin: 4 * root.scaleFactor
        width: root.level * 18 * root.scaleFactor
        Repeater {
            model: root.level
            delegate: Rectangle {
                required property int index
                x: index * 18 * root.scaleFactor + 9 * root.scaleFactor
                width: 1
                anchors.top: guideContainer.top
                anchors.bottom: guideContainer.bottom
                color: root.guideColor
            }
        }
    }

    // ---- left direction stripe (leaves only) ----
    Rectangle {
        id: stripe
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3 * root.scaleFactor
        color: root.dirColor
        visible: root.hasMessage
    }

    // ---- content ----
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.rowIndent
        anchors.rightMargin: 8 * root.scaleFactor
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        spacing: 6 * root.scaleFactor

        // expand / collapse chevron (fixed slot so segments align)
        Item {
            Layout.preferredWidth: 16 * root.scaleFactor
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true

            Text {
                id: chevron
                anchors.centerIn: parent
                text: "▶"
                color: Material.foreground
                opacity: 0.55
                font.pixelSize: 9 * root.scaleFactor
                visible: root.hasChildren
                rotation: root.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: root.hasChildren
                onClicked: root.toggleExpand()
            }
        }

        ColumnLayout {
            id: contentCol
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: root.hasMessage ? 3 * root.scaleFactor : 0

            // header row: segment name + badges + timestamp
            RowLayout {
                Layout.fillWidth: true
                spacing: 6 * root.scaleFactor

                Text {
                    id: topicText
                    text: root.segment
                    color: root.hasMessage ? Material.accent : Material.foreground
                    opacity: root.hasMessage ? 1.0 : 0.9
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: root.hasMessage || root.hasChildren
                    Layout.fillWidth: true
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                // subtopic count pill (branches)
                Rectangle {
                    visible: root.hasChildren && root.subtopicCount > 0
                    color: Qt.rgba(Material.foreground.r, Material.foreground.g, Material.foreground.b, 0.10)
                    radius: height / 2
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.subtopicCount
                        color: Material.foreground
                        opacity: 0.75
                        font.pixelSize: 10
                    }
                }

                // format pill (JSON / XML) — tinted, not solid
                Rectangle {
                    visible: root.hasMessage && root.detectedFormat !== "raw"
                    property color tint: root.detectedFormat === "json"
                                         ? Material.color(Material.Teal) : Material.color(Material.Purple)
                    color: Qt.rgba(tint.r, tint.g, tint.b, 0.20)
                    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.55)
                    border.width: 1
                    radius: height / 2
                    implicitWidth: formatBadgeText.implicitWidth + 12
                    implicitHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        id: formatBadgeText
                        anchors.centerIn: parent
                        text: root.detectedFormat.toUpperCase()
                        color: parent.tint
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                // history count pill — tinted
                Rectangle {
                    visible: root.hasMessage && root.historyCount > 0
                    property color tint: Material.color(Material.DeepOrange)
                    color: Qt.rgba(tint.r, tint.g, tint.b, 0.20)
                    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.55)
                    border.width: 1
                    radius: height / 2
                    implicitWidth: historyCountText.implicitWidth + 12
                    implicitHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                        id: historyCountText
                        anchors.centerIn: parent
                        text: "↺ " + root.historyCount
                        color: parent.tint
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Text {
                    text: root.displayedTimestamp
                    color: Material.foreground
                    font.pixelSize: 10
                    opacity: 0.55
                    visible: root.hasMessage
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // message preview — monospace, dimmed
            Text {
                id: messageText
                text: root.formattedMessage
                color: Material.foreground
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: root.hasMessage
            }

            // history navigation
            RowLayout {
                Layout.fillWidth: true
                visible: root.hasMessage && root.historyCount > 0
                spacing: 4 * root.scaleFactor

                Button {
                    text: "◀"
                    flat: true
                    font.pixelSize: 10
                    implicitWidth: 24 * root.scaleFactor
                    implicitHeight: 20 * root.scaleFactor
                    enabled: root.historyViewIndex < root.historyCount
                    onClicked: root.historyViewIndex++
                }

                Text {
                    text: root.historyViewIndex === 0 ? "latest" : ("-%1 of %2".arg(root.historyViewIndex).arg(root.historyCount + 1))
                    color: Material.foreground
                    font.pixelSize: 9
                    opacity: 0.7
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    text: "▶"
                    flat: true
                    font.pixelSize: 10
                    implicitWidth: 24 * root.scaleFactor
                    implicitHeight: 20 * root.scaleFactor
                    enabled: root.historyViewIndex > 0
                    onClicked: root.historyViewIndex--
                }
            }
        }

        // delete retained button — only on hover, flat & subtle
        Button {
            id: deleteButton
            flat: true
            text: "🗑️"
            font.pixelSize: 13
            implicitWidth: 30 * root.scaleFactor
            implicitHeight: 30 * root.scaleFactor
            Layout.alignment: Qt.AlignVCenter
            opacity: (mouseArea.containsMouse || hovered) ? 1 : 0
            enabled: root.mqttConnected && root.hasMessage
            visible: root.mqttConnected && root.hasMessage
            onClicked: root.deleteRetainedClicked(root.topic)
            ToolTip.visible: hovered
            ToolTip.text: "Delete retained message"
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.rightMargin: deleteButton.visible ? deleteButton.width + 12 * root.scaleFactor : 0
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (root.hasMessage) {
                    contextMenu.popup()
                }
            } else {
                if (root.hasChildren) {
                    root.toggleExpand()
                } else if (root.hasMessage) {
                    root.clicked()
                }
            }
        }
    }

    // Flash overlay for new message highlight — subtle accent glow
    Rectangle {
        id: flashOverlay
        anchors.fill: parent
        color: Material.accent
        opacity: 0
        z: 10

        SequentialAnimation {
            id: flashAnimation
            NumberAnimation { target: flashOverlay; property: "opacity"; from: 0; to: 0.28; duration: 90 }
            NumberAnimation { target: flashOverlay; property: "opacity"; from: 0.28; to: 0; duration: 550; easing.type: Easing.OutCubic }
        }
    }

    Menu {
        id: contextMenu
        MenuItem {
            text: "Use as Publish Topic"
            onTriggered: root.useAsPublishTopic(root.topic)
        }
        MenuItem {
            text: "Use as Subscribe Topic"
            onTriggered: root.useAsSubscribeTopic(root.topic)
        }
    }
}
