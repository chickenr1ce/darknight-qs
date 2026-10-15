.pragma library

const BROWSER_TOKENS = ["firefox", "firefox-esr", "waterfox", "floorp", "zen-browser", "chromium", "chrome", "brave", "vivaldi", "opera", "microsoft-edge", "thorium", "ladybird", "epiphany"]
const BROWSER_EXACT = ["zen"]
const VOLUME_SYNC_KEYS = ["spotify"]

function playerKey(player) {
    if (!player)
        return "";
    let key = (player.desktopEntry || player.identity || player.dbusName || "").toLowerCase().trim();
    const instance = key.indexOf(".instance");
    if (instance !== -1)
        key = key.slice(0, instance);
    return key;
}

function defaultAllowed(key) {
    for (let i = 0; i < BROWSER_EXACT.length; i++) {
        if (key === BROWSER_EXACT[i])
            return false;
    }
    for (let i = 0; i < BROWSER_TOKENS.length; i++) {
        if (key.indexOf(BROWSER_TOKENS[i]) !== -1)
            return false;
    }
    return true;
}

function volumeSyncStreamKey(node) {
    if (!node || !node.isStream)
        return "";
    const properties = node.properties || {};
    const name = properties["application.name"] || properties["application.process.binary"] || node.name || "";
    const key = String(name).toLowerCase().trim();
    return VOLUME_SYNC_KEYS.indexOf(key) === -1 ? "" : key;
}

function playerSyncKeys(player) {
    if (!player)
        return [];
    const bus = String(player.dbusName || "").toLowerCase().replace("org.mpris.mediaplayer2.", "");
    const instance = bus.indexOf(".instance");
    const names = [playerKey(player), String(player.identity || "").toLowerCase().trim(), instance === -1 ? bus : bus.slice(0, instance)];
    return names.filter(name => name !== "");
}

function syncedPlayerFor(node, players) {
    const key = volumeSyncStreamKey(node);
    if (key === "")
        return null;
    const list = players || [];
    for (let i = 0; i < list.length; i++) {
        if (playerSyncKeys(list[i]).indexOf(key) !== -1)
            return list[i];
    }
    return null;
}

function parseApps(jsonText) {
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

function sameApps(a, b) {
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

function mergeApps(stored, current) {
    for (const key in current) {
        if (!(key in stored))
            stored[key] = current[key];
    }
    return stored;
}

function formatTime(seconds) {
    const total = Math.max(0, Math.floor(Number(seconds) || 0));
    const minutes = Math.floor(total / 60);
    const secs = total % 60;
    return minutes + ":" + (secs < 10 ? "0" : "") + secs;
}

function nextLoopState(current, states) {
    if (current === states.Playlist)
        return states.Track;
    if (current === states.Track)
        return states.None;
    return states.Playlist;
}
