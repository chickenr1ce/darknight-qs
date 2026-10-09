.pragma library

const ENTRY_KEY_STOPLIST = ["app", "desktop", "client", "gui", "handler", "launcher", "bin", "main"];

function compareNames(a, b) {
    const an = (a && a.name ? a.name : "").toLowerCase();
    const bn = (b && b.name ? b.name : "").toLowerCase();
    if (an < bn)
        return -1;
    if (an > bn)
        return 1;
    return 0;
}

function subsequence(text, query) {
    let j = 0;
    for (let i = 0; i < text.length && j < query.length; i++) {
        if (text[i] === query[j])
            j++;
    }
    return j === query.length;
}

function score(entry, query) {
    const name = (entry && entry.name ? entry.name : "").toLowerCase();
    if (query === "")
        return 0;
    if (name.indexOf(query) === 0)
        return 100 - name.length * 0.1;
    const words = name.split(/[\s\-+.]/);
    for (let i = 0; i < words.length; i++) {
        if (words[i].indexOf(query) === 0)
            return 80;
    }
    if (name.indexOf(query) !== -1)
        return 60;
    if (subsequence(name, query))
        return 40;
    const meta = [(entry && entry.genericName ? entry.genericName : ""),
        (entry && entry.keywords ? entry.keywords.join(" ") : ""),
        (entry && entry.id ? entry.id : "")].join(" ").toLowerCase();
    if (meta.indexOf(query) !== -1)
        return 25;
    return 0;
}

function rank(entries, query) {
    const list = entries || [];
    const q = (query || "").trim().toLowerCase();
    if (q === "")
        return list.slice().sort(compareNames);
    const scored = [];
    for (let i = 0; i < list.length; i++) {
        const value = score(list[i], q);
        if (value > 0)
            scored.push({ entry: list[i], score: value });
    }
    scored.sort((a, b) => b.score - a.score || compareNames(a.entry, b.entry));
    const out = [];
    for (let i = 0; i < scored.length; i++)
        out.push(scored[i].entry);
    return out;
}

function matchRanges(name, query) {
    const q = (query || "").trim().toLowerCase();
    if (q === "")
        return [];
    const text = (name || "").toLowerCase();
    const at = text.indexOf(q);
    if (at !== -1)
        return [[at, at + q.length]];
    const marks = [];
    let j = 0;
    for (let i = 0; i < text.length && j < q.length; i++) {
        if (text[i] === q[j]) {
            marks.push([i, i + 1]);
            j++;
        }
    }
    if (j < q.length)
        return [];
    const merged = [];
    for (let i = 0; i < marks.length; i++) {
        const last = merged.length > 0 ? merged[merged.length - 1] : null;
        if (last && last[1] === marks[i][0])
            last[1] = marks[i][1];
        else
            merged.push([marks[i][0], marks[i][1]]);
    }
    return merged;
}

