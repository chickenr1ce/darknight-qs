.pragma library

// The one owner of Hyprland's Lua IPC payloads. Hyprland >= 0.56 evaluates IPC
// dispatch as Lua, so the legacy dispatcher strings fail; every payload, the
// window-address rule, the string escaper, and the `hyprctl cursorpos` parse
// live here. Callers state an intent. A builder returns "" when its input
// cannot make a valid payload, and the caller then skips the dispatch.

// Hyprland's toplevel.address carries no 0x, but a window selector needs one.
// Anything that is not a hex address after normalising is rejected, so a stray
// quote or a bad class name cannot reach the dispatch string.
function selector(address) {
    let text = String(address === null || address === undefined ? "" : address).toLowerCase();
    if (text.indexOf("0x") === 0)
        text = text.slice(2);
    if (!/^[0-9a-f]+$/.test(text))
        return "";
    return "0x" + text;
}

// A workspace id as the integer a payload may carry; -1 when the value is not
// one, so a float, a NaN, or a quoted fragment cannot reach the Lua source.
function workspaceId(value) {
    if (typeof value === "boolean" || value === null || value === undefined)
        return -1;
    const id = Number(value);
    if (!isFinite(id) || !Number.isInteger(id) || id < 1)
        return -1;
    return id;
}

// A pointer coordinate may be negative on a monitor left of or above the
// origin, but it is still a whole number.
function coordinate(value) {
    if (typeof value === "boolean" || value === null || value === undefined)
        return NaN;
    const n = Number(value);
    if (!isFinite(n) || !Number.isInteger(n))
        return NaN;
    return n;
}

function escapeLua(value) {
    return String(value === null || value === undefined ? "" : value)
        .replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\0/g, "\\0");
}

function focusWorkspace(id) {
    const workspace = workspaceId(id);
    if (workspace < 1)
        return "";
    return `hl.dsp.focus({ workspace = ${workspace} })`;
}

function focusWindow(address) {
    const target = selector(address);
    if (target === "")
        return "";
    return `hl.dsp.focus({ window = "address:${target}" })`;
}

// Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an unfocused
// window: it moved to workspace 9 while the active workspace and focus stayed
// put. The confirmed call is:
//   hl.dsp.window.move({ workspace = N, follow = false, window = "address:0x<hex>" })
function moveWindowToWorkspace(address, id, follow) {
    const target = selector(address);
    const workspace = workspaceId(id);
    if (target === "" || workspace < 1)
        return "";
    return `hl.dsp.window.move({ workspace = ${workspace}, follow = ${follow === true}, window = "address:${target}" })`;
}

// Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an unfocused
// window, by address: it toggled floating and left the active workspace and
// focus alone. The confirmed call is:
//   hl.dsp.window.float({ action = "toggle", window = "address:0x<hex>" })
function toggleFloating(address) {
    const target = selector(address);
    if (target === "")
        return "";
    return `hl.dsp.window.float({ action = "toggle", window = "address:${target}" })`;
}

// Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an unfocused
// window, by address: it toggled fullscreen and left the active workspace
// alone, but Hyprland moves focus to the fullscreened window. The confirmed
// call is:
//   hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = "address:0x<hex>" })
function toggleFullscreen(address, mode) {
    const target = selector(address);
    if (target === "")
        return "";
    const confirmed = mode === "maximized" ? "maximized" : "fullscreen";
    return `hl.dsp.window.fullscreen({ mode = "${confirmed}", action = "toggle", window = "address:${target}" })`;
}

function execOnWorkspace(command, id) {
    const workspace = workspaceId(id);
    const text = String(command === null || command === undefined ? "" : command);
    if (workspace < 1 || text === "")
        return "";
    return `hl.dsp.exec_cmd("${escapeLua(text)}", { workspace = ${workspace} })`;
}

function moveCursor(x, y) {
    const pointX = coordinate(x);
    const pointY = coordinate(y);
    if (!isFinite(pointX) || !isFinite(pointY))
        return "";
    return `hl.dsp.cursor.move({ x = ${pointX}, y = ${pointY} })`;
}

// `hyprctl cursorpos` prints "x, y"; anything else is unparseable and the
// caller leaves the cursor where it is.
function parseCursorPos(text) {
    const match = String(text === null || text === undefined ? "" : text).trim()
        .match(/^(-?\d+)\s*,\s*(-?\d+)$/);
    if (!match)
        return null;
    return { x: Number(match[1]), y: Number(match[2]) };
}

// The seam: a test sets `impl` to record a payload instead of dispatching it.
// An empty payload never reaches either path.
function deliver(payload, impl, live) {
    if (typeof payload !== "string" || payload === "")
        return false;
    if (typeof impl === "function") {
        impl(payload);
        return true;
    }
    if (typeof live !== "function")
        return false;
    live(payload);
    return true;
}
