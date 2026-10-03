pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services

Singleton {
    id: root

    readonly property var tabs: [
        { key: "dashboard", title: qsTr("Dashboard") },
        { key: "media", title: qsTr("Media") },
        { key: "performance", title: qsTr("Performance") },
        { key: "workspaces", title: qsTr("Workspaces") }
    ]

    property alias dashboardVisible: idPanelState.visible
    property alias dashboardLastOutsideCloseAt: idPanelState.lastOutsideCloseAt
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    property string activeTab: "dashboard"
    property int junctionRadius: Globals.junctionRadiusDefault

    onJunctionRadiusChanged: {
        if (idJunctionState.loading || !idJunctionState.loaded)
            return;
        root.saveJunctionRadius();
    }

    PanelState {
        id: idPanelState
    }

    StateFile {
        id: idJunctionState

        name: "dashboard-junction"
        createDir: true
        onParsed: text => root.applyJunctionRadius(text)
    }

    function toggleDashboard(): void {
        if (!root.dashboardVisible)
            root.activeTab = "dashboard";
        idPanelState.toggle()
    }

    function toggleDashboardAt(screen, centerX: real): void {
        if (!root.dashboardVisible)
            root.activeTab = "dashboard";
        idPanelState.toggleAt(screen, centerX)
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
        idJunctionState.save(JSON.stringify(payload) + "\n");
    }
}
