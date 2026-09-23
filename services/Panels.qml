pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property bool anyOpen: CalendarService.calendarVisible || NotificationServer.centerVisible || CavaService.cavaVisible || PowerService.powerVisible

    function toggleCalendarAt(screen, centerX: real) {
        NotificationServer.centerVisible = false;
        CavaService.cavaVisible = false;
        PowerService.powerVisible = false;
        PowerService.cancel();
        CalendarService.toggleCalendarAt(screen, centerX);
    }

    function toggleCenterAt(screen, centerX: real) {
        CalendarService.calendarVisible = false;
        CavaService.cavaVisible = false;
        PowerService.powerVisible = false;
        PowerService.cancel();
        NotificationServer.toggleCenterAt(screen, centerX);
    }

    function toggleCavaAt(screen, centerX: real) {
        CalendarService.calendarVisible = false;
        NotificationServer.centerVisible = false;
        PowerService.powerVisible = false;
        PowerService.cancel();
        CavaService.toggleCavaAt(screen, centerX);
    }

    function togglePowerAt(screen, centerX: real) {
        CalendarService.calendarVisible = false;
        NotificationServer.centerVisible = false;
        CavaService.cavaVisible = false;
        PowerService.cancel();
        PowerService.togglePowerAt(screen, centerX);
    }
}
