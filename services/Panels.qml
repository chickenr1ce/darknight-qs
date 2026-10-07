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
    }

    function toggleAt(panel, screen, centerX: real) {
        root.closeOtherPanels(panel);
        panel.toggleAt(screen, centerX);
    }

    function openAt(panel, screen, centerX: real) {
        root.closeOtherPanels(panel);
        panel.openAt(screen, centerX);
    }
}
