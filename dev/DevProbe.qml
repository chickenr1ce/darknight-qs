pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.dev
import qs.services

Item {
    id: root

    visible: false

    readonly property bool enabled: Quickshell.env("QUICKSHELL_DEV_PROBE") === "1" || idFlag.text() !== ""
    readonly property ShellScreen probeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    FileView {
        id: idFlag

        path: "file://" + Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-dev-probe"
        printErrors: false
    }

    IpcHandler {
        target: "devprobe"

        enabled: root.enabled

        function state(): string {
            return JSON.stringify({
                screens: Quickshell.screens.map(screen => screen.name),
                dashboard: DashboardService.dashboardVisible,
                settings: DashboardService.dashboardVisible && DashboardService.activeTab === "settings",
                calendar: CalendarService.panelState.visible,
                cava: CavaService.panelState.visible,
                center: NotificationServer.panelState.visible,
                power: PowerService.panelState.visible,
                dnd: NotificationServer.dndEnabled,
                reducedMotion: Globals.reducedMotion,
                zones: CalendarService.worldZones,
                hiddenCalendars: CalendarService.hiddenCalendars
            });
        }

        function toggle(name: string): void {
            const screen = root.probeScreen;
            if (screen === null)
                return;
            const centerX = screen.width / 2;
            if (name === "dashboard")
                DashboardService.dashboardVisible ? DashboardService.close() : DashboardService.openDashboardAt(screen, centerX);
            else if (name === "settings")
                DashboardService.dashboardVisible && DashboardService.activeTab === "settings" ? DashboardService.close() : DashboardService.openSettingsAt(screen, centerX, "");
            else if (name === "calendar")
                CalendarService.panelState.visible ? CalendarService.panelState.closeFromOutside() : Panels.openAt(CalendarService.panelState, screen, centerX);
            else if (name === "cava")
                CavaService.panelState.visible ? CavaService.panelState.closeFromOutside() : Panels.openAt(CavaService.panelState, screen, centerX);
            else if (name === "center")
                NotificationServer.panelState.visible ? NotificationServer.panelState.closeFromOutside() : Panels.openAt(NotificationServer.panelState, screen, centerX);
            else if (name === "power")
                PowerService.panelState.visible ? PowerService.panelState.closeFromOutside() : Panels.openAt(PowerService.panelState, screen, centerX);
        }

        function closeAll(): void {
            DashboardService.close();
            CalendarService.panelState.closeFromOutside();
            CavaService.panelState.closeFromOutside();
            NotificationServer.panelState.closeFromOutside();
            PowerService.panelState.closeFromOutside();
        }

        function toggleDnd(): void {
            NotificationServer.toggleDnd();
        }

        function tab(name: string): void {
            DashboardService.selectTab(name);
        }

        function setReducedMotion(on: bool): void {
            Globals.reducedMotion = on;
        }

        function addZone(zone: string): void {
            CalendarService.addZone(zone);
        }

        function removeZone(zone: string): void {
            CalendarService.removeZone(zone);
        }

        function setFeedHidden(feed: string, hidden: bool): void {
            CalendarService.setCalendarHidden(feed, hidden);
        }

        function geomNames(): string {
            return JSON.stringify(Object.keys(DevGeometry.targets));
        }

        function geom(name: string): string {
            return DevGeometry.snapshot(name);
        }

        function appsBench(): string {
            const screen = root.probeScreen;
            if (screen !== null && !(DashboardService.dashboardVisible && DashboardService.activeTab === "apps"))
                DashboardService.openAppsAt(screen, screen.width / 2);
            const view = DevGeometry.targets["dashboard.apps"];
            if (view === undefined || view === null)
                return JSON.stringify({ found: false });
            return JSON.stringify(view.bench());
        }

        function toplevels(): string {
            return JSON.stringify((Hyprland.toplevels?.values ?? []).map(toplevel => ({
                address: toplevel.address,
                title: toplevel.title,
                appId: toplevel.wayland ? toplevel.wayland.appId : "",
                ipc: toplevel.lastIpcObject
            })));
        }

        function focusMatch(token: string): string {
            return HyprlandFocus.addressFor(HyprlandFocus.keysFor([token]));
        }
    }
}
