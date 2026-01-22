import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root

    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    width: 500 * scaleFactor
    height: 400 * scaleFactor
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
        spacing: 10 * root.scaleFactor

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "MQTT Topic Filter Guide"
                font.bold: true
                font.pixelSize: 16
                Layout.fillWidth: true
            }

            Button {
                text: "✕"
                flat: true
                onClicked: root.close()
                Layout.preferredWidth: 30 * root.scaleFactor
                Layout.preferredHeight: 30 * root.scaleFactor
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: parent.parent.width
                spacing: 15 * root.scaleFactor

                GroupBox {
                    title: "Single Level Wildcard (+)"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.scaleFactor

                        Text {
                            text: "The '+' wildcard matches exactly one topic level."
                            color: Material.foreground
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: "Examples:\n• home/+/temperature → matches home/kitchen/temperature, home/bedroom/temperature\n• +/sensors/+ → matches device1/sensors/temp, device2/sensors/humidity\n• sport/+/player1 → matches sport/tennis/player1, sport/football/player1"
                            color: Material.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }

                GroupBox {
                    title: "Multi Level Wildcard (#)"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.scaleFactor

                        Text {
                            text: "The '#' wildcard matches zero or more topic levels and MUST be the last character."
                            color: Material.foreground
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: "Examples:\n• home/# → matches home/kitchen/temp, home/bedroom/light/status\n• sensors/# → matches sensors/temp, sensors/humidity/room1\n• # → matches ALL topics (use with caution!)\n• sport/tennis/# → matches sport/tennis/player1, sport/tennis/score/set1"
                            color: Material.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }

                GroupBox {
                    title: "Combined Examples"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.scaleFactor

                        Text {
                            text: "Complex patterns using both wildcards:"
                            color: Material.foreground
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }

                        Text {
                            text: "• +/+/temperature → any device, any room, temperature\n• home/+/sensors/# → home automation sensor data\n• device/+/status → status from any device\n• $SYS/broker/+/# → broker system messages"
                            color: Material.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }

                GroupBox {
                    title: "Important Notes"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8 * root.scaleFactor

                        Text {
                            text: "⚠️ Performance Considerations:"
                            color: Material.color(Material.Orange)
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "• '#' subscribes to ALL topics - can generate huge traffic!\n• Use specific patterns when possible\n• Monitor message count in high-traffic scenarios\n• Consider QoS levels for important subscriptions"
                            color: Material.foreground
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
