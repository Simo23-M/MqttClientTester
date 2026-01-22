import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "../components"

RowLayout {
    id: root

    property var mqttClient
    property ListModel activeSubscriptionsModel
    property ListModel mqttTreeModel
    property double scaleFactor: 1
    property string fontFamily: "Consolas, Monaco, monospace"

    signal subscribeRequested(string topic, int qos)
    signal unsubscribeRequested(string topic)
    signal setSubscribeTopicField(string topic)

    spacing: 10 * scaleFactor

    // Left panel - Topic Presets and Quick Actions
    ScrollView {
        Layout.preferredWidth: 500 * root.scaleFactor
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width - 10
            spacing: 15 * root.scaleFactor

            // Quick Subscription Presets
            GroupBox {
                title: "Quick Subscription Presets"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    Label {
                        text: "Common MQTT Topic Patterns:"
                        font.bold: true
                        color: Material.accent
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "All Topics (#)"
                            Material.background: Material.DeepPurple
                            enabled: root.mqttClient && root.mqttClient.connected
                            Layout.fillWidth: true
                            onClicked: {
                                root.subscribeRequested("#", 0)
                                root.setSubscribeTopicField("#")
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Subscribe to ALL topics (use with caution!)"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "All Sensors (+/sensors/+)"
                            Material.background: Material.Teal
                            enabled: root.mqttClient && root.mqttClient.connected
                            Layout.fillWidth: true
                            onClicked: {
                                root.subscribeRequested("+/sensors/+", 0)
                                root.setSubscribeTopicField("+/sensors/+")
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Subscribe to all sensor topics from any device"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Home Automation (home/#)"
                            Material.background: Material.Indigo
                            enabled: root.mqttClient && root.mqttClient.connected
                            Layout.fillWidth: true
                            onClicked: {
                                root.subscribeRequested("home/#", 0)
                                root.setSubscribeTopicField("home/#")
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Subscribe to all home automation topics"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Device Status (+/status)"
                            Material.background: Material.Green
                            enabled: root.mqttClient && root.mqttClient.connected
                            Layout.fillWidth: true
                            onClicked: {
                                root.subscribeRequested("+/status", 0)
                                root.setSubscribeTopicField("+/status")
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Subscribe to status messages from all devices"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "System Messages ($SYS/#)"
                            Material.background: Material.Orange
                            enabled: root.mqttClient && root.mqttClient.connected
                            Layout.fillWidth: true
                            onClicked: {
                                root.subscribeRequested("$SYS/#", 0)
                                root.setSubscribeTopicField("$SYS/#")
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Subscribe to broker system messages"
                        }
                    }
                }
            }

            // Custom Topic Builder
            GroupBox {
                title: "Custom Topic Builder"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    Label {
                        text: "Build custom topic patterns:"
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: customTopicField
                            placeholderText: "device/+/sensors/#"
                            Layout.fillWidth: true
                        }
                        Button {
                            text: "Add to Field"
                            enabled: customTopicField.text.length > 0
                            onClicked: {
                                root.setSubscribeTopicField(customTopicField.text)
                                customTopicField.clear()
                            }
                        }
                    }

                    Label {
                        text: "Wildcards Help:"
                        font.bold: true
                        color: Material.accent
                    }

                    Text {
                        text: "• '+' : Single level wildcard (device/+/temp)\n• '#' : Multi-level wildcard (sensors/#)\n• Mix them: home/+/sensors/#"
                        color: Material.foreground
                        font.family: root.fontFamily
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Bulk Actions
            GroupBox {
                title: "Bulk Actions"
                Layout.fillWidth: true
                Material.elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10 * root.scaleFactor

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Unsubscribe All"
                            Material.background: Material.Red
                            enabled: root.mqttClient && root.mqttClient.connected && root.activeSubscriptionsModel.count > 0
                            Layout.fillWidth: true
                            onClicked: {
                                for (var i = 0; i < root.activeSubscriptionsModel.count; i++) {
                                    var topic = root.activeSubscriptionsModel.get(i).topic
                                    root.mqttClient.unsubscribe(topic)
                                }
                                root.activeSubscriptionsModel.clear()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Clear All Messages"
                            Material.background: Material.DeepOrange
                            Layout.fillWidth: true
                            onClicked: root.mqttTreeModel.clear()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // Right panel - Active Subscriptions
    GroupBox {
        title: "Active Subscriptions"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Material.elevation: 2

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Active: " + root.activeSubscriptionsModel.count
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "Refresh Status"
                    enabled: root.mqttClient && root.mqttClient.connected
                    onClicked: {
                        for (var i = 0; i < root.activeSubscriptionsModel.count; i++) {
                            var sub = root.activeSubscriptionsModel.get(i)
                            // Log current subscriptions
                        }
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: activeSubscriptionsView
                    model: root.activeSubscriptionsModel

                    delegate: Rectangle {
                        width: activeSubscriptionsView.width
                        height: 60 * root.scaleFactor
                        color: index % 2 === 0 ? Material.background : Qt.darker(Material.background, 1.1)
                        border.color: Material.accent
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10 * root.scaleFactor
                            spacing: 10 * root.scaleFactor

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5 * root.scaleFactor

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.topic
                                        color: Material.accent
                                        font.family: root.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                    }

                                    QosBadge {
                                        qos: model.qos
                                        scaleFactor: root.scaleFactor
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Subscribed at: " + model.timestamp
                                        color: Material.foreground
                                        font.pixelSize: 10
                                        opacity: 0.7
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        text: "Unsubscribe"
                                        Material.background: Material.Red
                                        enabled: root.mqttClient && root.mqttClient.connected
                                        font.pixelSize: 10
                                        implicitHeight: 25 * root.scaleFactor
                                        implicitWidth: 80 * root.scaleFactor
                                        onClicked: {
                                            root.mqttClient.unsubscribe(model.topic)
                                            root.activeSubscriptionsModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        // Visual indicator for wildcard topics
                        Rectangle {
                            width: 4 * root.scaleFactor
                            height: parent.height
                            anchors.left: parent.left
                            color: model.topic.includes('+') || model.topic.includes('#') ?
                                   Material.color(Material.Purple) : Material.color(Material.Blue)
                        }
                    }

                    // Empty state
                    EmptyStateView {
                        visible: root.activeSubscriptionsModel.count === 0
                        width: activeSubscriptionsView.width
                        height: 100 * root.scaleFactor
                        icon: "📭"
                        title: "No active subscriptions"
                        scaleFactor: root.scaleFactor
                    }
                }
            }
        }
    }
}
