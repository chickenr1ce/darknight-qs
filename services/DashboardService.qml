pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services

Singleton {
    id: root

    property alias dashboardVisible: idPanelState.visible
    property alias dashboardLastOutsideCloseAt: idPanelState.lastOutsideCloseAt
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    property int junctionRadius: Globals.junctionRadiusDefault

    onJunctionRadiusChanged: {
        if (idJunctionState.loading || !idJunctionState.loaded)
            return;
        root.saveJunctionRadius();
    }

    onDashboardVisibleChanged: {
        if (root.dashboardVisible)
            SettingsService.close();
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
        idPanelState.toggle()
    }

    function toggleDashboardAt(screen, centerX: real): void {
        idPanelState.toggleAt(screen, centerX)
    }

    function openDashboardAt(screen, centerX: real): void {
        idPanelState.openAt(screen, centerX)
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
