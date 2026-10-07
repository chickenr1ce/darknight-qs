pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.services
import "MprisLogic.js" as MprisLogic

Singleton {
    id: root

    readonly property var loopStates: {
        const states = {};
        states["None"] = MprisLoopState.None;
        states["Track"] = MprisLoopState.Track;
        states["Playlist"] = MprisLoopState.Playlist;
        return states;
    }
    property var apps: ({})
    property int activeIndex: 0

    readonly property var playerList: Mpris.players.values.filter(player => root.isAllowed(player))
    readonly property var seenPlayers: {
        const out = [];
        const seen = {};
        const apps = root.apps;
        for (const key in apps) {
            const entry = {};
            entry["key"] = key;
            entry["label"] = apps[key].label;
            entry["allowed"] = apps[key].allowed !== false;
            out.push(entry);
            seen[key] = true;
        }
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            const key = root.playerKey(players[i]);
            if (key === "" || seen[key])
                continue;
            out.push(root.entryFor(players[i]));
        }
        return out;
    }
    readonly property MprisPlayer activePlayer: playerList.length > 0 ? playerList[Math.min(activeIndex, playerList.length - 1)] : null
    readonly property string playerName: activePlayer?.identity ?? ""

    onAppsChanged: root.saveApps()

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

    Component.onCompleted: root.rememberPlayers()

    function playerKey(player): string {
        return MprisLogic.playerKey(player);
    }

    function playerLabel(player): string {
        if (!player)
            return "";
        return player.identity || player.desktopEntry || player.dbusName || "";
    }

    function defaultAllowed(key: string): bool {
        return MprisLogic.defaultAllowed(key);
    }

    function entryFor(player): var {
        const key = root.playerKey(player);
        const entry = {};
        entry["key"] = key;
        entry["label"] = root.playerLabel(player);
        entry["allowed"] = root.defaultAllowed(key);
        return entry;
    }

    function isAllowed(player): bool {
        const key = root.playerKey(player);
        if (key === "")
            return true;
        const entry = root.apps[key];
        if (entry)
            return entry.allowed !== false;
        return root.defaultAllowed(key);
    }

    function rememberPlayers(): void {
        const current = root.apps;
        const next = {};
        let changed = false;
        for (const key in current)
            next[key] = current[key];
        const players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            const key = root.playerKey(players[i]);
            if (key === "")
                continue;
            const label = root.playerLabel(players[i]);
            const existing = next[key];
            if (existing) {
                if (label !== "" && existing.label !== label) {
                    const entry = {};
                    entry["label"] = label;
                    entry["allowed"] = existing.allowed !== false;
                    next[key] = entry;
                    changed = true;
                }
                continue;
            }
            next[key] = root.entryFor(players[i]);
            changed = true;
        }
        if (changed)
            root.apps = next;
    }

    function setAllowed(key: string, label: string, allowed: bool): void {
        const current = root.apps;
        const existing = current[key];
        if (existing && (existing.allowed !== false) === allowed)
            return;
        const next = {};
        for (const k in current)
            next[k] = current[k];
        const entry = {};
        entry["label"] = existing && existing.label ? existing.label : label;
        entry["allowed"] = allowed;
        next[key] = entry;
        root.apps = next;
    }

    function sameApps(a, b): bool {
        return MprisLogic.sameApps(a, b);
    }

    function parseApps(jsonText: string): var {
        return MprisLogic.parseApps(jsonText);
    }

    function applyApps(jsonText: string): void {
        const current = root.apps;
        const merged = MprisLogic.mergeApps(MprisLogic.parseApps(jsonText), current);
        if (!root.sameApps(current, merged))
            root.apps = merged;
    }

    function saveApps(): void {
        if (idAppsState.loading || !idAppsState.loaded)
            return;
        const current = root.apps;
        const apps = {};
        for (const key in current) {
            const entry = {};
            entry["label"] = current[key].label;
            entry["allowed"] = current[key].allowed !== false;
            apps[key] = entry;
        }
        const payload = {};
        payload["apps"] = apps;
        idAppsState.save(JSON.stringify(payload) + "\n");
    }

    function selectPlayer(x: int) {
        if (!playerList || playerList.length === 0) {
            activeIndex = 0;
            return;
        }
        activeIndex = (activeIndex + x + playerList.length) % playerList.length;
    }

    function nextLoopState(current: int): int {
        return MprisLogic.nextLoopState(current, root.loopStates);
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
        return MprisLogic.formatTime(seconds);
    }

    StateFile {
        id: idAppsState

        name: "mpris-players"
        createDir: true
        onParsed: text => root.applyApps(text)
    }

    Connections {
        target: Mpris.players

        function onObjectInsertedPost(): void {
            root.rememberPlayers();
        }
    }

    FrameAnimation {
        id: idMprisFrameAnimation

        running: root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
        onTriggered: if (root.activePlayer) {
            root.activePlayer.positionChanged();
        }
    }
}
