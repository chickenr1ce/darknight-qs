pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property alias calendarVisible: idPanelState.visible

    property alias calendarLastOutsideCloseAt: idPanelState.lastOutsideCloseAt

    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    readonly property int eventsPollMs: 15 * 60 * 1000
    readonly property int eventsStaleAfterMs: 30 * 60 * 1000
    readonly property string eventsUrlFile: root.stateFile("calendar-url")
    readonly property string eventsCachePath: root.cacheFile("calendar-events.json")
    readonly property string stateDirPath: root.stateBase() + "/quickshell"
    property var eventsCache: root.parseEventsCache("")
    property string lastEventsCacheText: ""
    readonly property var eventDays: root.eventsCache.days
    readonly property string eventsFetchedAt: root.eventsCache.fetchedAt || ""
    readonly property double eventsFetchedAtMs: Date.parse(root.eventsFetchedAt) || 0
    readonly property bool eventsStale: root.isStale(root.now.getTime(), root.eventsFetchedAtMs, root.eventsLastPollFailed)
    readonly property var selectedDayEvents: root.eventDays[root.selectedIso] || []

    property bool eventsLastPollFailed: false
    property bool eventsPollQueued: false

    property var hiddenCalendars: []
    readonly property string hiddenCalendarsPath: root.stateFile("calendar-hidden")
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
    readonly property string zonesPath: root.stateFile("calendar-zones")
    readonly property string zonesListPath: Quickshell.shellDir + "/assets/iana-zones.json"
    readonly property var ianaZones: root.parseZoneList(idZoneListFile.text())

    readonly property var monthCells: {
        root.todayIso;
        root.eventDays;
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
                isSelected: iso === root.selectedIso,
                hasEvents: (root.eventDays[iso] || []).length > 0
            });
        }
        return cells;
    }

    property var zoneTimes: ({})

    property bool zonePollQueued: false

    onWorldZonesChanged: Qt.callLater(root.repollZoneTimes)

    PanelState {
        id: idPanelState
    }

    Timer {
        id: idZoneTimer

        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!idZoneProcess.running)
                idZoneProcess.running = true;
        }
    }

    Process {
        id: idZoneProcess

        command: ["python3", Quickshell.shellDir + "/scripts/calendar-clock.py"].concat(root.worldZones)
        stdout: idZoneCollector
    }

    StdioCollector {
        id: idZoneCollector

        onStreamFinished: {
            root.zoneTimes = root.parseZoneTimes(idZoneCollector.text);
            if (root.zonePollQueued) {
                root.zonePollQueued = false;
                idZoneProcess.running = true;
            }
        }
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
                idEventsCache.reload();
            } else {
                root.eventsLastPollFailed = true;
                console.warn("calendar-fetch failed with exit " + code + ": " + idEventsErrorCollector.text.trim());
            }
            if (root.eventsPollQueued) {
                root.eventsPollQueued = false;
                idEventsProcess.running = true;
            }
        }
    }

    StdioCollector {
        id: idEventsErrorCollector
    }

    FileView {
        id: idEventsCache

        path: "file://" + root.eventsCachePath
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.refreshEventsCache()
    }

    FileView {
        id: idHiddenFile

        path: "file://" + root.hiddenCalendarsPath
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            const next = root.parseHiddenCalendars(idHiddenFile.text());
            if (!root.sameStringList(root.hiddenCalendars, next))
                root.hiddenCalendars = next;
        }
    }

    Process {
        id: idZonesDirProcess

        command: ["mkdir", "-p", root.stateDirPath]
        running: true
        onExited: {
            idZonesFile.reload();
            idHiddenFile.reload();
        }
    }

    FileView {
        id: idZonesFile

        path: "file://" + root.zonesPath
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            const next = root.parseZones(idZonesFile.text());
            if (!root.sameStringList(root.worldZones, next))
                root.worldZones = next;
        }
    }

    FileView {
        id: idZoneListFile

        path: "file://" + root.zonesListPath
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
    }

    function toggleCalendar() {
        idPanelState.toggle()
    }

    function toggleCalendarAt(screen, centerX: real) {
        idPanelState.toggleAt(screen, centerX)
    }

    function closeCalendarFromOutside() {
        idPanelState.closeFromOutside()
    }

    function stateBase(): string {
        return Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state");
    }

    function cacheBase(): string {
        return Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache");
    }

    function stateFile(name: string): string {
        return root.stateDirPath + "/" + name;
    }

    function cacheFile(name: string): string {
        return root.cacheBase() + "/quickshell/" + name;
    }

    function parseEventsCache(jsonText: string): var {
        try {
            const parsed = JSON.parse(jsonText);
            if (parsed && parsed.days)
                return parsed;
        } catch (e) {
        }
        return {
            "fetchedAt": "",
            "days": {},
            "calendars": []
        };
    }

    function refreshEventsCache() {
        const text = idEventsCache.text();
        if (text === root.lastEventsCacheText)
            return;
        root.lastEventsCacheText = text;
        root.eventsCache = root.parseEventsCache(text);
    }

    function isStale(nowMs: double, fetchedAtMs: double, failed: bool): bool {
        if (failed)
            return true;
        if (!(fetchedAtMs > 0))
            return false;
        return (nowMs - fetchedAtMs) > root.eventsStaleAfterMs;
    }

    function staleLabel(): string {
        if (root.eventsFetchedAt.length === 0)
            return qsTr("Stale · never synced");
        const mins = Math.max(0, Math.floor((root.now.getTime() - root.eventsFetchedAtMs) / 60000));
        if (mins < 60)
            return qsTr("Stale · synced %1m ago").arg(mins);
        return qsTr("Stale · synced %1h ago").arg(Math.floor(mins / 60));
    }

    function sameStringList(a, b): bool {
        if (!(a.length === b.length))
            return false;
        for (let i = 0; i < a.length; i++) {
            if (!(a[i] === b[i]))
                return false;
        }
        return true;
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

    function zoneLabel(iana: string): string {
        const parts = iana.split("/");
        return parts[parts.length - 1].replace("_", " ");
    }

    function parseZoneTimes(output) {
        const times = {};
        const lines = output.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const eq = lines[i].indexOf("=");
            if (eq <= 0)
                continue;
            const rest = lines[i].slice(eq + 1);
            const sp = rest.indexOf(" ");
            times[lines[i].slice(0, eq)] = {
                t: sp < 0 ? rest : rest.slice(0, sp),
                d: sp < 0 ? null : rest.slice(sp + 1)
            };
        }
        return times;
    }

    function zoneTime(iana: string): string {
        const e = root.zoneTimes[iana];
        return e && e.t ? e.t : "";
    }

    function zoneDiff(iana: string): string {
        const e = root.zoneTimes[iana];
        if (!e || e.d === undefined || e.d === null || e.d === "")
            return "";
        const m = Number(e.d);
        const sign = m < 0 ? "-" : "+";
        const abs = Math.abs(m);
        const h = Math.floor(abs / 60);
        const mm = abs % 60;
        const body = mm === 0 ? h + "h" : h + ":" + String(mm).padStart(2, "0") + "h";
        return "(" + sign + body + ")";
    }

    function zoneTitle(iana: string): string {
        const diff = root.zoneDiff(iana);
        return diff === "" ? root.zoneLabel(iana) : root.zoneLabel(iana) + " " + diff;
    }

    function isValidZoneName(name: string): bool {
        return /^[A-Za-z0-9_\-+\/]+$/.test(name);
    }

    function parseZones(text: string): var {
        const zones = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length && zones.length < root.maxZones; i++) {
            const name = lines[i].trim();
            if (name !== "" && root.isValidZoneName(name) && !zones.includes(name))
                zones.push(name);
        }
        return zones;
    }

    function parseZoneList(text) {
        try {
            const parsed = JSON.parse(text);
            if (Array.isArray(parsed))
                return parsed;
        } catch (e) {
        }
        return [];
    }
    function saveZones() {
        idZonesFile.setText(root.worldZones.length > 0 ? root.worldZones.join("\n") + "\n" : "");
    }

    function parseHiddenCalendars(text: string): var {
        const hidden = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const name = lines[i].trim();
            if (name !== "" && !hidden.includes(name))
                hidden.push(name);
        }
        return hidden;
    }

    function saveHiddenCalendars() {
        idHiddenFile.setText(root.hiddenCalendars.length > 0 ? root.hiddenCalendars.join("\n") + "\n" : "");
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
        if (idEventsProcess.running)
            root.eventsPollQueued = true;
        else
            idEventsProcess.running = true;
    }

    function repollZoneTimes() {
        if (idZoneProcess.running)
            root.zonePollQueued = true;
        else
            idZoneProcess.running = true;
    }

    function addZone(iana: string) {
        const name = iana.trim();
        if (name === "" || root.worldZones.includes(name) || root.worldZones.length >= root.maxZones)
            return;
        if (!root.isValidZoneName(name))
            return;
        root.worldZones = root.worldZones.concat([name]);
        root.saveZones();
    }

    function removeZone(iana: string) {
        if (!root.worldZones.includes(iana))
            return;
        root.worldZones = root.worldZones.filter(z => z !== iana);
        root.saveZones();
    }

    function selectDay(iso: string) {
        root.selectedIso = iso;
    }
}
