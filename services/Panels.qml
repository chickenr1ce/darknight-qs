pragma Singleton

import QtQuick
import Quickshell

// One-panel rule: opening a panel closes the others. Services own their
// state (composed PanelState each); this registry owns the exclusivity, so
// triggers call here instead of writing each other's services.
Singleton {
    id: root

    readonly property bool anyOpen: CalendarService.calendarVisible || NotificationServer.centerVisible || CavaService.cavaVisible

    function toggleCalendarAt(screen, centerX: real) {
        NotificationServer.centerVisible = false;
        CavaService.cavaVisible = false;
        CalendarService.toggleCalendarAt(screen, centerX);
    }

    function toggleCenterAt(screen, centerX: real) {
        CalendarService.calendarVisible = false;
        CavaService.cavaVisible = false;
        NotificationServer.toggleCenterAt(screen, centerX);
    }

    function toggleCavaAt(screen, centerX: real) {
        CalendarService.calendarVisible = false;
        NotificationServer.centerVisible = false;
        CavaService.toggleCavaAt(screen, centerX);
    }
}
