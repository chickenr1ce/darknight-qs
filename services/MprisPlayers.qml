pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.services

Singleton {
    id: root

    readonly property var browserTokens: ["firefox", "firefox-esr", "waterfox", "floorp", "zen-browser", "chromium", "chrome", "brave", "vivaldi", "opera", "microsoft-edge", "thorium", "ladybird", "epiphany"]
    readonly property var browserExact: ["zen"]
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
        if (!player)
            return "";
        let key = (player.desktopEntry || player.identity || player.dbusName || "").toLowerCase().trim();
        const instance = key.indexOf(".instance");
        if (instance !== -1)
            key = key.slice(0, instance);
        return key;
    }

    function playerLabel(player): string {
        if (!player)
            return "";
        return player.identity || player.desktopEntry || player.dbusName || "";
    }

    function defaultAllowed(key: string): bool {
        for (let i = 0; i < root.browserExact.length; i++) {
            if (key === root.browserExact[i])
                return false;
        }
        for (let i = 0; i < root.browserTokens.length; i++) {
            if (key.indexOf(root.browserTokens[i]) !== -1)
                return false;
        }
        return true;
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
        const keys = Object.keys(a);
        if (keys.length !== Object.keys(b).length)
            return false;
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            if (!(key in b))
                return false;
            if ((a[key].allowed !== false) !== (b[key].allowed !== false))
                return false;
            if (a[key].label !== b[key].label)
                return false;
        }
        return true;
    }

    function parseApps(jsonText: string): var {
        const out = {};
        let parsed = null;
        try {
            parsed = JSON.parse(jsonText);
        }
        catch (e)
        {
            return out;
        }
        if (!parsed || typeof parsed !== "object" || !parsed.apps || typeof parsed.apps !== "object")
            return out;
        const stored = parsed.apps;
        for (const key in stored) {
            const entry = stored[key];
            if (!entry || typeof entry !== "object")
                continue;
            const item = {};
            item["label"] = typeof entry.label === "string" && entry.label !== "" ? entry.label : key;
            item["allowed"] = entry.allowed !== false;
            out[key.toLowerCase()] = item;
        }
        return out;
    }

    function applyApps(jsonText: string): void {
        const stored = root.parseApps(jsonText);
        const current = root.apps;
        for (const key in current) {
            if (!(key in stored))
                stored[key] = current[key];
        }
        if (!root.sameApps(current, stored))
            root.apps = stored;
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
