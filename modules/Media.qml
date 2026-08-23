import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Media player module using MprisPlayers singleton service.
// Click toggles play/pause. Wheel scroll cycles active player.
// "Playing" state inverts the module colors like waybar.
ModuleBox {
    id: root

    readonly property MprisPlayer activePlayer: MprisPlayers.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing || Boolean(activePlayer?.isPlaying)

    maxWidth: 360
    visible: activePlayer !== null
    color: root.isPlaying ? Colors.lavender : Colors.background

    onClicked: {
        if (!root.activePlayer)
            return;
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
        //Layout.minimumWidth: 0
        elide: Text.ElideRight

        color: root.isPlaying ? Colors.background : Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold

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
