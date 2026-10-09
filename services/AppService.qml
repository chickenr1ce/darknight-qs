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

    property var state: ({})

    property var iconCache: ({})

    readonly property var entries: root.buildRecords()

    readonly property var toplevels: Hyprland.toplevels?.values ?? []

    readonly property var toplevelClassLists: {
        const tops = root.toplevels;
        const lists = [];
        for (let i = 0; i < tops.length; i++)
            lists.push(HyprlandFocus.classSources(tops[i]));
        return lists;
    }

    property int runningMapRevision: 0

    readonly property var runningMap: root.runningMapRevision >= 0
        ? AppLogic.runningCounts(root.entries, root.toplevelClassLists)
        : {}

    readonly property var pinned: root.state.pinned || []
    readonly property var hidden: root.state.hidden || []
    readonly property var recent: root.state.recent || []

    readonly property var hiddenEntries: {
        const records = root.resolveHidden(root.entries, root.hidden);
        const out = [];
        for (let i = 0; i < records.length; i++) {
            const record = records[i].entry;
            if (record) {
                out.push({ id: record.id, name: record.name, source: root.iconFor(record) });
                continue;
            }
            const entry = DesktopEntries.byId(records[i].id);
            out.push({
                id: records[i].id,
                name: entry ? entry.name : records[i].id,
                source: entry ? root.iconForName(entry.icon) : ""
            });
        }
        return out;
    }

    onStateChanged: root.saveState()
    onEntriesChanged: root.iconCache = ({})

    StateFile {
        id: idAppState

        name: "app-launcher"
        createDir: true
        onParsed: text => root.applyState(text)
    }

    function buildRecords(): var {
        const list = DesktopEntries.applications.values;
        const plain = [];
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            if (!entry)
                continue;
            const actions = [];
            const sourceActions = entry.actions || [];
            for (let j = 0; j < sourceActions.length; j++) {
                const action = sourceActions[j];
                if (action)
                    actions.push({ name: action.name, icon: action.icon, index: j });
            }
            plain.push({
                id: entry.id,
                name: entry.name,
                genericName: entry.genericName,
                keywords: entry.keywords,
                icon: entry.icon,
                startupClass: entry.startupClass,
                runInTerminal: entry.runInTerminal,
                command: entry.command,
                actions: actions,
                entry: entry
            });
        }
        return AppLogic.makeRecords(plain);
    }

    function rebuildRunningMap(): var {
        root.runningMapRevision = root.runningMapRevision + 1;
        return root.runningMap;
    }

    function iconFor(record): string {
        if (!record || record.icon === "")
            return "";
        return root.iconForName(record.icon);
    }

    function iconForName(name): string {
        if (!name)
            return "";
        const cached = root.iconCache[name];
        if (typeof cached === "string")
            return cached;
        const path = Quickshell.iconPath(name, true);
        root.iconCache[name] = path;
        return path;
    }

    function launch(record, keepOpen): void {
        if (!record)
            return;
        const entry = record.entry;
        if (!entry)
            return;
        if (record.runInTerminal)
            Quickshell.execDetached(root.terminalPrefix.concat(record.command || []));
        else
            entry.execute();
        root.recordLaunch(record.id);
        if (!keepOpen)
            DashboardService.close();
    }

    function launchKeep(record): void {
        root.launch(record, true);
    }

    function launchAction(record, index): void {
        const entry = record ? record.entry : null;
        if (!entry || !entry.actions || index < 0 || index >= entry.actions.length)
            return;
        entry.actions[index].execute();
        root.recordLaunch(record.id);
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

    function activeWorkspaceFor(hyprMonitors, monitorName): int {
        for (let i = 0; i < hyprMonitors.length; i++) {
            if (hyprMonitors[i].name === monitorName && hyprMonitors[i].activeWorkspace)
                return hyprMonitors[i].activeWorkspace.id;
        }
        return -1;
    }

    function workspaceMenuItems(): var {
        const name = root.anchorMonitorName();
        const hyprMonitors = Hyprland.monitors?.values ?? [];
        const enabled = MonitorService.enabledMonitors;
        const enabledNames = [];
        for (let i = 0; i < enabled.length; i++) {
            if (enabled[i] && enabled[i].name)
                enabledNames.push(enabled[i].name);
        }
        const monitors = [];
        const orderedNames = MonitorService.orderedMonitors;
        for (let i = 0; i < orderedNames.length; i++) {
            const monitorName = orderedNames[i];
            monitors.push({
                name: monitorName,
                first: MonitorService.firstWorkspaceFor(monitorName),
                active: root.activeWorkspaceFor(hyprMonitors, monitorName),
                disabled: enabledNames.indexOf(monitorName) === -1
            });
        }
        const occupied = [];
        const tops = root.toplevels;
        for (let i = 0; i < tops.length; i++) {
            const workspace = tops[i].workspace;
            if (workspace && occupied.indexOf(workspace.id) === -1)
                occupied.push(workspace.id);
        }
        const fallbackName = name !== ""
            ? name
            : (orderedNames.length > 0 ? orderedNames[0] : "");
        const fallback = {
            name: fallbackName,
            first: MonitorService.firstWorkspaceFor(fallbackName),
            active: root.activeWorkspaceFor(hyprMonitors, fallbackName)
        };
        return AppLogic.workspaceMenu(monitors, MonitorService.workspacesPerMonitor, name, occupied, fallback);
    }

    function launchOnWorkspace(record, workspace, keepOpen): void {
        if (!record || workspace < 1)
            return;
        const parts = record.runInTerminal ? root.terminalPrefix.concat(record.command || []) : (record.command || []);
        const command = AppLogic.shellCommand(parts);
        if (command === "")
            return;
        Hyprland.dispatch(`hl.dsp.exec_cmd("${MonitorLogic.escapeLua(command)}", { workspace = ${workspace} })`);
        root.recordLaunch(record.id);
        if (!keepOpen)
            DashboardService.close();
    }

    function copyCommand(record): void {
        if (!record)
            return;
        root.copyText((record.command || []).join(" "));
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

    function windowsFor(record): var {
        if (!record)
            return [];
        const keys = record.keys || [];
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

    function runningCount(record): int {
        if (!record)
            return 0;
        const count = root.runningMap[record.id];
        return typeof count === "number" ? count : 0;
    }

    function focusWindows(record): void {
        if (!record)
            return;
        const windows = root.windowsFor(record);
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

    function killWindows(record): void {
        const windows = root.windowsFor(record);
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

    function makeRecords(list): var {
        return AppLogic.makeRecords(list);
    }

    function runningCounts(records, toplevelClassLists): var {
        return AppLogic.runningCounts(records, toplevelClassLists);
    }

    function sections(query): var {
        return AppLogic.sections(root.visibleEntries(root.entries, root.hidden), root.pinned, root.recent, query);
    }

    function browseRows(): var {
        return AppLogic.browseRows(root.visibleEntries(root.entries, root.hidden), root.pinned, root.recent);
    }

    function resultRows(query): var {
        return AppLogic.resultRows(root.visibleEntries(root.entries, root.hidden), root.pinned, root.recent, query);
    }

    function parseState(jsonText): var {
        return AppLogic.parseState(jsonText);
    }

    function menuItems(record, pinned, isRun, runningCount): var {
        return AppLogic.menuItems(record, pinned, isRun, runningCount, root.workspaceMenuItems());
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
