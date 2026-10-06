pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Keyboard accelerator hint: a bordered key cap plus its action label. Display
// only — the shortcut itself lives where the key is handled.
RowLayout {
    id: root

    property string key: ""
    property string label: ""

    spacing: Globals.fieldPadding

    Rectangle {
        id: idKeyCap

        Layout.alignment: Qt.AlignVCenter

        implicitWidth: idKeyText.implicitWidth + 2 * Globals.fieldPadding
        implicitHeight: idKeyText.implicitHeight + 2 * Globals.hairlineHeight
        radius: Globals.pillRadius
        color: Colors.cardSecondary
        border.width: Globals.hairlineHeight
        border.color: Colors.border

        Text {
            id: idKeyText

            anchors.centerIn: parent

            textFormat: Text.PlainText
            text: root.key
            color: Colors.text

            font {
                family: Globals.fontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }
    }

    Text {
        id: idKeyLabel

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: root.label
        color: Colors.textSecondary

        font {
            family: Globals.fontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }
}
