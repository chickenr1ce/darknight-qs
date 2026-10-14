.pragma library

const ROTATED_TRANSFORMS = [1, 3, 5, 7];

function number(value, fallback) {
    const n = Number(value);
    return isFinite(n) ? n : fallback;
}

function clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function normalizeAddress(value) {
    let text = String(value === null || value === undefined ? "" : value).toLowerCase();
    if (text.indexOf("0x") === 0)
        text = text.slice(2);
    return text;
}

// Hyprland's toplevel.address carries no 0x, but a window selector needs one.
// Anything that is not a hex address after normalising is rejected, so a stray
// quote or a bad class name cannot reach the dispatch string.
function selector(address) {
    const text = normalizeAddress(address);
    const candidate = "0x" + text;
    if (!/^0x[0-9a-f]+$/.test(candidate))
        return "";
    return candidate;
}

function logicalSize(monitor) {
    const source = monitor || {};
    const scale = number(source.scale, 1) || 1;
    let width = number(source.width, 0) / scale;
    let height = number(source.height, 0) / scale;
    if (ROTATED_TRANSFORMS.indexOf(number(source.transform, 0)) !== -1) {
        const swap = width;
        width = height;
        height = swap;
    }
    return { width: width, height: height };
}

// Hyprland IPC sends `at` and `size` as two-element arrays: [x, y], [w, h].
function pairValue(pair, index) {
    return pair && pair.length > index ? number(pair[index], 0) : 0;
}

function relativeRect(at, size, monitor) {
    const logical = logicalSize(monitor);
    if (logical.width <= 0 || logical.height <= 0)
        return { x: 0, y: 0, width: 0, height: 0 };
    const originX = number(monitor && monitor.x, 0);
    const originY = number(monitor && monitor.y, 0);
    const left = (pairValue(at, 0) - originX) / logical.width;
    const top = (pairValue(at, 1) - originY) / logical.height;
    const right = left + pairValue(size, 0) / logical.width;
    const bottom = top + pairValue(size, 1) / logical.height;
    const x = clamp01(left);
    const y = clamp01(top);
    return {
        x: x,
        y: y,
        width: Math.max(0, clamp01(right) - x),
        height: Math.max(0, clamp01(bottom) - y)
    };
}

// The workspace id under a drop point, in one shared coordinate space, or -1
// for a gap or outside every map.
function dropTarget(point, tileRects) {
    const x = number(point && point.x, NaN);
    const y = number(point && point.y, NaN);
    if (!isFinite(x) || !isFinite(y))
        return -1;
    const rects = tileRects || [];
    for (let i = 0; i < rects.length; i++) {
        const rect = rects[i];
        if (!rect)
            continue;
        const left = number(rect.x, 0);
        const top = number(rect.y, 0);
        const width = number(rect.width, 0);
        const height = number(rect.height, 0);
        if (width <= 0 || height <= 0)
            continue;
        if (x >= left && x < left + width && y >= top && y < top + height)
            return Math.round(number(rect.id, -1));
    }
    return -1;
}

// A drop on the source workspace, or outside every map, is a no-op (-1);
// otherwise the workspace id to move the window to.
function moveDecision(sourceId, targetId) {
    const target = Math.round(number(targetId, -1));
    const source = Math.round(number(sourceId, -1));
    if (target < 1 || target === source)
        return -1;
    return target;
}

function tileWidth(viewWidth, count, gap) {
    const n = Math.round(number(count, 0));
    if (n < 1)
        return 0;
    return (number(viewWidth, 0) - (n - 1) * number(gap, 0)) / n;
}

function menuItem(kind, extra) {
    const item = { kind: kind, id: "", text: "", hint: "", danger: false, enabled: true, image: "", actionIndex: -1, workspace: -1, submenu: [] };
    if (extra) {
        for (const key in extra)
            item[key] = extra[key];
    }
    return item;
}

