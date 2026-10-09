pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import "AppLogic.js" as AppLogic
import "MonitorLogic.js" as MonitorLogic

Singleton {
    id: root

    readonly property var terminalPrefix: ["kitty", "-e"]

    readonly property var entries: {
        const list = DesktopEntries.applications.values.slice();
        list.sort((a, b) => AppLogic.compareNames(a, b));
        return list;
    }

    readonly property var toplevels: Hyprland.toplevels?.values ?? []

    readonly property var runningMap: {
        const map = {};
        const tops = root.toplevels;
        const lists = [];
        for (let i = 0; i < tops.length; i++)
            lists.push(HyprlandFocus.classSources(tops[i]));
        const entries = root.entries;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            const count = AppLogic.windowIndexesFor(AppLogic.entryKeys(entry), lists).length;
            if (count > 0)
                map[entry.id] = count;
        }
        return map;
    }

    property var state: ({})

    readonly property var pinned: root.state.pinned || []
    readonly property var hidden: root.state.hidden || []
    readonly property var recent: root.state.recent || []

    readonly property var hiddenEntries: {
        const records = root.resolveHidden(root.entries, root.hidden);
        const out = [];
        for (let i = 0; i < records.length; i++) {
            const entry = records[i].entry || DesktopEntries.byId(records[i].id);
            out.push({
                id: records[i].id,
                name: entry ? entry.name : records[i].id,
                source: entry ? root.iconFor(entry) : ""
            });
        }
        return out;
    }

    onStateChanged: root.saveState()

    StateFile {
        id: idAppState

        name: "app-launcher"
        createDir: true
        onParsed: text => root.applyState(text)
    }

    function iconFor(entry): string {
        if (!entry || entry.icon === "")
            return "";
        return root.iconForName(entry.icon);
    }

    function iconForName(name): string {
        if (!name)
            return "";
        return Quickshell.iconPath(name, true);
    }

    function launch(entry, keepOpen): void {
        if (!entry)
            return;
        if (entry.runInTerminal)
            Quickshell.execDetached(root.terminalPrefix.concat(entry.command || []));
        else
            entry.execute();
        root.recordLaunch(entry.id);
        if (!keepOpen)
            DashboardService.close();
    }

    function launchKeep(entry): void {
        root.launch(entry, true);
    }

    function launchAction(entry, index): void {
        if (!entry || !entry.actions || index < 0 || index >= entry.actions.length)
            return;
        entry.actions[index].execute();
        root.recordLaunch(entry.id);
        DashboardService.close();
    }

    function anchorMonitorName(): string {
        const screen = DashboardService.anchorScreen;
        return screen ? screen.name : "";
    }

    function workspaceFor(n): int {
        return AppLogic.workspaceFor(n, MonitorService.firstWorkspaceFor(root.anchorMonitorName()),
            MonitorService.workspacesPerMonitor);
    }

    function workspaceMenuItems(): var {
        const name = root.anchorMonitorName();
        const monitors = Hyprland.monitors?.values ?? [];
        let active = -1;
        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === name && monitors[i].activeWorkspace) {
                active = monitors[i].activeWorkspace.id;
                break;
            }
        }
        const occupied = [];
        const tops = root.toplevels;
        for (let i = 0; i < tops.length; i++) {
            const workspace = tops[i].workspace;
            if (workspace && occupied.indexOf(workspace.id) === -1)
                occupied.push(workspace.id);
        }
        return AppLogic.workspaceMenu(MonitorService.firstWorkspaceFor(name),
            MonitorService.workspacesPerMonitor, active, occupied);
    }

    function launchOnWorkspace(entry, workspace, keepOpen): void {
        if (!entry || workspace < 1)
            return;
        const parts = entry.runInTerminal ? root.terminalPrefix.concat(entry.command || []) : (entry.command || []);
        const command = AppLogic.shellCommand(parts);
        if (command === "")
            return;
        Hyprland.dispatch(`hl.dsp.exec_cmd("${MonitorLogic.escapeLua(command)}", { workspace = ${workspace} })`);
        root.recordLaunch(entry.id);
        if (!keepOpen)
            DashboardService.close();
    }

    function copyCommand(entry): void {
        if (!entry)
            return;
        root.copyText((entry.command || []).join(" "));
    }

    function copyText(text): void {
        const payload = text || "";
        if (payload === "")
            return;
        Quickshell.execDetached(["wl-copy", payload]);
    }

    function runQuery(text): void {
        const command = (text || "").trim();
        if (command === "")
            return;
        Quickshell.execDetached(root.terminalPrefix.concat(["sh", "-c", command]));
        DashboardService.close();
    }

    function recordLaunch(id): void {
        if (!id)
            return;
        root.setState(root.pinned, root.hidden, AppLogic.recordLaunch(root.recent, id, 8));
    }

    function isPinned(id): bool {
        return root.pinned.indexOf(id) !== -1;
    }

    function togglePin(id): void {
        if (!id)
            return;
        root.setState(AppLogic.togglePin(root.pinned, id), root.hidden, root.recent);
    }

    function hide(id): void {
        if (!id)
            return;
        root.setState(root.pinned, AppLogic.hide(root.hidden, id), root.recent);
    }

    function unhide(id): void {
        if (!id)
            return;
        root.setState(root.pinned, AppLogic.unhide(root.hidden, id), root.recent);
    }

    function windowsFor(entry): var {
        if (!entry)
            return [];
        const keys = AppLogic.entryKeys(entry);
        if (keys.length === 0)
            return [];
        const tops = root.toplevels;
        const lists = [];
        for (let i = 0; i < tops.length; i++)
            lists.push(HyprlandFocus.classSources(tops[i]));
        const indexes = AppLogic.windowIndexesFor(keys, lists);
        const out = [];
        for (let i = 0; i < indexes.length; i++)
            out.push(tops[indexes[i]]);
        return out;
    }

    function runningCount(entry): int {
        if (!entry)
            return 0;
        const count = root.runningMap[entry.id];
        return typeof count === "number" ? count : 0;
    }

    function focusWindows(entry): void {
        if (!entry)
            return;
        const windows = root.windowsFor(entry);
        if (windows.length === 0)
            return;
        let target = windows[0];
        for (let i = 0; i < windows.length; i++) {
            if (windows[i].activated === true) {
                target = windows[i];
                break;
            }
        }
        DashboardService.close();
        HyprlandFocus.focusAddress(target.address);
    }

    function killWindows(entry): void {
        const windows = root.windowsFor(entry);
        for (let i = 0; i < windows.length; i++) {
            const handle = windows[i].wayland;
            if (handle)
                handle.close();
        }
    }

    function visibleEntries(entries, hiddenIds): var {
        return AppLogic.visibleEntries(entries, hiddenIds);
    }

    function resolveHidden(entries, hiddenIds): var {
        return AppLogic.resolveHidden(entries, hiddenIds);
    }

    function setState(pinned, hidden, recent): void {
        const next = {};
        next["pinned"] = pinned || [];
        next["hidden"] = hidden || [];
        next["recent"] = recent || [];
        root.state = next;
    }

    function rank(query): var {
        return AppLogic.rank(root.visibleEntries(root.entries, root.hidden), query);
    }

    function matchRanges(name, query): var {
        return AppLogic.matchRanges(name, query);
    }

    function markup(name, query, color): string {
        return AppLogic.markup(name, query, color);
    }

    function escapeHtml(text): string {
        return AppLogic.escapeHtml(text);
    }

    function shellQuote(arg): string {
        return AppLogic.shellQuote(arg);
    }

    function shellCommand(argv): string {
        return AppLogic.shellCommand(argv);
    }

    function sections(query): var {
        return AppLogic.sections(root.visibleEntries(root.entries, root.hidden), root.pinned, root.recent, query);
    }

    function parseState(jsonText): var {
        return AppLogic.parseState(jsonText);
    }

    function menuItems(entry, pinned, isRun, runningCount): var {
        return AppLogic.menuItems(entry, pinned, isRun, runningCount, root.workspaceMenuItems());
    }

    function applyState(jsonText): void {
        root.state = root.parseState(jsonText);
    }

    function saveState(): void {
        const payload = {};
        payload["pinned"] = root.pinned;
        payload["hidden"] = root.hidden;
        payload["recent"] = root.recent;
        idAppState.saveJson(payload);
    }
}
