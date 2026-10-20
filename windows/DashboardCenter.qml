pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.components
import qs.config
import qs.dev
import qs.services

PanelShell {
    id: root

    anchorScreen: DashboardService.anchorScreen
    anchorCenterX: DashboardService.anchorCenterX
    panelVisible: DashboardService.dashboardVisible
    geometryName: "dashboard.panel"
    panelWidth: Globals.dashboardWidth
    readonly property real appsMaxHeight: Math.max(Globals.dashboardMaxHeight,
        Math.round(Globals.dashboardAppsMaxFraction
            * (DashboardService.anchorScreen ? DashboardService.anchorScreen.height : 0)))
    panelMaxHeight: DashboardService.activeTab === "apps"
        ? root.appsMaxHeight
        : Globals.dashboardMaxHeight
    windowHeight: root.appsMaxHeight
    attachedToBar: true
    instantReveal: DashboardService.keyboardOpened
    junctionRadius: DashboardService.junctionRadius
    inputOverlay: DashboardService.activeTab === "workspaces"
        ? idDashboardWorkspacesView.menuInputBox
        : idDashboardAppsView.menuInputBox
    // Own namespace so Hyprland can skip its layer fade (no_anim layer rule);
    // the slide in PanelShell is the only motion; keyboard opens skip the opening slide.
    WlrLayershell.namespace: "quickshell-dashboard"
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
        DevGeometry.register("dashboard.settings", idDashboardSettingsView);
        idDashboardAppsView.registerProbe();
        idDashboardWorkspacesView.registerProbe();
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
            restColor: DashboardService.activeTab === "settings" ? Colors.accent : Colors.textSubtle
            accessibleName: qsTr("Settings")
            onClicked: DashboardService.openSettings("")
        }
    }

    RowLayout {
        id: idDashboardBody

        Layout.fillWidth: true

        visible: DashboardService.activeTab === "dashboard"
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

        visible: DashboardService.activeTab === "dashboard"
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

    Item {
        id: idDashboardPlaceholder

        Layout.fillWidth: true

        visible: DashboardService.activeTab !== "dashboard" && DashboardService.activeTab !== "settings" && DashboardService.activeTab !== "apps" && DashboardService.activeTab !== "workspaces"
        implicitHeight: idPlaceholderLabel.implicitHeight + 4 * Globals.panelPadding

        Text {
            id: idPlaceholderLabel

            anchors.centerIn: parent

            textFormat: Text.PlainText
            text: qsTr("Coming soon")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }
    }

    DashboardAppsView {
        id: idDashboardAppsView

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: DashboardService.activeTab === "apps"
        windowShown: root.visible
        windowRoom: root.windowHeight
        slideOffset: root.slideOffset
    }

    DashboardWorkspacesView {
        id: idDashboardWorkspacesView

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: DashboardService.activeTab === "workspaces"
        windowRoom: root.windowHeight
        slideOffset: root.slideOffset
    }

    SettingsView {
        id: idDashboardSettingsView

        Layout.fillWidth: true

        visible: DashboardService.activeTab === "settings"
    }
}
