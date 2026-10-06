pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property bool value: false
    property bool locked: false

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
            locked: root.locked
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

        onTextChanged: idHintSwapAnimation.restart()

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    ParallelAnimation {
        id: idHintSwapAnimation

        NumberAnimation {
            target: idToggleHint
            property: "opacity"
            from: 0
            to: 1
            duration: Globals.reducedMotion ? 0 : Globals.hoverMs
        }
        NumberAnimation {
            target: idToggleHint
            property: "scale"
            from: 0.97
            to: 1
            duration: Globals.reducedMotion ? 0 : Globals.hoverMs
            easing.type: Easing.OutCubic
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
