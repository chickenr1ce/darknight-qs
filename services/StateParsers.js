.pragma library

function parseEventsCache(jsonText) {
    try {
        const parsed = JSON.parse(jsonText);
        if (parsed && parsed.days)
            return parsed;
    } catch (e) {
    }
    return {
        "fetchedAt": "",
        "days": {},
        "calendars": []
    };
}

function isValidZoneName(name) {
    return /^[A-Za-z0-9_\-+\/]+$/.test(name);
}

function parseZones(text, maxZones) {
    const zones = [];
    const lines = text.split("\n");
    for (let i = 0; i < lines.length && zones.length < maxZones; i++) {
        const name = lines[i].trim();
        if (name !== "" && isValidZoneName(name) && !zones.includes(name))
            zones.push(name);
    }
    return zones;
}

function parseHiddenCalendars(text) {
    const hidden = [];
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const name = lines[i].trim();
        if (name !== "" && !hidden.includes(name))
            hidden.push(name);
    }
    return hidden;
}

function parseZoneList(text) {
    try {
        const parsed = JSON.parse(text);
        if (Array.isArray(parsed))
            return parsed;
    } catch (e) {
    }
    return [];
}

function parseZoneTimes(output) {
    const times = {};
    const lines = output.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const eq = lines[i].indexOf("=");
        if (eq <= 0)
            continue;
        const rest = lines[i].slice(eq + 1);
        const sp = rest.indexOf(" ");
        times[lines[i].slice(0, eq)] = {
            t: sp < 0 ? rest : rest.slice(0, sp),
            d: sp < 0 ? null : rest.slice(sp + 1)
        };
    }
    return times;
}

function sameStringList(a, b) {
    if (!(a.length === b.length))
        return false;
    for (let i = 0; i < a.length; i++) {
        if (!(a[i] === b[i]))
            return false;
    }
    return true;
}

function parseCavaSettings(jsonText, limits) {
    let parsed = null;
    try
    {
        parsed = JSON.parse(jsonText);
    }
    catch (e)
    {
        return null;
    }
    if (!parsed || typeof parsed !== "object")
        return null;
    const clampInt = (value, range) => {
        const n = Math.round(Number(value));
        if (isNaN(n))
            return range[2];
        return Math.max(range[0], Math.min(range[1], n));
    };
    const out = {};
    out["sensitivity"] = clampInt(parsed.sensitivity, limits["sensitivity"]);
    out["autoSensitivity"] = parsed.autoSensitivity === true || parsed.autoSensitivity === 1;
    out["barCount"] = clampInt(parsed.barCount, limits["barCount"]);
    out["styleMode"] = clampInt(parsed.styleMode, limits["styleMode"]);
    out["maxHeight"] = clampInt(parsed.maxHeight, limits["maxHeight"]);
    return out;
}
