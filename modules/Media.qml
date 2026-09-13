import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Media player: left-click toggles play/pause, right-click next track, middle-click previous track; wheel cycles players; state shows in text color only (the slab forbids module backgrounds).
ModuleBox {
    id: root

    readonly property MprisPlayer activePlayer: MprisPlayers.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing || Boolean(activePlayer?.isPlaying)

    maxWidth: 360
    visible: activePlayer !== null

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

    Text {
        id: idMediaLabel

        Layout.fillWidth: true

        textFormat: Text.PlainText
        elide: Text.ElideRight

        color: root.isPlaying ? Colors.lavender : Colors.textSecondary

        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }

        text: {
            if (!root.activePlayer)
                return "";

            let statusIcon = "⏹";
            if (root.isPlaying) {
                statusIcon = "▶";
            } else if (root.activePlayer.playbackState === MprisPlaybackState.Paused) {
                statusIcon = "⏸";
            }

            const title = root.activePlayer.trackTitle ?? "";
            const artist = root.activePlayer.trackArtist ?? "";
            const trackInfo = artist ? (title ? `${title} - ${artist}` : artist) : title;
            return trackInfo ? ` ${statusIcon} ${trackInfo}` : ` ${statusIcon}`;
        }
    }
}
