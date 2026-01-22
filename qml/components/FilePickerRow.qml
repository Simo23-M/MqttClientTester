import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root

    property alias label: labelText.text
    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property double scaleFactor: 1

    signal browseClicked()
    signal fieldTextChanged(string newText)

    Layout.fillWidth: true
    spacing: 10 * scaleFactor

    Label {
        id: labelText
        Layout.minimumWidth: 100 * root.scaleFactor
        color: Material.foreground
    }

    TextField {
        id: textField
        Layout.fillWidth: true
        color: "#ffffff"
        placeholderTextColor: "#808080"
        font.family: "Consolas, Monaco, monospace"

        onTextChanged: root.fieldTextChanged(text)

        background: Rectangle {
            color: "#2d2d2d"
            border.color: textField.activeFocus ? "#bb86fc" : "#404040"
            border.width: textField.activeFocus ? 2 : 1
            radius: 4
        }
    }

    Button {
        text: "Browse"
        onClicked: root.browseClicked()
    }
}
