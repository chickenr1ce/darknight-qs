pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "CalendarLogic.js" as CalendarLogic
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property PanelState panelState: idPanelState

    readonly property BarAnchor barAnchor: idBarAnchor

    readonly property int eventsPollMs: 15 * 60 * 1000
    readonly property int eventsStaleAfterMs: 30 * 60 * 1000
    readonly property string eventsUrlFile: idEventsState.stateFile("calendar-url")
    readonly property string eventsCachePath: idEventsState.path
    property var eventsCache: StateParsers.parseEventsCache("")
    readonly property var eventDays: root.eventsCache.days
    readonly property string eventsFetchedAt: root.eventsCache.fetchedAt || ""
    readonly property double eventsFetchedAtMs: Date.parse(root.eventsFetchedAt) || 0
    readonly property bool eventsStale: root.isStale(root.now.getTime(), root.eventsFetchedAtMs, root.eventsLastPollFailed)
    readonly property var selectedDayEvents: root.eventDays[root.selectedIso] || []

    property bool eventsLastPollFailed: false

    property var hiddenCalendars: []
    readonly property var eventCalendars: Array.isArray(root.eventsCache.calendars) ? root.eventsCache.calendars : []
    readonly property var hiddenCalendarArgs: {
        const args = [];
        for (let i = 0; i < root.hiddenCalendars.length; i++)
            args.push("--gcalcli-ignore-calendar", root.hiddenCalendars[i]);
        return args;
    }

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    property date now: new Date()

    property string todayIso: root.isoFor(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())

    property string selectedIso: root.todayIso

    property var worldZones: ["UTC", "America/New_York", "Europe/Berlin", "Asia/Tokyo"]
    readonly property var commonZones: ["UTC", "America/New_York", "America/Chicago", "America/Los_Angeles", "Europe/London", "Europe/Berlin", "Asia/Tokyo", "Australia/Sydney"]
    readonly property int maxZones: 6
    readonly property string zonesListPath: Quickshell.shellDir + "/assets/iana-zones.json"
    readonly property var ianaZones: StateParsers.parseZoneList(idZoneListState.text)

    readonly property var monthCells: CalendarLogic.monthCells(root.viewYear, root.viewMonth, root.todayIso, root.selectedIso, root.eventDays)

    property var zoneTimes: ({})

    onWorldZonesChanged: Qt.callLater(root.repollZoneTimes)

    PanelState {
        id: idPanelState
    }

    BarAnchor {
        id: idBarAnchor
    }

    IpcHandler {
        target: "calendar"

        function toggle(): string {
            return idBarAnchor.requestToggle() ? "ok" : "error: clock module is hidden";
        }

        function close(): string {
            idPanelState.closeFromOutside();
            return "ok";
        }
    }

    Timer {
        id: idZoneTimer

        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!idZoneRun.running)
                idZoneRun.request();
        }
    }

    Process {
        id: idZoneProcess

        command: ["python3", Quickshell.shellDir + "/scripts/calendar-clock.py"].concat(root.worldZones)
        stdout: idZoneCollector
        onExited: code => idZoneRun.finished(code === 0)
    }

    CoalescedRun {
        id: idZoneRun

        process: idZoneProcess

        starter: () => {
            idZoneProcess.running = true;
        }
    }

    StdioCollector {
        id: idZoneCollector

        onStreamFinished: root.zoneTimes = StateParsers.parseZoneTimes(idZoneCollector.text)
    }

    Timer {
        id: idEventsTimer

        interval: root.eventsPollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.repollEvents()
    }

    Timer {
        id: idRolloverTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            root.now = now;
            const iso = root.isoFor(now.getFullYear(), now.getMonth(), now.getDate());
            if (!(iso === root.todayIso))
                root.todayIso = iso;
        }
    }

    Process {
        id: idEventsProcess

        command: ["python3", Quickshell.shellDir + "/scripts/calendar-fetch.py", "--url-file", root.eventsUrlFile, "--cache-file", root.eventsCachePath].concat(root.hiddenCalendarArgs)
        stderr: idEventsErrorCollector
        onExited: code => {
            if (code === 0) {
                root.eventsLastPollFailed = false;
                idEventsState.reload();
            } else {
                root.eventsLastPollFailed = true;
                console.warn("calendar-fetch failed with exit " + code + ": " + idEventsErrorCollector.text.trim());
            }
            idEventsRun.finished(code === 0);
        }
    }

    CoalescedRun {
        id: idEventsRun

        process: idEventsProcess

        starter: () => {
            idEventsProcess.running = true;
        }
    }

    StdioCollector {
        id: idEventsErrorCollector
    }

    StateFile {
        id: idEventsState

        name: "calendar-events.json"
        inCache: true
        onParsed: text => root.eventsCache = StateParsers.parseEventsCache(text)
    }

    StateFile {
        id: idHiddenState

        name: "calendar-hidden"
        createDir: true
        onParsed: text => {
            const next = StateParsers.parseHiddenCalendars(text);
            if (!StateParsers.sameStringList(root.hiddenCalendars, next))
                root.hiddenCalendars = next;
        }
    }

    StateFile {
        id: idZonesState

        name: "calendar-zones"
        createDir: true
        onParsed: text => {
            const next = StateParsers.parseZones(text, root.maxZones);
            if (!StateParsers.sameStringList(root.worldZones, next))
                root.worldZones = next;
        }
    }

    StateFile {
        id: idZoneListState

        path: root.zonesListPath
    }

    function isStale(nowMs: double, fetchedAtMs: double, failed: bool): bool {
        return CalendarLogic.isStale(nowMs, fetchedAtMs, failed, root.eventsStaleAfterMs);
    }

    function staleLabel(): string {
        if (root.eventsFetchedAt.length === 0)
            return qsTr("Stale · never synced");
        const mins = Math.max(0, Math.floor((root.now.getTime() - root.eventsFetchedAtMs) / 60000));
        if (mins < 60)
            return qsTr("Stale · synced %1m ago").arg(mins);
        return qsTr("Stale · synced %1h ago").arg(Math.floor(mins / 60));
    }

    function dateLabel(iso: string): string {
        const parts = iso.split("-");
        if (parts.length !== 3)
            return iso;
        return Qt.formatDateTime(new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])), "dddd, d MMMM");
    }

    function showToday() {
        const now = new Date();
        root.viewYear = now.getFullYear();
        root.viewMonth = now.getMonth();
        root.selectedIso = root.isoFor(now.getFullYear(), now.getMonth(), now.getDate());
    }

    function shiftMonth(delta: int) {
        const next = CalendarLogic.shiftMonth(root.viewYear, root.viewMonth, delta);
        root.viewMonth = next.month;
        root.viewYear = next.year;
    }

    function isoFor(year: int, month: int, day: int): string {
        return CalendarLogic.isoFor(year, month, day);
    }

    function zoneLabel(iana: string): string {
        return CalendarLogic.zoneLabel(iana);
    }

    function zoneTime(iana: string): string {
        const e = root.zoneTimes[iana];
        return e && e.t ? e.t : "";
    }

    function zoneDiff(iana: string): string {
        const e = root.zoneTimes[iana];
        return CalendarLogic.zoneDiff(e ? e.d : null);
    }

    function zoneTitle(iana: string): string {
        return CalendarLogic.zoneTitle(root.zoneLabel(iana), root.zoneDiff(iana));
    }

    function saveZones() {
        idZonesState.save(root.worldZones.length > 0 ? root.worldZones.join("\n") + "\n" : "");
    }

    function saveHiddenCalendars() {
        idHiddenState.save(root.hiddenCalendars.length > 0 ? root.hiddenCalendars.join("\n") + "\n" : "");
    }

    function setCalendarHidden(name: string, hide: bool) {
        if (hide && !root.hiddenCalendars.includes(name))
            root.hiddenCalendars = root.hiddenCalendars.concat([name]);
        else if (!hide)
            root.hiddenCalendars = root.hiddenCalendars.filter(n => n !== name);
        else
            return;
        root.saveHiddenCalendars();
        Qt.callLater(root.repollEvents);
    }

    function repollEvents() {
        idEventsRun.request();
    }

    function repollZoneTimes() {
        idZoneRun.request();
    }

    function isValidZoneName(name: string): bool {
        return StateParsers.isValidZoneName(name);
    }

    function addZone(iana: string) {
        const name = iana.trim();
        if (!root.isValidZoneName(name))
            return;
        const next = CalendarLogic.withZone(root.worldZones, name, root.maxZones);
        if (next.length === root.worldZones.length)
            return;
        root.worldZones = next;
        root.saveZones();
    }

    function removeZone(iana: string) {
        const next = CalendarLogic.withoutZone(root.worldZones, iana);
        if (next.length === root.worldZones.length)
            return;
        root.worldZones = next;
        root.saveZones();
    }

    function selectDay(iso: string) {
        root.selectedIso = iso;
    }
}
