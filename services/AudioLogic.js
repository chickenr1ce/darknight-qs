.pragma library

function isSinkNode(node) {
    // Wrapped in Boolean(): the QML declaration coerced the return to bool,
    // so a truthy node with no isSink flag must read false, not undefined.
    return Boolean(Boolean(node) && node.isSink && !node.isStream && Boolean(node.audio));
}

function isSourceNode(node) {
    if (!node || node.isSink || node.isStream)
        return false;
    const mediaClass = String((node.properties || {})["media.class"] || "");
    if (!mediaClass.startsWith("Audio/Source"))
        return false;
    // The virtual class is the one sound source Quickshell does not type as an
    // audio node, so it is a source on its media class alone.
    return Boolean(mediaClass.startsWith("Audio/Source/Virtual") || node.audio);
}

function keyFor(node) {
    if (!node)
        return "";
    return node.name || node.description || node.nickname || String(node.id);
}

function rawLabelFor(node) {
    if (!node)
        return "";
    return node.description || node.nickname || node.name || "";
}

function appName(node) {
    if (!node)
        return "";
    const properties = node.properties || {};
    const name = properties["application.name"] || node.name || "";
    // Spotify reports "spotify" as its app name and "Spotify" as its media
    // name; take the media name's casing when the two only differ in case.
    const media = properties["media.name"] || "";
    return media.toLowerCase() === name.toLowerCase() && media !== "" ? media : name;
}

function isAppStream(node) {
    if (!node || !node.audio)
        return false;
    const properties = node.properties || {};
    return properties["media.class"] === "Stream/Output/Audio";
}

function streamTitle(node) {
    if (!node)
        return "";
    const properties = node.properties || {};
    const title = properties["media.name"] || "";
    return title.toLowerCase() === appName(node).toLowerCase() ? "" : title;
}

function appIconName(node) {
    if (!node)
        return "";
    const properties = node.properties || {};
    return properties["application.icon-name"] || properties["application.process.binary"] || "";
}

function sortStreams(nodes) {
    const list = nodes || [];
    return list.slice().sort((a, b) => {
        const left = appName(a).toLowerCase();
        const right = appName(b).toLowerCase();
        if (left < right)
            return -1;
        if (left > right)
            return 1;
        const leftId = a ? Number(a.id) || 0 : 0;
        const rightId = b ? Number(b.id) || 0 : 0;
        return leftId - rightId;
    });
}

function captureAppNames(linkGroups) {
    const groups = linkGroups || [];
    const out = [];
    for (let i = 0; i < groups.length; i++) {
        const group = groups[i];
        const target = group ? group.target : null;
        const properties = target ? target.properties || {} : {};
        if (properties["media.class"] !== "Stream/Input/Audio")
            continue;
        const name = appName(target);
        if (name !== "" && out.indexOf(name) === -1)
            out.push(name);
    }
    return out;
}

function orderedNodes(nodes, orderKeys) {
    const order = orderKeys || [];
    const out = [];
    for (let i = 0; i < order.length; i++) {
        for (let j = 0; j < nodes.length; j++) {
            if (keyFor(nodes[j]) === order[i]) {
                out.push(nodes[j]);
                break;
            }
        }
    }
    const rest = [];
    for (let j = 0; j < nodes.length; j++) {
        if (order.indexOf(keyFor(nodes[j])) === -1)
            rest.push(nodes[j]);
    }
    rest.sort((a, b) => {
        const left = rawLabelFor(a).toLowerCase();
        const right = rawLabelFor(b).toLowerCase();
        return left < right ? -1 : (left > right ? 1 : 0);
    });
    for (let j = 0; j < rest.length; j++)
        out.push(rest[j]);
    return out;
}

function indexOfKey(entries, key) {
    const list = entries || [];
    for (let i = 0; i < list.length; i++) {
        if (list[i] && list[i].key === key)
            return i;
    }
    return -1;
}

function percentForVolume(volume) {
    const value = Number(volume);
    if (isNaN(value))
        return 0;
    return Math.round(Math.max(0, Math.min(1, value)) * 100);
}

function volumeForPercent(percent) {
    const value = Number(percent);
    if (isNaN(value))
        return 0;
    return Math.max(0, Math.min(100, value)) / 100;
}

function percentText(volume) {
    const value = Number(volume);
    if (isNaN(value))
        return "0";
    return String(Math.round(value * 100));
}

function volumeFraction(volume) {
    const value = Number(volume);
    if (isNaN(value))
        return 0;
    return Math.max(0, Math.min(1, value));
}

function statusText(volume, muted) {
    if (muted)
        return "muted";
    return percentText(volume);
}

function stepPercent(current, direction, step) {
    const value = Number(current);
    const p = isNaN(value) ? 0 : Math.round(value);
    if (direction > 0)
        return Math.max(p, Math.min(100, Math.floor(p / step) * step + step));
    if (direction < 0)
        return Math.max(0, Math.ceil(p / step) * step - step);
    return p;
}
