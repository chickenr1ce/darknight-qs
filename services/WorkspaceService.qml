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

    // Every live read the model needs, captured once as plain data. The rules
    // that turn it into the model live in WorkspaceLogic.
    function snapshot(): var {
        const snapshot = root.monitorsSnapshot();
        snapshot.toplevels = root.toplevelsSnapshot();
        snapshot.workspaces = root.workspacesSnapshot();
        snapshot.focusedName = root.focusedMonitorName;
        snapshot.focusedAddress = Hyprland.activeToplevel ? Hyprland.activeToplevel.address : "";
        return snapshot;
    }

    // The monitor half alone, for callers that need no window data.
    function monitorsSnapshot(): var {
        const names = MonitorService.orderedMonitors;
        const enabled = MonitorService.enabledMonitors;
        const enabledNames = [];
        for (let i = 0; i < enabled.length; i++) {
            if (enabled[i] && enabled[i].name)
                enabledNames.push(enabled[i].name);
        }
        const firstWorkspace = {};
        for (let i = 0; i < names.length; i++)
            firstWorkspace[names[i]] = MonitorService.firstWorkspaceFor(names[i]);
        const hypr = root.hyprMonitors;
        const monitors = [];
        for (let i = 0; i < hypr.length; i++) {
            if (hypr[i] && hypr[i].name)
                monitors.push(root.monitorSnapshot(hypr[i]));
        }
        return {
            monitorNames: names,
            enabledNames: enabledNames,
            monitors: monitors,
            firstWorkspace: firstWorkspace,
            perMonitor: MonitorService.workspacesPerMonitor
        };
    }

    function toplevelsSnapshot(): var {
        const tops = root.hyprToplevels;
        const toplevels = [];
        for (let i = 0; i < tops.length; i++) {
            const top = tops[i];
            if (!top)
                continue;
            const ipc = top.lastIpcObject ?? {};
            const workspace = ipc.workspace;
            toplevels.push({
                address: top.address ?? "",
                title: top.title ?? "",
                urgent: top.urgent === true,
                app: AppService.appNameForClass(ipc["class"]),
                icon: AppService.iconForClass(ipc["class"]),
                ipc: {
                    class: ipc["class"],
                    title: ipc.title,
                    workspace: workspace ? { id: workspace.id } : null,
                    at: ipc.at,
                    size: ipc.size,
                    floating: ipc.floating,
                    fullscreen: ipc.fullscreen
                }
            });
        }
        return toplevels;
    }

    function workspacesSnapshot(): var {
        const list = root.hyprWorkspaces;
        const workspaces = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i])
                workspaces.push({ id: list[i].id, active: list[i].active === true });
        }
        return workspaces;
    }

    function buildModel(): var {
        return WorkspaceLogic.model(root.snapshot());
    }

    // --- window menu ---
    function windowMenuItems(record): var {
        return WorkspaceLogic.windowMenuItems(record, root.windowMoveTargets(record));
    }

    function windowMoveTargets(record): var {
        const snapshot = root.monitorsSnapshot();
        const entries = WorkspaceLogic.monitorEntries(snapshot);
        const monitors = [];
        const blocks = [];
        for (let i = 0; i < entries.length; i++) {
            monitors.push({ name: entries[i].monitor.name });
            blocks.push({ first: entries[i].first, count: snapshot.perMonitor });
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
        // The dashboard stays open so the map shows the switch land.
        HyprlandDispatch.focusWorkspace(id);
    }

    function focusWindow(address): void {
        const target = String(address ?? "");
        if (target === "")
            return;
        DashboardService.close();
        HyprlandFocus.focusAddress(target);
    }

    function moveWindow(address, id): void {
        if (!HyprlandDispatch.moveWindowToWorkspace(address, id, false))
            return;
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }

    function toggleFloating(address): void {
        if (!HyprlandDispatch.toggleFloating(address))
            return;
        Hyprland.refreshToplevels();
        root.scheduleRebuild();
    }

    function toggleFullscreen(address): void {
        if (!HyprlandDispatch.toggleFullscreen(address, "fullscreen"))
            return;
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
