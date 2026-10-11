.pragma library

function isoFor(year, month, day) {
    const m = String(month + 1).padStart(2, "0");
    const d = String(day).padStart(2, "0");
    return year + "-" + m + "-" + d;
}

function monthCells(year, month, todayIso, selectedIso, eventDays) {
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
        const iso = isoFor(cellYear, cellMonth, cellDay);
        cells.push({
            iso: iso,
            day: cellDay,
            inMonth: inMonth,
            isToday: iso === todayIso,
            isSelected: iso === selectedIso,
            hasEvents: (eventDays[iso] || []).length > 0
        });
    }
    return cells;
}

function shiftMonth(year, month, delta) {
    let nextMonth = month + delta;
    let nextYear = year;
    while (nextMonth < 0) {
        nextMonth += 12;
        nextYear -= 1;
    }
    while (nextMonth > 11) {
        nextMonth -= 12;
        nextYear += 1;
    }
    return { year: nextYear, month: nextMonth };
}

function isStale(nowMs, fetchedAtMs, failed, staleAfterMs) {
    if (failed)
        return true;
    if (!(fetchedAtMs > 0))
        return false;
    return (nowMs - fetchedAtMs) > staleAfterMs;
}

function zoneLabel(iana) {
    const parts = iana.split("/");
    return parts[parts.length - 1].replace("_", " ");
}

function zoneDiff(diff) {
    if (diff === undefined || diff === null || diff === "")
        return "";
    const minutes = Number(diff);
    const sign = minutes < 0 ? "-" : "+";
    const abs = Math.abs(minutes);
    const h = Math.floor(abs / 60);
    const mm = abs % 60;
    const body = mm === 0 ? h + "h" : h + ":" + String(mm).padStart(2, "0") + "h";
    return "(" + sign + body + ")";
}

function zoneTitle(label, diff) {
    return diff === "" ? label : label + " " + diff;
}

function withZone(list, iana, max) {
    const zones = list || [];
    const name = String(iana).trim();
    if (name === "" || zones.includes(name) || zones.length >= max)
        return zones;
    return zones.concat([name]);
}

function withoutZone(list, iana) {
    const zones = list || [];
    if (!zones.includes(iana))
        return zones;
    return zones.filter(zone => zone !== iana);
}
