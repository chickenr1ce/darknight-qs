.pragma library

const BROWSER_TOKENS = ["firefox", "firefox-esr", "waterfox", "floorp", "zen-browser", "chromium", "chrome", "brave", "vivaldi", "opera", "microsoft-edge", "thorium", "ladybird", "epiphany"]
const BROWSER_EXACT = ["zen"]

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
