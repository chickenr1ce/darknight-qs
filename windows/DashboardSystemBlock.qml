pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    ColumnLayout {
        id: idSystemColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Repeater {
            id: idSystemRepeater

            model: [qsTr("Arch Linux"), qsTr("Hyprland"), qsTr("up 1 hour, 23 minutes")]

            delegate: Text {
                required property string modelData

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: modelData
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }
        }
    }
}
