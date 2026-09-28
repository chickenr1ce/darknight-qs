pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    readonly property real sinkGlyphWidth: Math.max(idSinkGlyphHighMetrics.advanceWidth, idSinkGlyphMuteMetrics.advanceWidth)

    ColumnLayout {
        id: idVolumeColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Repeater {
            id: idVolumeRepeater

            model: AudioService.sinks

            delegate: RowLayout {
                id: idSinkRow

                Layout.fillWidth: true

                required property var modelData

                readonly property var sinkNode: modelData.node
                readonly property int percent: AudioService.percentForVolume(idSinkRow.sinkNode.audio.volume)

                spacing: Globals.rowSpacing

                Icon {
                    id: idSinkGlyph

                    Layout.preferredWidth: root.sinkGlyphWidth
                    Layout.alignment: Qt.AlignVCenter

                    text: idSinkRow.sinkNode.audio.muted ? Icons.volumeMute : Icons.volumeHigh
                    size: Globals.uiBodySize
                    color: Colors.textSubtle
                }

                Text {
                    id: idSinkLabel

                    Layout.preferredWidth: Globals.volumeLabelWidth
                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: idSinkRow.modelData.label
                    color: idSinkRow.modelData.isDefault ? Colors.text : Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                Slider {
                    id: idSinkSlider

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    from: 0
                    to: 100
                    stepSize: 1
                    value: idSinkRow.percent
                    accessibleName: idSinkRow.modelData.label
                    onMoved: value => AudioService.setVolume(idSinkRow.sinkNode, value)
                }

                Text {
                    id: idSinkValue

                    Layout.preferredWidth: Globals.volumeValueWidth
                    Layout.alignment: Qt.AlignVCenter

                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                    text: idSinkRow.percent + "%"
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        weight: Font.Medium
                    }
                }
            }
        }

        Text {
            id: idVolumeEmpty

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            visible: AudioService.sinks.length === 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("No outputs")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }
    }

    TextMetrics {
        id: idSinkGlyphHighMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiBodySize
        text: Icons.volumeHigh
    }

    TextMetrics {
        id: idSinkGlyphMuteMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiBodySize
        text: Icons.volumeMute
    }
}
