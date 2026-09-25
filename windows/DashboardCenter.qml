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
    attachedToBar: true
    junctionRadius: DashboardService.junctionRadius
    onOutsideClicked: DashboardService.closeDashboardFromOutside()

    readonly property real halfBlockWidth: (Globals.dashboardWidth - 2 * Globals.panelPadding - Math.round(Globals.dashboardWidth * 0.27) - 2 * Globals.rowSpacing) / 2

    DashboardTabs {
        id: idDashboardTabs

        Layout.fillWidth: true
    }

    RowLayout {
        id: idDashboardBody

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        ColumnLayout {
            id: idDashboardMain

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignTop

            spacing: Globals.rowSpacing

            RowLayout {
                id: idDashboardTopRow

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                DashboardWeatherBlock {
                    id: idDashboardWeather

                    Layout.preferredWidth: root.halfBlockWidth
                }

                DashboardSystemBlock {
                    id: idDashboardSystem

                    Layout.preferredWidth: root.halfBlockWidth
                }
            }

            DashboardCalendarBlock {
                id: idDashboardCalendar

                Layout.fillWidth: true
            }

            RowLayout {
                id: idDashboardMetersRow

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                DashboardCpuBlock {
                    id: idDashboardCpu

                    Layout.preferredWidth: root.halfBlockWidth
                }

                DashboardVolumeBlock {
                    id: idDashboardVolume

                    Layout.preferredWidth: root.halfBlockWidth
                }
            }
        }

        DashboardPlayerBlock {
            id: idDashboardPlayer

            Layout.preferredWidth: Math.round(Globals.dashboardWidth * 0.27)
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
        }
    }
}
