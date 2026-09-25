pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    ColumnLayout {
        id: idVolumeColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Text {
            id: idVolumeTitle

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Volume").toUpperCase()
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        Slider {
            id: idVolumeStub

            Layout.fillWidth: true

            from: 0
            to: 100
            value: 50
            disabled: true
            accessibleName: qsTr("Volume")
        }
    }
}
