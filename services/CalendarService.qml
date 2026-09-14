pragma Singleton

import QtQuick
import Quickshell

// Calendar state for the clock panel; date-only plus world zones, no event backend yet.
// No "pragma ComponentBehavior: Bound": combined with pragma Singleton it crashes qmllint (silent exit 255).
Singleton {
    id: root

    property bool calendarVisible: false

    // Press clears the grab before release toggles the clock, so a clock close would reopen without this window.
    property double calendarLastOutsideCloseAt: 0

    function toggleCalendar() {
        if (!root.calendarVisible && Date.now() - root.calendarLastOutsideCloseAt < 300)
            return;
        root.calendarVisible = !root.calendarVisible;
    }

    function closeCalendarFromOutside() {
        if (root.calendarVisible) {
            root.calendarLastOutsideCloseAt = Date.now();
            root.calendarVisible = false;
        }
    }

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    // ISO yyyy-mm-dd for today; refreshed by the panel timer so midnight rolls over while open.
    property string todayIso: root.isoFor(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())

    property string selectedIso: root.todayIso

    function showToday() {
        const now = new Date();
        root.viewYear = now.getFullYear();
        root.viewMonth = now.getMonth();
        root.selectedIso = root.isoFor(now.getFullYear(), now.getMonth(), now.getDate());
    }

    function shiftMonth(delta: int) {
        let month = root.viewMonth + delta;
        let year = root.viewYear;
        while (month < 0) {
            month += 12;
            year -= 1;
        }
        while (month > 11) {
            month -= 12;
            year += 1;
        }
        root.viewMonth = month;
        root.viewYear = year;
    }

    function isoFor(year: int, month: int, day: int): string {
        const m = String(month + 1).padStart(2, "0");
        const d = String(day).padStart(2, "0");
        return year + "-" + m + "-" + d;
    }

    // World zones shown under the grid; IANA names for Intl timeZone formatting.
    readonly property var worldZones: ["UTC", "America/New_York", "Europe/Berlin", "Asia/Tokyo"]

    function zoneLabel(iana: string): string {
        const parts = iana.split("/");
        return parts[parts.length - 1].replace("_", " ");
    }

    // 42 Monday-first cells covering the visible month plus leading and trailing days.
    // Re-evaluates on view change and on today rollover via todayIso.
    readonly property var monthCells: {
        root.todayIso;
        const year = root.viewYear;
        const month = root.viewMonth;
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrev = new Date(year, month, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const dayIndex = i - lead + 1;
            let cellYear = year;
            let cellMonth = month;
            let cellDay = dayIndex;
            let inMonth = true;
            if (dayIndex < 1) {
                cellDay = daysInPrev + dayIndex;
                cellMonth = month - 1;
                inMonth = false;
                if (cellMonth < 0) {
                    cellMonth = 11;
                    cellYear -= 1;
                }
            } else if (dayIndex > daysInMonth) {
                cellDay = dayIndex - daysInMonth;
                cellMonth = month + 1;
                inMonth = false;
                if (cellMonth > 11) {
                    cellMonth = 0;
                    cellYear += 1;
                }
            }
            const iso = root.isoFor(cellYear, cellMonth, cellDay);
            cells.push({
                iso: iso,
                day: cellDay,
                inMonth: inMonth,
                isToday: iso === root.todayIso,
                isSelected: iso === root.selectedIso
            });
        }
        return cells;
    }

    // No ": void" return type: qmllint crashes (exit 255) on void returns in pragma Singleton files.
    function selectDay(iso: string) {
        root.selectedIso = iso;
    }
}
