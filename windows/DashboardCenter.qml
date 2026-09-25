pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    anchorScreen: DashboardService.anchorScreen
    anchorCenterX: DashboardService.anchorCenterX
    panelVisible: DashboardService.dashboardVisible
    panelWidth: Globals.dashboardWidth
    panelMaxHeight: Globals.dashboardMaxHeight
    onOutsideClicked: DashboardService.closeDashboardFromOutside()

    PanelHeader {
        id: idDashboardHeader

        title: qsTr("Dashboard")
        showBadge: false
    }
}