// The window menu's "Move to workspace" submenu: one label per enabled
// monitor, then one item per workspace in that monitor's block. The window's
// own workspace is shown but inert, so the menu cannot move a window onto the
// workspace it already sits on. `blocks` pairs with `monitors` by index.
function moveTargets(monitors, blocks, currentId) {
    const out = [];
    const monitorList = monitors || [];
    const blockList = blocks || [];
    const current = Math.round(number(currentId, -1));
    for (let i = 0; i < monitorList.length; i++) {
        const monitor = monitorList[i];
        if (!monitor || monitor.disabled === true)
            continue;
        const name = monitor.name ? String(monitor.name) : "";
        const block = i < blockList.length ? blockList[i] : null;
        if (name === "" || !block)
            continue;
        const first = Math.round(number(block.first, 0));
        const count = Math.round(number(block.count, 0));
        if (first < 1 || count < 1)
            continue;
        out.push(menuItem("label", { text: name }));
        for (let n = 0; n < count; n++) {
            const workspace = first + n;
            const isCurrent = workspace === current;
            out.push(menuItem("item", {
                id: "move-workspace",
                text: isCurrent
                    ? qsTr("Workspace %1 (current)").arg(workspace)
                    : qsTr("Workspace %1").arg(workspace),
                workspace: workspace,
                current: isCurrent,
                enabled: !isCurrent
            }));
        }
    }
    return out;
}

// A submenu is worth showing only when it holds at least one workspace the
// window could actually move to; a list of labels, or of the window's own
// (inert) workspace alone, offers nothing to choose.
function hasMoveTarget(targets) {
    const list = targets || [];
    for (let i = 0; i < list.length; i++) {
        const item = list[i];
        if (item && item.kind === "item" && item.enabled !== false)
            return true;
    }
    return false;
}

function windowMenuItems(window, moveTargetsList) {
    const floating = window && window.floating === true;
    const fullscreen = window && window.fullscreen === true;
    const targets = moveTargetsList || [];
    const items = [
        menuItem("item", { id: "focus", text: qsTr("Focus window"), hint: "↵" })
    ];
    if (hasMoveTarget(targets))
        items.push(menuItem("item", {
            id: "move",
            text: qsTr("Move to workspace"),
            submenu: targets
        }));
    items.push(
        menuItem("item", {
            id: "toggle-floating",
            text: floating ? qsTr("Tile") : qsTr("Float")
        }),
        menuItem("item", {
            id: "toggle-fullscreen",
            text: fullscreen ? qsTr("Exit fullscreen") : qsTr("Fullscreen")
        }),
        menuItem("separator", {}),
        menuItem("item", { id: "copy-class", text: qsTr("Copy window class") }),
        menuItem("item", { id: "copy-title", text: qsTr("Copy window title") }),
        menuItem("separator", {}),
        menuItem("item", { id: "close", text: qsTr("Close window"), danger: true })
    );
    return items;
}

function menuAction(item) {
    if (!item || item.kind !== "item")
        return "";
    const id = item.id;
    if (id === "focus")
        return "focusWindow";
    if (id === "move-workspace")
        return "moveWindow";
    if (id === "toggle-floating")
        return "toggleFloating";
    if (id === "toggle-fullscreen")
        return "toggleFullscreen";
    if (id === "copy-class")
        return "copyWindowClass";
    if (id === "copy-title")
        return "copyWindowTitle";
    if (id === "close")
        return "closeWindow";
    return "";
}

function windowRank(window) {
    if (window && window.fullscreen === true)
        return 2;
    if (window && window.floating === true)
        return 1;
    return 0;
}

function sortWindows(windows) {
    const list = windows || [];
    const tiled = [];
    const floating = [];
    const fullscreen = [];
    for (let i = 0; i < list.length; i++) {
        const window = list[i];
        const rank = windowRank(window);
        if (rank === 2)
            fullscreen.push(window);
        else if (rank === 1)
            floating.push(window);
        else
            tiled.push(window);
    }
    return tiled.concat(floating, fullscreen);
}

// The desktop entry's app name, else the window class.
function appName(window) {
    if (window && window.app)
        return String(window.app);
    return window && window.cls ? String(window.cls) : "";
}

