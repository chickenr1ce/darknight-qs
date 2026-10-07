.pragma library

function clampWorkspacesPerMonitor(value, fallback) {
    const count = Math.round(Number(value));
    if (isNaN(count))
        return fallback;
    return Math.max(1, Math.min(20, count));
}

function parseMonitorSettings(text, fallbackCount) {
    let parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!parsed || typeof parsed !== "object")
        return null;
    return {
        primary: typeof parsed.primary === "string" ? parsed.primary : null,
        workspacesPerMonitor: clampWorkspacesPerMonitor(parsed.workspacesPerMonitor, fallbackCount)
    };
}

function orderMonitors(primary, screenNames) {
    const ordered = [];
    if (primary !== "")
        ordered.push(primary);
    for (let i = 0; i < screenNames.length; i++) {
        if (screenNames[i] !== primary)
            ordered.push(screenNames[i]);
    }
    return ordered;
}

function firstWorkspaceFor(ordered, monitorName, perMonitor) {
    const index = ordered.indexOf(monitorName);
    if (index === -1)
        return 1;
    return index * perMonitor + 1;
}

function escapeLua(value) {
    return value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
}

function modeFor(monitor) {
    const width = Math.round(Number(monitor.width));
    const height = Math.round(Number(monitor.height));
    const refresh = Math.round(Number(monitor.refreshRate));
    if (!(width > 0) || !(height > 0) || !(refresh > 0))
        return "preferred";
    return width + "x" + height + "@" + refresh;
}

function positionFor(monitor) {
    const x = Math.round(Number(monitor.x));
    const y = Math.round(Number(monitor.y));
    if (isNaN(x) || isNaN(y))
        return "auto";
    return x + "x" + y;
}

function scaleFor(monitor) {
    const scale = Number(monitor.scale);
    return scale > 0 ? scale : 1;
}

function setEnabledSpec(output, monitor, enabled, multiMonitor) {
    if (!monitor)
        return null;
    if (monitor.disabled === !enabled)
        return null;
    if (!enabled && !multiMonitor)
        return null;
    let spec = "hl.monitor({ output = \"" + output + "\", disabled = " + (enabled ? "false" : "true");
    if (enabled)
        spec += ", mode = \"" + monitor.mode + "\", position = \"" + monitor.position + "\", scale = " + monitor.scale;
    return spec + " })";
}
