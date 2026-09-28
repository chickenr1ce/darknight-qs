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

    onDashboardVisibleChanged: {
        if (root.dashboardVisible)
            SettingsService.close();
    }

    PanelState {
        id: idPanelState
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
}