function caption(windows) {
    const list = windows || [];
    const names = [];
    for (let i = 0; i < list.length; i++) {
        const window = list[i];
        const name = appName(window);
        if (name !== "" && names.indexOf(name) === -1)
            names.push(name);
    }
    if (names.length === 0)
        return qsTr("Empty");
    return names.join(", ");
}

function inBlocks(workspaceId, blocks) {
    const id = Math.round(number(workspaceId, -1));
    if (id < 1)
        return false;
    const list = blocks || [];
    for (let i = 0; i < list.length; i++) {
        const block = list[i];
        if (!block)
            continue;
        const first = Math.round(number(block.first, 0));
        const count = Math.round(number(block.count, 0));
        if (count < 1)
            continue;
        if (id >= first && id < first + count)
            return true;
    }
    return false;
}

function monitorSnapshot(source) {
    const monitor = source || {};
    const ipc = monitor.lastIpcObject || {};
    const active = monitor.activeWorkspace || null;
    const transform = number(ipc.transform, 0);
    const logical = logicalSize({
        width: monitor.width,
        height: monitor.height,
        scale: monitor.scale,
        transform: transform
    });
    return {
        name: monitor.name ? String(monitor.name) : "",
        x: number(monitor.x, 0),
        y: number(monitor.y, 0),
        width: number(monitor.width, 0),
        height: number(monitor.height, 0),
        scale: number(monitor.scale, 1) || 1,
        transform: transform,
        logicalWidth: logical.width,
        logicalHeight: logical.height,
        activeId: active ? Math.round(number(active.id, -1)) : -1,
        focused: monitor.focused === true
    };
}

function monitorBlocks(entries, perMonitor, windows, activeIds, focusedMonitorName, focusedAddress) {
    const out = [];
    const list = entries || [];
    for (let i = 0; i < list.length; i++) {
        const entry = list[i];
        if (!entry)
            continue;
        out.push({
            monitor: entry.monitor,
            tiles: monitorTiles(entry.monitor, entry.first, perMonitor, windows, activeIds,
                focusedMonitorName, focusedAddress)
        });
    }
    return out;
}

function monitorTiles(monitor, firstId, count, windows, activeIds, focusedMonitorName, focusedAddress) {
    const tiles = [];
    const n = Math.round(number(count, 0));
    if (n < 1)
        return tiles;
    const first = Math.round(number(firstId, 0));
    const list = windows || [];
    const actives = activeIds || [];
    const address = normalizeAddress(focusedAddress);
    const source = monitor || {};
    const monitorName = source.name ? String(source.name) : "";
    const focusedMonitor = focusedMonitorName ? String(focusedMonitorName) : "";
    const isFocusedMonitor = monitorName !== "" && monitorName === focusedMonitor;
    const activeId = Math.round(number(source.activeId, -1));
    for (let k = 0; k < n; k++) {
        const id = first + k;
        const on = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && Math.round(number(list[i].workspaceId, -1)) === id)
                on.push(list[i]);
        }
        const ordered = sortWindows(on);
        const mapped = [];
        let urgent = false;
        for (let i = 0; i < ordered.length; i++) {
            const window = ordered[i];
            const windowAddress = normalizeAddress(window.address);
            mapped.push({
                address: windowAddress,
                cls: window.cls ? String(window.cls) : "",
                app: appName(window),
                title: window.title ? String(window.title) : "",
                icon: window.icon ? String(window.icon) : "",
                rect: relativeRect(window.at, window.size, source),
                floating: window.floating === true,
                fullscreen: window.fullscreen === true,
                focused: windowAddress !== "" && windowAddress === address,
                urgent: window.urgent === true
            });
            if (window.urgent === true)
                urgent = true;
        }
        let state = "normal";
        if (isFocusedMonitor && id === activeId)
            state = "current";
        else if (actives.indexOf(id) !== -1)
            state = "shown";
        tiles.push({
            id: id,
            state: state,
            empty: mapped.length === 0,
            urgent: urgent,
            caption: caption(mapped),
            windows: mapped
        });
    }
    return tiles;
}
