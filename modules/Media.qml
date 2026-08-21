import QtQuick
import Quickshell.Services.Mpris
import "../config"
import "../components"

// First non-Firefox MPRIS player. Click toggles play/pause.
// "Playing" state inverts the module colors like waybar.
// Mpris.players is a QML model, not a JS array, so iterate by index.
ModuleBox {
    id: root

    property var activePlayer: null

    function refreshActivePlayer(): void {
        const players = Mpris.players;
        if (!players) {
            activePlayer = null;
            return;
        }
        activePlayer = null;
        for (let i = 0; i < players.count; i++) {
            const candidate = players.get(i);
            if (!(candidate.identity ?? "").toLowerCase().includes("firefox")) {
                activePlayer = candidate;
                break;
            }
        }
    }

    Component.onCompleted: refreshActivePlayer()

    Timer {
        id: idMediaTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshActivePlayer()
    }

    visible: activePlayer !== null
    color: activePlayer?.isPlaying ? Colors.lavender : Colors.background

    Text {
        id: idMediaLabel

        color: root.activePlayer?.isPlaying ? Colors.background : Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: {
            if (!root.activePlayer)
                return "";
            const statusIcon = root.activePlayer.isPlaying ? "▶" : "⏸";
            const title = root.activePlayer.trackTitle ?? "";
            const artist = root.activePlayer.trackArtist ?? "";
            return ` ${statusIcon} ${title}${artist ? ` - ${artist}` : ""}`;
        }
    }

    onClicked: activePlayer?.playPause?.()
}
