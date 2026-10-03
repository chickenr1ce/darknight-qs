pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> playerList: Mpris.players.values
    property int activeIndex: 0
    readonly property MprisPlayer activePlayer: playerList.length > 0 ? playerList[activeIndex] : null
    readonly property string playerName: activePlayer?.identity ?? ""

    onPlayerListChanged: {
        if (!playerList || playerList.length === 0) {
            activeIndex = 0;
            return;
        }
        if (playerName !== "") {
            const index = playerList.findIndex(item => item && item.identity === playerName);
            activeIndex = index !== -1 ? index : 0;
        } else {
            activeIndex = 0;
        }
    }

    onActivePlayerChanged: {
        if (activePlayer) {
            activePlayer.positionChanged();
        }
    }
    readonly property real percentageProgress: {
        if (!activePlayer || !activePlayer.lengthSupported || activePlayer.length <= 0)
            return 0;
        return activePlayer.position / activePlayer.length;
    }

    function selectPlayer(x: int) {
        if (!playerList || playerList.length === 0) {
            activeIndex = 0;
            return;
        }
        activeIndex = (activeIndex + x + playerList.length) % playerList.length;
    }

    function nextLoopState(current: int): int {
        if (current === MprisLoopState.Playlist)
            return MprisLoopState.Track;
        if (current === MprisLoopState.Track)
            return MprisLoopState.None;
        return MprisLoopState.Playlist;
    }

    function cycleRepeat(): void {
        const player = root.activePlayer;
        if (!player || !player.loopSupported)
            return;
        player.loopState = root.nextLoopState(player.loopState);
    }

    function toggleShuffle(): void {
        const player = root.activePlayer;
        if (!player || !player.shuffleSupported)
            return;
        player.shuffle = !player.shuffle;
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(total / 60);
        const secs = total % 60;
        return minutes + ":" + (secs < 10 ? "0" : "") + secs;
    }

    FrameAnimation {
        id: idMprisFrameAnimation

        running: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
        onTriggered: if (root.activePlayer) {
            root.activePlayer.positionChanged();
        }
    }
}
