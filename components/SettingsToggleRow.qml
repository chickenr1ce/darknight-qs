pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property bool value: false

    signal toggled()

    spacing: Globals.spacing

    RowLayout {
        id: idToggleRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idToggleLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.label
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        PillButton {
            id: idToggleButton

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idToggleMetrics.width + 2 * Globals.pillHPadding

            highlighted: root.value
            text: root.value ? qsTr("On") : qsTr("Off")
            onClicked: root.toggled()
        }
    }

    Text {
        id: idToggleHint

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

    TextMetrics {
        id: idToggleMetrics

        text: qsTr("Off")

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiPillSize
            weight: Font.Medium
        }
    }
}
