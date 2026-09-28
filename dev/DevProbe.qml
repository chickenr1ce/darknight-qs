pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
                settings: SettingsService.visible,
                calendar: CalendarService.calendarVisible,
                cava: CavaService.cavaVisible,
                center: NotificationServer.centerVisible,
                power: PowerService.powerVisible,
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
                SettingsService.visible ? SettingsService.close() : SettingsService.open(screen);
            else if (name === "calendar")
                CalendarService.calendarVisible ? CalendarService.closeCalendarFromOutside() : Panels.openCalendarAt(screen, centerX);
            else if (name === "cava")
                CavaService.cavaVisible ? CavaService.closeCavaFromOutside() : Panels.openCavaAt(screen, centerX);
            else if (name === "center")
                NotificationServer.centerVisible ? NotificationServer.closeCenterFromOutside() : Panels.openCenterAt(screen, centerX);
            else if (name === "power")
                PowerService.powerVisible ? PowerService.closePowerFromOutside() : Panels.openPowerAt(screen, centerX);
        }

        function closeAll(): void {
            DashboardService.close();
            SettingsService.close();
            CalendarService.closeCalendarFromOutside();
            CavaService.closeCavaFromOutside();
            NotificationServer.closeCenterFromOutside();
            PowerService.closePowerFromOutside();
        }

        function toggleDnd(): void {
            NotificationServer.toggleDnd();
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
    }
}
