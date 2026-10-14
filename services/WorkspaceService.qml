pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import "WorkspaceLogic.js" as WorkspaceLogic

Singleton {
    id: root

    // Set by the view while the Workspaces tab is on screen; the refresh path
    // and the model rebuild only run then.
    property bool visibleTab: false
    property var model: []
    property bool rebuildPending: false

    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property var hyprMonitors: Hyprland.monitors?.values ?? []
    readonly property var hyprWorkspaces: Hyprland.workspaces?.values ?? []
    readonly property var hyprToplevels: Hyprland.toplevels?.values ?? []

    // Socket2 events that change geometry, stacking, the float/fullscreen
    // state, workspace membership, focus, urgency, or a window title.
    readonly property var layoutEvents: [
        "openwindow", "closewindow", "movewindow", "movewindowv2",
        "changefloatingmode", "fullscreen", "workspace", "workspacev2",
        "focusedmon", "moveworkspace", "moveworkspacev2", "activewindowv2",
        "urgent", "windowtitlev2"
    ]

    onVisibleTabChanged: {
        if (root.visibleTab) {
            root.refresh();
            root.rebuild();
        } else {
            idWorkspacesRefreshTimer.stop();
        }
    }

    Connections {
        id: idHyprlandWatch

        target: Hyprland

        function onRawEvent(event): void {
            if (!root.visibleTab)
                return;
            if (!root.capturesLayout(event.name))
                return;
            idWorkspacesRefreshTimer.restart();
        }

        function onActiveToplevelChanged(): void {
            root.scheduleRebuild();
        }

        function onFocusedMonitorChanged(): void {
            root.scheduleRebuild();
        }
    }

    // One restartable timer coalesces a burst of socket2 events into a single
    // Hyprland.refresh*() round trip.
    Timer {
        id: idWorkspacesRefreshTimer

        interval: Globals.workspacesRefreshMs
        repeat: false
        onTriggered: {
            if (!root.visibleTab)
                return;
            root.refresh();
        }
    }

    // lastIpcObject is a snapshot that only moves on a refresh, and a changed
    // snapshot does not reliably re-run a JS binding that reads it, so each
    // watched object drives an explicit, coalesced rebuild.
    Instantiator {
        id: idToplevelWatchers

        model: root.visibleTab ? Hyprland.toplevels : null

        delegate: Connections {
            required property var modelData

            target: modelData
            function onLastIpcObjectChanged(): void {
                root.scheduleRebuild();
            }
        }
    }

    Instantiator {
        id: idMonitorWatchers

        model: root.visibleTab ? Hyprland.monitors : null

        delegate: Connections {
            required property var modelData

            target: modelData
            function onActiveWorkspaceChanged(): void {
                root.scheduleRebuild();
            }
            function onFocusedChanged(): void {
                root.scheduleRebuild();
            }
        }
    }

    Instantiator {
        id: idWorkspaceWatchers

        model: root.visibleTab ? Hyprland.workspaces : null

        delegate: Connections {
            required property var modelData

            target: modelData
            function onActiveChanged(): void {
                root.scheduleRebuild();
            }
            function onFocusedChanged(): void {
                root.scheduleRebuild();
            }
            function onUrgentChanged(): void {
                root.scheduleRebuild();
            }
        }
    }

    Connections {
        id: idToplevelListWatch

        target: Hyprland.toplevels

        function onValuesChanged(): void {
            root.scheduleRebuild();
        }
    }

    Connections {
        id: idMonitorListWatch

        target: Hyprland.monitors

        function onValuesChanged(): void {
            root.scheduleRebuild();
        }
    }

    Connections {
        id: idWorkspaceListWatch

        target: Hyprland.workspaces

        function onValuesChanged(): void {
            root.scheduleRebuild();
        }
    }

    Connections {
        id: idMonitorServiceWatch

        target: MonitorService

        function onEnabledMonitorsChanged(): void {
            root.scheduleRebuild();
        }
        function onMonitorsChanged(): void {
            root.scheduleRebuild();
        }
        function onOrderedMonitorsChanged(): void {
            root.scheduleRebuild();
        }
        function onWorkspacesPerMonitorChanged(): void {
            root.scheduleRebuild();
        }
    }

    function capturesLayout(name): bool {
        return root.layoutEvents.indexOf(String(name ?? "")) !== -1;
    }

    function refresh(): void {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }

    function scheduleRebuild(): void {
        if (!root.visibleTab || root.rebuildPending)
            return;
        root.rebuildPending = true;
        Qt.callLater(root.rebuild);
    }

    function rebuild(): void {
        root.rebuildPending = false;
        root.model = root.buildModel();
    }

    // --- one-line delegates into WorkspaceLogic ---
    function tileWidth(viewWidth, count, gap): real {
        return WorkspaceLogic.tileWidth(viewWidth, count, gap);
    }

    function dropTarget(point, tileRects): var {
        return WorkspaceLogic.dropTarget(point, tileRects);
    }

    function moveDecision(sourceId, targetId): int {
        return WorkspaceLogic.moveDecision(sourceId, targetId);
    }

    function inBlocks(workspaceId, blocks): bool {
        return WorkspaceLogic.inBlocks(workspaceId, blocks);
    }

    function monitorSnapshot(source): var {
        return WorkspaceLogic.monitorSnapshot(source);
    }

    function monitorBlocks(entries, perMonitor, windows, activeIds, focusedName, focusedAddress): var {
        return WorkspaceLogic.monitorBlocks(entries, perMonitor, windows, activeIds, focusedName, focusedAddress);
    }

    // --- model plumbing ---
    function buildModel(): var {
        const entries = root.enabledMonitorInfo();
        const windows = root.windowEntries(root.blocksFor(entries));
        const activeIds = root.activeWorkspaceIds();
        const focusedAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "";
        const focusedName = root.focusedMonitorName;
        return root.monitorBlocks(entries, MonitorService.workspacesPerMonitor, windows, activeIds,
            focusedName, focusedAddress);
    }

    function blocksFor(entries): var {
        const blocks = [];
        for (let i = 0; i < entries.length; i++)
            blocks.push({ first: entries[i].first, count: MonitorService.workspacesPerMonitor });
        return blocks;
    }

    function enabledMonitorInfo(): var {
        const names = MonitorService.orderedMonitors;
        const enabled = MonitorService.enabledMonitors;
        const hypr = root.hyprMonitors;
        const byName = {};
        for (let i = 0; i < hypr.length; i++) {
            if (hypr[i] && hypr[i].name)
                byName[hypr[i].name] = hypr[i];
        }
        const out = [];
        for (let i = 0; i < names.length; i++) {
            const name = names[i];
            if (!root.isEnabled(name, enabled))
                continue;
            const source = byName[name];
            if (!source)
                continue;
            out.push({ monitor: root.monitorSnapshot(source), first: MonitorService.firstWorkspaceFor(name) });
        }
        return out;
    }

    function isEnabled(name, enabled): bool {
        for (let i = 0; i < enabled.length; i++) {
            if (enabled[i] && enabled[i].name === name)
                return true;
        }
        return false;
    }

    function windowEntries(blocks): var {
        const tops = root.hyprToplevels;
        const out = [];
        for (let i = 0; i < tops.length; i++) {
            const top = tops[i];
            if (!top)
                continue;
            const ipc = top.lastIpcObject ?? {};
            const workspace = ipc.workspace;
            if (!root.inBlocks(workspace ? workspace.id : -1, blocks))
                continue;
            const cls = ipc["class"];
            const name = cls === undefined || cls === null ? "" : String(cls);
            out.push({
                address: top.address ?? "",
                cls: name,
                title: ipc.title === undefined || ipc.title === null ? (top.title ?? "") : String(ipc.title),
                app: AppService.appNameForClass(name),
                icon: AppService.iconForClass(name),
                at: ipc.at,
                size: ipc.size,
                floating: ipc.floating === true,
                // Hyprland reports a mode: 0 none, 1 maximized, 2 fullscreen,
                // 3 both. Maximized keeps its real (work-area) geometry.
                fullscreen: ipc.fullscreen === true || Number(ipc.fullscreen) >= 2,
                urgent: top.urgent === true,
                workspaceId: workspace.id
            });
        }
        return out;
    }

    function activeWorkspaceIds(): var {
        const list = root.hyprWorkspaces;
        const ids = [];
        for (let i = 0; i < list.length; i++) {
            const workspace = list[i];
            if (workspace && workspace.active === true)
                ids.push(workspace.id);
        }
        return ids;
    }

    // --- window menu ---
    function windowMenuItems(record): var {
        return WorkspaceLogic.windowMenuItems(record, root.windowMoveTargets(record));
    }

    function windowMoveTargets(record): var {
        const entries = root.enabledMonitorInfo();
        const monitors = [];
        const blocks = [];
        for (let i = 0; i < entries.length; i++) {
            monitors.push({ name: entries[i].monitor.name });
            blocks.push({ first: entries[i].first, count: MonitorService.workspacesPerMonitor });
        }
        const currentId = record ? record.workspaceId : -1;
        return WorkspaceLogic.moveTargets(monitors, blocks, currentId);
    }

    function menuAction(item): string {
        return WorkspaceLogic.menuAction(item);
    }

    function runMenuItem(item, record): void {
        if (!record)
            return;
        const action = root.menuAction(item);
        if (action === "")
            return;
        if (action === "moveWindow") {
            root.moveWindow(record.address, item.workspace);
        } else if (action === "copyWindowClass" || action === "copyWindowTitle") {
            root[action](record);
        } else {
            root[action](record.address);
        }
    }

    function copyWindowClass(record): void {
        AppService.copyText(record ? record.cls : "");
    }

    function copyWindowTitle(record): void {
        AppService.copyText(record ? record.title : "");
    }

    // --- dispatch actions ---
    function switchTo(id): void {
        const workspaceId = Math.round(Number(id));
        if (!isFinite(workspaceId) || workspaceId < 1)
            return;
        // The dashboard stays open so the map shows the switch land.
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspaceId} })`);
    }

    function focusWindow(address): void {
        const target = String(address ?? "");
        if (target === "")
            return;
        DashboardService.close();
        HyprlandFocus.focusAddress(target);
    }

    function moveWindow(address, id): void {
        const target = WorkspaceLogic.selector(address);
        const workspaceId = Math.round(Number(id));
        if (target === "" || !isFinite(workspaceId) || workspaceId < 1)
            return;
        // Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an
        // unfocused window: it moved to workspace 9 while the active workspace
        // and focus stayed put. Hyprland ≥0.56 evaluates IPC as Lua, so a
        // legacy dispatcher string fails (as modules/Workspaces.qml notes). The
        // confirmed call is:
        //   hl.dsp.window.move({ workspace = N, follow = false, window = "address:0x<hex>" })
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, follow = false, window = "address:${target}" })`);
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }

    // Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an
    // unfocused window, by address: it toggled floating and left the active
    // workspace and focus alone. Hyprland >=0.56 evaluates IPC as Lua, so the
    // confirmed call is:
    //   hl.dsp.window.float({ action = "toggle", window = "address:0x<hex>" })
    function toggleFloating(address): void {
        const target = WorkspaceLogic.selector(address);
        if (target === "")
            return;
        Hyprland.dispatch(`hl.dsp.window.float({ action = "toggle", window = "address:${target}" })`);
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }

    // Confirmed on Hyprland 0.56.2 with `hyprctl dispatch` against an
    // unfocused window, by address: it toggled fullscreen and left the active
    // workspace alone, but Hyprland moves focus to the fullscreened window.
    // The confirmed call is:
    //   hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = "address:0x<hex>" })
    function toggleFullscreen(address): void {
        const target = WorkspaceLogic.selector(address);
        if (target === "")
            return;
        Hyprland.dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = "address:${target}" })`);
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }

    // Graceful close, the same call the Apps tab's Kill uses; nothing is
    // force-killed and an app may still prompt to save.
    function closeWindow(address): void {
        const target = WorkspaceLogic.normalizeAddress(address);
        if (target === "")
            return;
        const tops = root.hyprToplevels;
        for (let i = 0; i < tops.length; i++) {
            const top = tops[i];
            if (!top || WorkspaceLogic.normalizeAddress(top.address) !== target)
                continue;
            const handle = top.wayland;
            if (handle)
                handle.close();
            break;
        }
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }
}
