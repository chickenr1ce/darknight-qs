pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services

Singleton {
    id: root

    readonly property var screenNames: Globals.screensByPosition.map(screen => screen.name)

    property int workspacesPerMonitor: 5

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

    StateFile {
        id: idMonitorState

        name: "monitor-settings"
        createDir: true
        onParsed: text => root.applySettings(text)
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
