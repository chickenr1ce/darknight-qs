pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property alias dashboardVisible: idPanelState.visible
    property alias dashboardLastOutsideCloseAt: idPanelState.lastOutsideCloseAt
    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    PanelState {
        id: idPanelState
    }

    function toggleDashboard(): void {
        idPanelState.toggle()
    }

    function toggleDashboardAt(screen, centerX: real): void {
        idPanelState.toggleAt(screen, centerX)
    }

    function closeDashboardFromOutside(): void {
        idPanelState.closeFromOutside()
    }
}
