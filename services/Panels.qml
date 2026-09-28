pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property var panels: [CalendarService.panelState, NotificationServer.panelState, CavaService.panelState, PowerService.panelState]

    readonly property bool anyOpen: {
        for (let i = 0; i < root.panels.length; i++) {
            if (root.panels[i].visible)
                return true;
        }
        return false;
    }

    function closeOtherPanels(target) {
        for (let i = 0; i < root.panels.length; i++) {
            if (!(root.panels[i] === target))
                root.panels[i].visible = false;
        }
        PowerService.cancel();
    }

    function toggleCalendarAt(screen, centerX: real) {
        root.closeOtherPanels(CalendarService.panelState);
        CalendarService.toggleCalendarAt(screen, centerX);
    }

    function toggleCenterAt(screen, centerX: real) {
        root.closeOtherPanels(NotificationServer.panelState);
        NotificationServer.toggleCenterAt(screen, centerX);
    }

    function toggleCavaAt(screen, centerX: real) {
        root.closeOtherPanels(CavaService.panelState);
        CavaService.toggleCavaAt(screen, centerX);
    }

    function togglePowerAt(screen, centerX: real) {
        root.closeOtherPanels(PowerService.panelState);
        PowerService.togglePowerAt(screen, centerX);
    }

    function openCalendarAt(screen, centerX: real) {
        root.closeOtherPanels(CalendarService.panelState);
        CalendarService.openCalendarAt(screen, centerX);
    }

    function openCenterAt(screen, centerX: real) {
        root.closeOtherPanels(NotificationServer.panelState);
        NotificationServer.openCenterAt(screen, centerX);
    }

    function openCavaAt(screen, centerX: real) {
        root.closeOtherPanels(CavaService.panelState);
        CavaService.openCavaAt(screen, centerX);
    }

    function openPowerAt(screen, centerX: real) {
        root.closeOtherPanels(PowerService.panelState);
        PowerService.openPowerAt(screen, centerX);
    }
}
