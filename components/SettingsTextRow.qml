pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property string value: ""

    signal edited(string text)

    spacing: Globals.spacing

    Text {
        id: idTextLabel

        Layout.fillWidth: true

        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: root.label
        color: Colors.text

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
        }
    }

    Rectangle {
        id: idTextField

        Layout.fillWidth: true
        Layout.preferredHeight: idTextInput.implicitHeight + 2 * Globals.fieldPadding

        radius: Globals.pillRadius
        color: Colors.cardSecondary
        border.width: Globals.hairlineHeight
        border.color: idTextInput.activeFocus ? Colors.accent : Colors.border

        TextInput {
            id: idTextInput

            anchors.fill: parent
            anchors.margins: Globals.fieldPadding

            clip: true
            color: Colors.text
            selectByMouse: true

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }

            onEditingFinished: {
                root.edited(idTextInput.text);
                idTextInput.focus = false;
            }
        }

        Binding {
            target: idTextInput
            property: "text"
            value: root.value
            when: !idTextInput.activeFocus
            restoreMode: Binding.RestoreNone
        }
    }

    Text {
        id: idTextHint

        Layout.fillWidth: true

        visible: root.hint !== ""
        textFormat: Text.PlainText
        text: root.hint
        color: Colors.textSubtle
        wrapMode: Text.WordWrap

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }
}
