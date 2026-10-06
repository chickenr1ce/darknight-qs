pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    readonly property var screenNames: Globals.screensByPosition.map(screen => screen.name)

    property int workspacesPerMonitor: 5
    property var monitors: []
    property var monitorNames: []
    property bool monitorsLoaded: false
    property bool pendingRefresh: false
    property bool toggleSettling: false
    property bool settleGraceUsed: false
    property int toggleEpoch: 0
    property int pollEpoch: 0

    readonly property var enabledMonitors: root.monitors.filter(monitor => !monitor.disabled)
    readonly property bool multiMonitor: root.enabledMonitors.length > 1
    readonly property bool toggleBusy: idCommandProcess.running || root.toggleSettling

    readonly property int screenCount: Globals.screensByPosition.length

    readonly property var orderedMonitors: {
        const ordered = [];
        if (Globals.primaryMonitor !== "")
            ordered.push(Globals.primaryMonitor);
        const rest = Globals.screensByPosition;
        for (let i = 0; i < rest.length; i++) {
            if (rest[i].name !== Globals.primaryMonitor)
                ordered.push(rest[i].name);
        }
        return ordered;
    }

    onScreenCountChanged: root.refreshMonitors()

    StateFile {
        id: idMonitorState

        name: "monitor-settings"
        createDir: true
        onParsed: text => root.applySettings(text)
    }

    Timer {
        id: idMonitorsTimer

        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMonitors()
    }

    Process {
        id: idMonitorsProcess

        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: idMonitorsCollector
        onExited: root.consumePendingRefresh()
    }

    StdioCollector {
        id: idMonitorsCollector

        onStreamFinished: root.applyMonitors(idMonitorsCollector.text)
    }

    Process {
        id: idCommandProcess

        onExited: root.refreshMonitors()
    }

    Timer {
        id: idCommandWatchdog

        interval: 5000
        repeat: false
        onTriggered: {
            if (idCommandProcess.running) {
                idCommandProcess.running = false;
                root.toggleSettling = false;
                root.refreshMonitors();
                return;
            }
            if (!root.toggleSettling)
                return;
            if (!root.settleGraceUsed) {
                root.settleGraceUsed = true;
                idCommandWatchdog.restart();
                return;
            }
            root.toggleSettling = false;
            idMonitorsProcess.running = false;
            root.refreshMonitors();
        }
    }

    function isValidPrimary(name: string): bool {
        return name === "" || root.screenNames.indexOf(name) !== -1;
    }

    function setPrimary(name: string): void {
        const next = root.isValidPrimary(name) ? name : "";
        if (next !== Globals.primaryMonitorOverride)
            Globals.primaryMonitorOverride = next;
        root.saveSettings();
    }

    function firstWorkspaceFor(monitorName: string): int {
        const index = root.orderedMonitors.indexOf(monitorName);
        if (index === -1)
            return 1;
        return index * root.workspacesPerMonitor + 1;
    }

    function clampWorkspacesPerMonitor(value, fallback: int): int {
        const count = Math.round(Number(value));
        if (isNaN(count))
            return fallback;
        return Math.max(1, Math.min(20, count));
    }

    function setWorkspacesPerMonitor(value): void {
        const next = root.clampWorkspacesPerMonitor(value, root.workspacesPerMonitor);
        if (next === root.workspacesPerMonitor)
            return;
        root.workspacesPerMonitor = next;
        root.saveSettings();
    }

    function monitorByName(name: string): var {
        for (let i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].name === name)
                return root.monitors[i];
        }
        return null;
    }

    function rowState(name: string): var {
        const list = root.monitors;
        let enabled = 0;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].disabled)
                enabled += 1;
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].name !== name)
                continue;
            return {
                monitor: list[i],
                lastDisplay: !list[i].disabled && enabled <= 1
            };
        }
        return null;
    }

    function refreshMonitors(): void {
        if (idMonitorsProcess.running || idCommandProcess.running) {
            root.pendingRefresh = true;
            return;
        }
        root.pendingRefresh = false;
        root.pollEpoch = root.toggleEpoch;
        idMonitorsProcess.running = true;
    }

    function consumePendingRefresh(): void {
        if (!root.pendingRefresh)
            return;
        root.pendingRefresh = false;
        root.refreshMonitors();
    }

    function escapeLua(value: string): string {
        return value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function modeFor(monitor): string {
        const width = Math.round(Number(monitor.width));
        const height = Math.round(Number(monitor.height));
        const refresh = Math.round(Number(monitor.refreshRate));
        if (!(width > 0) || !(height > 0) || !(refresh > 0))
            return "preferred";
        return width + "x" + height + "@" + refresh;
    }

    function positionFor(monitor): string {
        const x = Math.round(Number(monitor.x));
        const y = Math.round(Number(monitor.y));
        if (isNaN(x) || isNaN(y))
            return "auto";
        return x + "x" + y;
    }

    function scaleFor(monitor): real {
        const scale = Number(monitor.scale);
        return scale > 0 ? scale : 1;
    }

    function applyMonitors(text: string): void {
        let parsed = null;
        try
        {
            parsed = JSON.parse(text);
        }
        catch (e)
        {
            parsed = null;
        }
        root.monitorsLoaded = true;
        if (!Array.isArray(parsed))
            return;
        const list = [];
        for (let i = 0; i < parsed.length; i++) {
            const monitor = parsed[i];
            if (!monitor || typeof monitor.name !== "string" || monitor.name === "")
                continue;
            list.push({
                name: monitor.name,
                description: typeof monitor.description === "string" ? monitor.description : "",
                model: typeof monitor.model === "string" ? monitor.model : "",
                disabled: monitor.disabled === true,
                mode: root.modeFor(monitor),
                position: root.positionFor(monitor),
                scale: root.scaleFor(monitor)
            });
        }
        const names = [];
        for (let i = 0; i < list.length; i++)
            names.push(list[i].name);
        if (JSON.stringify(list) !== JSON.stringify(root.monitors))
            root.monitors = list;
        if (JSON.stringify(names) !== JSON.stringify(root.monitorNames))
            root.monitorNames = names;
        if (root.pollEpoch === root.toggleEpoch)
            root.toggleSettling = false;
    }

    function setEnabled(name: string, enabled: bool): void {
        if (root.toggleBusy)
            return;
        const monitor = root.monitorByName(name);
        if (!monitor)
            return;
        if (monitor.disabled === !enabled)
            return;
        if (!enabled && !root.multiMonitor)
            return;
        const output = root.escapeLua(name);
        let spec = "hl.monitor({ output = \"" + output + "\", disabled = " + (enabled ? "false" : "true");
        if (enabled)
            spec += ", mode = \"" + monitor.mode + "\", position = \"" + monitor.position + "\", scale = " + monitor.scale;
        spec += " })";
        root.toggleEpoch += 1;
        root.settleGraceUsed = false;
        root.toggleSettling = true;
        idCommandProcess.command = ["hyprctl", "eval", spec];
        idCommandProcess.running = true;
        idCommandWatchdog.restart();
    }

    function applySettings(jsonText: string): void {
        let parsed = null;
        try
        {
            parsed = JSON.parse(jsonText);
        }
        catch (e)
        {
            return;
        }
        if (!parsed || typeof parsed !== "object")
            return;
        if (typeof parsed.primary === "string" && parsed.primary !== Globals.primaryMonitorOverride)
            Globals.primaryMonitorOverride = parsed.primary;
        const count = Number(parsed.workspacesPerMonitor);
        if (!isNaN(count))
            root.workspacesPerMonitor = root.clampWorkspacesPerMonitor(count, root.workspacesPerMonitor);
    }

    function saveSettings(): void {
        if (idMonitorState.loading || !idMonitorState.loaded)
            return;
        const payload = {};
        payload["primary"] = Globals.primaryMonitorOverride;
        payload["workspacesPerMonitor"] = root.workspacesPerMonitor;
        idMonitorState.save(JSON.stringify(payload) + "\n");
    }
}
