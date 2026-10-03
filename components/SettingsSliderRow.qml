pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property bool disabled: false

    signal moved(real value)

    spacing: Globals.spacing

    RowLayout {
        id: idSliderRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idSliderLabel

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

        Text {
            id: idSliderValue

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idSliderValueMetrics.width

            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: root.value
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        TextMetrics {
            id: idSliderValueMetrics

            text: String(root.to)

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }
    }

    Slider {
        id: idSlider

        Layout.fillWidth: true

        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        disabled: root.disabled
        accessibleName: root.label
        onMoved: newValue => root.moved(newValue)
    }

    Text {
        id: idSliderHint

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
