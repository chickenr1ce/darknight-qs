pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    readonly property var tabs: [
        { key: "dashboard", title: qsTr("Dashboard") },
        { key: "apps", title: qsTr("Apps") },
        { key: "performance", title: qsTr("Performance") },
        { key: "workspaces", title: qsTr("Workspaces") }
    ]

    property alias dashboardVisible: idPanelState.visible
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    property string activeTab: "dashboard"
    property int junctionRadius: Globals.junctionRadiusDefault

    onJunctionRadiusChanged: root.saveJunctionRadius()

    PanelState {
        id: idPanelState
    }

    StateFile {
        id: idJunctionState

        name: "dashboard-junction"
        createDir: true
        onParsed: text => root.applyJunctionRadius(text)
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): string {
            const screen = MonitorService.focusedScreen();
            if (screen === null)
                return "error: no screen";
            root.toggleDashboardAt(screen, screen.width / 2);
            return "ok";
        }

        function open(): string {
            const screen = MonitorService.focusedScreen();
            if (screen === null)
                return "error: no screen";
            root.openDashboardAt(screen, screen.width / 2);
            return "ok";
        }

        function close(): string {
            root.closeDashboardFromOutside();
            return "ok";
        }

        function apps(): string {
            const screen = MonitorService.focusedScreen();
            if (screen === null)
                return "error: no screen";
            root.toggleAppsAt(screen, screen.width / 2);
            return "ok";
        }

        function settings(section: string): string {
            const safe = /^[a-z0-9-]{1,32}$/.test(section) ? section : "?";
            const registry = SettingsService.sectionRegistry;
            let known = false;
            for (let i = 0; i < registry.length; i++) {
                if (registry[i].key === section) {
                    known = true;
                    break;
                }
            }
            if (!known)
                return "error: no section " + safe;
            const screen = MonitorService.focusedScreen();
            if (screen === null)
                return "error: no screen";
            root.openSettingsAt(screen, screen.width / 2, section);
            return "ok: " + section;
        }
    }

    function toggleDashboardAt(screen, centerX: real): void {
        if (!root.dashboardVisible)
            root.activeTab = "dashboard";
        idPanelState.toggleAt(screen, centerX)
    }

    function openAppsAt(screen, centerX: real): void {
        root.activeTab = "apps";
        idPanelState.openAt(screen, centerX);
    }

    function toggleAppsAt(screen, centerX: real): void {
        if (!root.dashboardVisible) {
            root.activeTab = "apps";
            idPanelState.openAt(screen, centerX);
            return;
        }
        if (root.activeTab === "apps") {
            idPanelState.toggle();
            return;
        }
        root.activeTab = "apps";
    }

    function openDashboardAt(screen, centerX: real): void {
        root.activeTab = "dashboard";
        idPanelState.openAt(screen, centerX)
    }

    function selectTab(key: string): void {
        root.activeTab = key;
    }

    function openSettings(sectionKey: string): void {
        root.activeTab = "settings";
        SettingsService.requestSection(sectionKey);
    }

    function openSettingsAt(screen, centerX: real, sectionKey: string): void {
        root.activeTab = "settings";
        SettingsService.requestSection(sectionKey);
        idPanelState.openAt(screen, centerX);
    }

    function close(): void {
        idPanelState.visible = false;
    }

    function closeDashboardFromOutside(): void {
        idPanelState.closeFromOutside()
    }

    function clampJunctionRadius(value, fallback: int): int {
        const n = Math.round(Number(value));
        if (isNaN(n))
            return fallback;
        return Math.max(0, Math.min(Globals.junctionRadiusMax, n));
    }

    function setJunctionRadius(value): void {
        const next = root.clampJunctionRadius(value, root.junctionRadius);
        if (next !== root.junctionRadius)
            root.junctionRadius = next;
    }

    function applyJunctionRadius(jsonText: string): void {
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
        root.setJunctionRadius(parsed.junctionRadius);
    }

    function saveJunctionRadius(): void {
        const payload = {};
        payload["junctionRadius"] = root.junctionRadius;
        idJunctionState.saveJson(payload);
    }
}
