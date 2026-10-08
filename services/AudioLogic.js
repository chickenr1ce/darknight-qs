.pragma library

function isSinkNode(node) {
    // Wrapped in Boolean(): the QML declaration coerced the return to bool,
    // so a truthy node with no isSink flag must read false, not undefined.
    return Boolean(Boolean(node) && node.isSink && !node.isStream && Boolean(node.audio));
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
