import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property string label: ""
    property string primaryText: ""
    property string secondaryText: ""
    property color secondaryColor: Colors.textSubtle
    property string extraText: ""
    property bool extraMarked: false
    property list<real> values
    property list<real> valuesBelow
    property list<real> valuesOver
    property real maxValue: 100
    property int windowSamples: 2
    property bool live: true

    spacing: Globals.rowSpacing

    ColumnLayout {
        id: idLaneReadout

        Layout.preferredWidth: Globals.performanceGutterWidth
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignVCenter

        spacing: 0

        RowLayout {
            id: idLanePrimaryRow

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            Text {
                id: idLaneLabel

                textFormat: Text.PlainText
                text: root.label
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }

            Text {
                id: idLanePrimary

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: root.primaryText
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    features: ({ "tnum": 1 })
                }
            }
        }

        Text {
            id: idLaneSecondary

            Layout.fillWidth: true

            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.secondaryText
            color: root.secondaryColor

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                features: ({ "tnum": 1 })
            }
        }

        RowLayout {
            id: idLaneExtraRow

            Layout.fillWidth: true

            visible: root.extraText !== ""
            spacing: Globals.fieldPadding

            Item {
                id: idLaneExtraGap

                Layout.fillWidth: true
            }

            Rectangle {
                id: idLaneExtraMark

                Layout.preferredWidth: Globals.panelPadding
                Layout.preferredHeight: Globals.hairlineHeight
                Layout.alignment: Qt.AlignVCenter

                visible: root.extraMarked
                color: Colors.text
            }

            Text {
                id: idLaneExtra

                textFormat: Text.PlainText
                text: root.extraText
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    features: ({ "tnum": 1 })
                }
            }
        }
    }

    PerformanceGraph {
        id: idLaneGraph

        Layout.fillWidth: true
        Layout.preferredHeight: Globals.performanceLaneHeight

        values: root.values
        valuesBelow: root.valuesBelow
        valuesOver: root.valuesOver
        maxValue: root.maxValue
        windowSamples: root.windowSamples
        live: root.live
    }
}
