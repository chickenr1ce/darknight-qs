pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services

// Shared volume row: optional mute button, slider, and reserved-width percent.
// Driven by a PwNode; a null node or null audio stays laid out with the
// controls disabled, so a row never reflows as the graph reconnects.
// `trailingMute` moves the mute button after the value, and `dimmed` greys the
// slider without disabling it, for a muted stream that stays adjustable.
RowLayout {
    id: root

    property PwNode node: null
    property bool showMute: true
    property bool micGlyphs: false
    property bool trailingMute: false
    property bool dimmed: false
    property string accessibleName: ""

    readonly property var audioNode: root.node ? (root.node.audio ?? null) : null
    readonly property bool hasAudio: Boolean(root.audioNode)
    readonly property int percent: AudioService.percentForVolume(root.hasAudio ? root.audioNode.volume : 0)
    readonly property string muteGlyph: AudioService.volumeGlyph(root.audioNode, root.micGlyphs)
    readonly property string muteAccessibleName: {
        if (root.accessibleName === "")
            return qsTr("Toggle mute");
        return qsTr("Mute") + " " + root.accessibleName;
    }
    readonly property real muteSlotWidth: {
        const glyph = Math.max(
            idMuteOnMetrics.advanceWidth,
            idMuteMutedMetrics.advanceWidth,
            idMuteOffMetrics.advanceWidth
        );
        return Math.max(Globals.uiBodySize, glyph) + 2 * Globals.iconButtonPadding;
    }
    // The slider track, inset by the handle radius, so a meter can line up with it.
    readonly property real trackX: idVolumeSlider.x + idVolumeSlider.handleRadius
    readonly property real trackWidth: Math.max(0, idVolumeSlider.width - 2 * idVolumeSlider.handleRadius)

    spacing: Globals.rowSpacing

    IconButton {
        id: idVolumeMuteLead

        Layout.preferredWidth: root.muteSlotWidth
        Layout.alignment: Qt.AlignVCenter

        visible: root.showMute && !root.trailingMute
        disabled: !root.hasAudio
        glyph: root.muteGlyph
        accessibleName: root.muteAccessibleName
        onClicked: AudioService.toggleMute(root.node)
    }

    Slider {
        id: idVolumeSlider

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignVCenter

        from: 0
        to: 100
        stepSize: 1
        value: root.percent
        disabled: !root.hasAudio
        dimmed: root.dimmed
        accessibleName: root.accessibleName
        onMoved: value => AudioService.setVolume(root.node, value)
    }

    Text {
        id: idVolumeValue

        Layout.preferredWidth: Globals.volumeValueWidth
        Layout.alignment: Qt.AlignVCenter

        horizontalAlignment: Text.AlignRight
        textFormat: Text.PlainText
        text: AudioService.percentText(root.hasAudio ? root.audioNode.volume : 0) + "%"
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
            weight: Font.Medium
            features: ({ "tnum": 1 })
        }
    }

    IconButton {
        id: idVolumeMuteTrail

        Layout.preferredWidth: root.muteSlotWidth
        Layout.alignment: Qt.AlignVCenter

        visible: root.showMute && root.trailingMute
        disabled: !root.hasAudio
        glyph: root.muteGlyph
        accessibleName: root.muteAccessibleName
        onClicked: AudioService.toggleMute(root.node)
    }

    TextMetrics {
        id: idMuteOnMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiBodySize
        text: root.micGlyphs ? Icons.mic : Icons.volumeHigh
    }

    TextMetrics {
        id: idMuteMutedMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiBodySize
        text: root.micGlyphs ? Icons.micOff : Icons.volumeMute
    }

    TextMetrics {
        id: idMuteOffMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.uiBodySize
        text: root.micGlyphs ? Icons.micOff : Icons.volumeOff
    }
}
