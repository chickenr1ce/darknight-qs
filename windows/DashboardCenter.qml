pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.dev
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
    onPanelVisibleChanged: if (root.panelVisible) {
        SystemInfo.refresh();
        WeatherService.refresh();
    }

    Component.onCompleted: {
        DevGeometry.register("dashboard.weather", idDashboardWeather);
        DevGeometry.register("dashboard.system", idDashboardSystem);
        DevGeometry.register("dashboard.player", idDashboardPlayer);
        DevGeometry.register("dashboard.theme", idDashboardTheme);
        DevGeometry.register("dashboard.cpu", idDashboardCpu);
        DevGeometry.register("dashboard.volume", idDashboardVolume);
    }

    readonly property real halfBlockWidth: (Globals.dashboardWidth - 2 * Globals.panelPadding - Math.round(Globals.dashboardWidth * 0.27) - 2 * Globals.rowSpacing) / 2

    RowLayout {
        id: idDashboardHeader

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        DashboardTabs {
            id: idDashboardTabs

            Layout.fillWidth: true
        }

        IconButton {
            id: idDashboardSettings

            Layout.alignment: Qt.AlignVCenter

            glyph: Icons.cog
            glyphSize: Globals.uiIconSize
            restColor: Colors.textSubtle
            accessibleName: qsTr("Settings")
            onClicked: SettingsService.open(DashboardService.anchorScreen)
        }
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
                    Layout.fillHeight: true
                }

                DashboardSystemBlock {
                    id: idDashboardSystem

                    Layout.preferredWidth: root.halfBlockWidth
                    Layout.fillHeight: true
                }
            }

            DashboardPlayerBlock {
                id: idDashboardPlayer

                Layout.fillWidth: true
            }
        }

        DashboardThemeBlock {
            id: idDashboardTheme

            Layout.preferredWidth: Math.round(Globals.dashboardWidth * 0.27)
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignTop
        }
    }

    RowLayout {
        id: idDashboardMetersRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        DashboardCpuBlock {
            id: idDashboardCpu

            Layout.preferredWidth: Globals.dashboardUsageWidth
            Layout.fillHeight: true
        }

        DashboardVolumeBlock {
            id: idDashboardVolume

            Layout.preferredWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
