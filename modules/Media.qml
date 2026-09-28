import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Media player: left-click toggles play/pause, right-click next track, middle-click previous track; wheel cycles players; state shows in text color only (the slab forbids module backgrounds).
ModuleBox {
    id: root

    property string monitorName: ""

    readonly property MprisPlayer activePlayer: MprisPlayers.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing || Boolean(activePlayer?.isPlaying)

    maxWidth: 360
    visible: BarVisibilityService.isVisible("media") && Globals.onPrimaryMonitor(root.monitorName) && activePlayer !== null

    onClicked: mouse => {
        if (!root.activePlayer)
            return;
        if (mouse.button === Qt.RightButton) {
            if (root.activePlayer.canGoNext)
                root.activePlayer.next();
            return;
        }
        if (mouse.button === Qt.MiddleButton) {
            if (root.activePlayer.canGoPrevious)
                root.activePlayer.previous();
            return;
        }
        if (root.activePlayer.togglePlaying)
            root.activePlayer.togglePlaying();
        else if (root.activePlayer.playPause)
            root.activePlayer.playPause();
    }

    onWheelMoved: wheel => {
        if (wheel.angleDelta.y > 0) {
            MprisPlayers.selectPlayer(-1);
        } else if (wheel.angleDelta.y < 0) {
            MprisPlayers.selectPlayer(1);
        }
    }

    readonly property string statusGlyph: {
        if (!root.activePlayer)
            return Icons.stop;
        if (root.isPlaying)
            return Icons.play;
        if (root.activePlayer.playbackState === MprisPlaybackState.Paused)
            return Icons.pause;
        return Icons.stop;
    }

    readonly property string trackText: {
        if (!root.activePlayer)
            return "";
        const title = root.activePlayer.trackTitle ?? "";
        const artist = root.activePlayer.trackArtist ?? "";
        return artist ? (title ? `${title} - ${artist}` : artist) : title;
    }

    RowLayout {
        id: idMediaRow

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        spacing: 4

        Icon {
            Layout.alignment: Qt.AlignVCenter
            text: Icons.music
            size: Globals.fontPixelSize
            color: root.isPlaying ? Colors.lavender : Colors.textSecondary
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter
            text: root.statusGlyph
            size: Globals.fontPixelSize
            color: root.isPlaying ? Colors.lavender : Colors.textSecondary
        }

        Text {
            id: idMediaLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            visible: root.trackText !== ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.trackText
            color: root.isPlaying ? Colors.lavender : Colors.textSecondary

            font {
                family: Globals.fontFamily
                pixelSize: Globals.fontPixelSize
                weight: Font.DemiBold
            }
        }
    }
}