function escapeHtml(text) {
    return (text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;")
        .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function markup(name, query, color) {
    const text = name || "";
    const ranges = matchRanges(text, query);
    if (ranges.length === 0)
        return escapeHtml(text);
    let out = "";
    let pos = 0;
    for (let i = 0; i < ranges.length; i++) {
        out += escapeHtml(text.slice(pos, ranges[i][0]));
        out += "<font color=\"" + color + "\">"
            + escapeHtml(text.slice(ranges[i][0], ranges[i][1])) + "</font>";
        pos = ranges[i][1];
    }
    return out + escapeHtml(text.slice(pos));
}

function shellQuote(arg) {
    const text = String(arg ?? "");
    if (text === "")
        return "''";
    return "'" + text.replace(/'/g, "'\\''") + "'";
}

function shellCommand(argv) {
    const list = argv || [];
    const out = [];
    for (let i = 0; i < list.length; i++)
        out.push(shellQuote(list[i]));
    return out.join(" ");
}

function stringList(value) {
    const out = [];
    if (!Array.isArray(value))
        return out;
    for (let i = 0; i < value.length; i++) {
        const item = value[i];
        if (typeof item === "string" && item !== "" && out.indexOf(item) === -1)
            out.push(item);
    }
    return out;
}

function parseState(jsonText) {
    const out = {};
    out["pinned"] = [];
    out["hidden"] = [];
    out["recent"] = [];
    let parsed = null;
    try {
        parsed = JSON.parse(jsonText);
    } catch (e) {
        return out;
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
        return out;
    out["pinned"] = stringList(parsed.pinned);
    out["hidden"] = stringList(parsed.hidden);
    out["recent"] = stringList(parsed.recent).slice(0, 8);
    return out;
}

function visibleEntries(entries, hiddenIds) {
    const list = entries || [];
    const ids = hiddenIds || [];
    if (ids.length === 0)
        return list;
    return list.filter(entry => ids.indexOf(entry.id) === -1);
}

function resolveHidden(entries, hiddenIds) {
    const list = entries || [];
    const ids = hiddenIds || [];
    const byId = {};
    for (let i = 0; i < list.length; i++)
        byId[list[i].id] = list[i];
    const out = [];
    for (let i = 0; i < ids.length; i++)
        out.push({ id: ids[i], entry: byId[ids[i]] || null });
    return out;
}

function recordLaunch(recent, id, cap) {
    const max = (typeof cap === "number" && cap >= 0) ? cap : 8;
    const list = recent || [];
    const next = [];
    if (id)
        next.push(id);
    for (let i = 0; i < list.length; i++) {
        if (id && list[i] === id)
            continue;
        next.push(list[i]);
    }
    return next.slice(0, max);
}

function togglePin(pinned, id) {
    const list = pinned || [];
    const next = [];
    let removed = false;
    for (let i = 0; i < list.length; i++) {
        if (list[i] === id) {
            removed = true;
            continue;
        }
        next.push(list[i]);
    }
    if (!removed)
        next.push(id);
    return next;
}

function hide(hiddenIds, id) {
    const list = hiddenIds || [];
    const next = list.slice();
    if (!id || list.indexOf(id) !== -1)
        return next;
    next.push(id);
    return next;
}

function unhide(hiddenIds, id) {
    const list = hiddenIds || [];
    if (!id || list.indexOf(id) === -1)
        return list.slice();
    const next = [];
    for (let i = 0; i < list.length; i++) {
        if (list[i] !== id)
            next.push(list[i]);
    }
    return next;
}

function normalizeKey(value) {
    return String(value ?? "").toLowerCase().trim();
}

function entryKeys(entry) {
    const keys = [];
    if (!entry)
        return keys;
    const add = value => {
        const key = normalizeKey(value);
        if (key !== "" && keys.indexOf(key) === -1)
            keys.push(key);
    };
    add(entry.startupClass);
    add(entry.id);
    const id = normalizeKey(entry.id);
    if (id.indexOf(".") === -1)
        return keys;
    const parts = id.split(".");
    const last = parts[parts.length - 1];
    if (last.length >= 3 && !/^[0-9]+$/.test(last) && ENTRY_KEY_STOPLIST.indexOf(last) === -1)
        add(last);
    return keys;
}

function classMatches(source, key) {
    const sourceParts = String(source ?? "").split(/[^a-z0-9]+/).filter(part => part !== "");
    const keyParts = String(key ?? "").split(/[^a-z0-9]+/).filter(part => part !== "");
    if (sourceParts.length === 0 || keyParts.length === 0)
        return false;
    if (keyParts.length === 1)
        return sourceParts.includes(keyParts[0]);
    return sourceParts[sourceParts.length - 1] === keyParts[keyParts.length - 1];
}

function windowMatches(keys, classSources) {
    const wanted = keys || [];
    const sources = classSources || [];
    for (let s = 0; s < sources.length; s++) {
        const source = normalizeKey(sources[s]);
        if (source === "")
            continue;
        for (let k = 0; k < wanted.length; k++) {
            if (source === normalizeKey(wanted[k]))
                return true;
        }
    }
    return false;
}

function windowIndexesFor(keys, toplevelClassLists) {
    const lists = toplevelClassLists || [];
    const out = [];
    for (let i = 0; i < lists.length; i++) {
        if (windowMatches(keys, lists[i]))
            out.push(i);
    }
    return out;
}

function menuItem(kind, extra) {
    const item = { kind: kind, id: "", text: "", hint: "", danger: false, enabled: true, image: "", actionIndex: -1, workspace: -1, submenu: [] };
    if (extra) {
        for (const key in extra)
            item[key] = extra[key];
    }
    return item;
}

function menuItems(entry, pinned, isRun, runningCount, workspaceItems) {
    const items = [];
    if (isRun) {
        items.push(menuItem("item", { id: "run", text: qsTr("Run"), hint: "↵" }));
        items.push(menuItem("item", { id: "copy-command", text: qsTr("Copy command") }));
        return items;
    }
    items.push(menuItem("item", { id: "open", text: qsTr("Open"), hint: "↵" }));
    const spaces = workspaceItems || [];
    if (spaces.length > 0)
        items.push(menuItem("item", { id: "open-workspace", text: qsTr("Open on workspace"), submenu: spaces }));
    items.push(menuItem("item", { id: "open-keep", text: qsTr("Open, keep dashboard"), hint: qsTr("middle") }));
    if (runningCount > 0)
        items.push(menuItem("item", { id: "focus-window", text: qsTr("Focus window (%1 open)").arg(runningCount) }));
    const actions = entry && entry.actions ? entry.actions : [];
    if (actions.length > 0) {
        items.push(menuItem("separator", {}));
        items.push(menuItem("label", { text: qsTr("Actions") }));
        for (let i = 0; i < actions.length; i++) {
            const action = actions[i];
            items.push(menuItem("item", {
                id: "action:" + i,
                text: action && action.name ? action.name : "",
                image: action && action.icon ? action.icon : "",
                actionIndex: i
            }));
        }
    }
    items.push(menuItem("separator", {}));
    items.push(menuItem("item", {
        id: pinned ? "unpin" : "pin",
        text: pinned ? qsTr("Unpin") : qsTr("Pin"),
        hint: "Ctrl+P"
    }));
    items.push(menuItem("item", { id: "hide", text: qsTr("Hide from launcher") }));
    items.push(menuItem("separator", {}));
    items.push(menuItem("item", { id: "copy-command", text: qsTr("Copy launch command") }));
    if (runningCount > 0) {
        items.push(menuItem("separator", {}));
        items.push(menuItem("item", {
            id: "kill",
            text: qsTr("Kill %1").arg(entry && entry.name ? entry.name : ""),
            danger: true
        }));
    }
    return items;
}

function workspaceFor(n, firstWorkspace, perMonitor) {
    const slot = Math.round(Number(n));
    const first = Math.round(Number(firstWorkspace));
    const count = Math.round(Number(perMonitor));
    if (isNaN(slot) || isNaN(first) || isNaN(count))
        return -1;
    if (slot < 1 || count < 1 || slot > count || first < 1)
        return -1;
    return first + slot - 1;
}

function firstEmptyWorkspace(firstWorkspace, perMonitor, occupiedIds) {
    const first = Math.round(Number(firstWorkspace));
    const count = Math.round(Number(perMonitor));
    if (isNaN(first) || isNaN(count) || count < 1 || first < 1)
        return -1;
    const occupied = occupiedIds || [];
    for (let i = 0; i < count; i++) {
        const workspace = first + i;
        if (occupied.indexOf(workspace) === -1)
            return workspace;
    }
    return -1;
}

function workspaceMenu(firstWorkspace, perMonitor, activeWorkspace, occupiedIds) {
    const items = [];
    const first = Math.round(Number(firstWorkspace));
    const count = Math.round(Number(perMonitor));
    if (isNaN(first) || isNaN(count) || count < 1 || first < 1)
        return items;
    const occupied = occupiedIds || [];
    for (let n = 1; n <= count; n++) {
        const workspace = first + n - 1;
        const current = workspace === activeWorkspace;
        items.push(menuItem("item", {
            id: "workspace",
            text: current ? qsTr("Workspace %1 (current)").arg(n) : qsTr("Workspace %1").arg(n),
            hint: n <= 9 ? qsTr("ctrl %1").arg(n) : "",
            workspace: workspace,
            current: current,
            occupied: occupied.indexOf(workspace) !== -1
        }));
    }
    const empty = firstEmptyWorkspace(first, count, occupied);
    if (empty !== -1) {
        items.push(menuItem("separator", {}));
        items.push(menuItem("item", { id: "workspace-new", text: qsTr("New empty workspace"), workspace: empty }));
    }
    return items;
}

function sections(entries, pinnedIds, recentIds, query) {
    const list = entries || [];
    const q = (query || "").trim().toLowerCase();
    const byId = {};
    for (let i = 0; i < list.length; i++)
        byId[list[i].id] = list[i];
    if (q !== "") {
        const ranked = rank(list, query);
        return [{ key: "results", count: ranked.length, items: ranked }];
    }
    const pins = pinnedIds || [];
    const recents = recentIds || [];
    const pinned = [];
    for (let i = 0; i < pins.length; i++) {
        const entry = byId[pins[i]];
        if (entry)
            pinned.push(entry);
    }
    const recent = [];
    for (let i = 0; i < recents.length && recent.length < 4; i++) {
        if (pins.indexOf(recents[i]) !== -1)
            continue;
        const entry = byId[recents[i]];
        if (entry)
            recent.push(entry);
    }
    const all = list.slice().sort(compareNames);
    return [
        { key: "pinned", count: pinned.length, items: pinned },
        { key: "recent", count: recent.length, items: recent },
        { key: "all", count: all.length, items: all }
    ];
}
