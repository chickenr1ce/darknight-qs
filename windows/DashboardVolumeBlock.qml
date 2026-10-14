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
                readonly property var sinkAudio: idSinkRow.sinkNode ? idSinkRow.sinkNode.audio : null
                readonly property bool sinkMuted: Boolean(idSinkRow.sinkAudio) && idSinkRow.sinkAudio.muted

                spacing: Globals.rowSpacing

                Icon {
                    id: idSinkGlyph

                    Layout.preferredWidth: root.sinkGlyphWidth
                    Layout.alignment: Qt.AlignVCenter

                    text: idSinkRow.sinkMuted ? Icons.volumeMute : Icons.volumeHigh
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

                VolumeControl {
                    id: idSinkVolume

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    node: idSinkRow.sinkNode
                    showMute: false
                    accessibleName: idSinkRow.modelData.label
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
