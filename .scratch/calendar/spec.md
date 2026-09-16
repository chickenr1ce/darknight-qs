# Spec: calendar panel with events, editable world clock, under trigger placement

## Problem Statement

Clicking the clock opens the calendar on the wrong side of the screen, far from the trigger. The month view shows no events, so planning means opening a browser. The world clock cities are fixed, with no way to change them. Each of these forces daily planning out of the shell.

## Solution

Every floating panel opens directly below its trigger on the clicked monitor. The calendar centers on the clock, shows event dots from Google Calendar plus an agenda for the selected day, and lets zones be added and removed inline. Offline shows the last good data with a stale marker instead of blank.

## User Stories

1. As a daily user, I want the calendar to open below the clock I clicked, so that my eyes stay where my cursor is.
2. As a dual monitor user, I want the calendar to open on the monitor whose clock I clicked, so that the panel never appears on the wrong screen.
3. As a daily user, I want only one panel open at a time, so that panels never stack or fight for focus.
4. As a daily user, I want outside click and Escape to close the panel and return focus to the trigger, so that dismissal is always one gesture.
5. As a planner, I want event dots on every day that has events, in any month I browse to, so that busy days are visible at a glance.
6. As a planner, I want an agenda list for the selected day with start times and titles, so that I can read the day without opening a browser.
7. As a planner, I want an explicit empty state on days with no events, so that blank never reads as broken.
8. As a planner, I want to browse a year ahead from cached data without network calls on month shift, so that future planning feels instant.
9. As a planner, I want a stale marker with sync age when the feed cannot refresh, so that I know how much to trust what I see.
10. As a Google Calendar user, I want setup to be one secret URL with no Cloud project, so that sync works in minutes.
11. As a privacy minded user, I want the secret URL treated like a password and never committed, so that my calendar stays mine.
12. As a world clock user, I want to add a zone from a common list or a manual IANA name, so that the cities match where my people are.
13. As a world clock user, I want to remove a zone inline, so that the list stays short.
14. As a world clock user, I want at most 6 zones with my edits surviving restart, so that the panel stays readable and stable.
15. As a notification center user, I want it to move under the bell under the same rule, so that every panel behaves one way.
16. As a future panel author, I want anchor plumbing shared in the panel shell, so that weather and other panels get placement free.

## Implementation Decisions

- Shared anchor plumbing lives in the panel shell. It accepts a target screen plus a trigger center x, keeps the 8px top gap under the slab, and clamps the 380 wide panel inside 18px screen edge margins. Each trigger reports its center on click through the existing click handler, and the clock learns its monitor name the way workspaces already do. The anchor is set before the panel shows, never moved mid fade.
- Placement math, taken from the approved click through prototype at `/tmp/opencode/panel-under-trigger.html`: final left equals trigger center minus half the panel width, clamped into the screen edges. The prototype readout proved the bell case shifts left while the clock case barely shifts.
- The calendar service is the single state seam. It gains the anchor target, an event map keyed by ISO date, and a read/write zone list with file persistence. The month grid, agenda, and zone editor all read from it, and selection state stays as today.
- Events arrive through a small fetch helper outside QML. It polls the primary secret iCal URL every 15 minutes, converts the feed to local JSON, and QML reads only the file. Recurrences expand per rendered 42 day window only, so any year renders from cache with no network on month shift.
- Backend order is secret iCal first, `gcalcli` later as the upgrade path for multi calendar search or true freshness. Both share the last good plus stale offline pattern.
- Zone storage is a plain string list file holding at most 6 IANA names, defaulting to the current 4. The picker is a short common list plus manual entry. Full timezone search is deferred.
- Agenda rows show start time plus title, read only, with no click through in v1.
- Secrets handling: the feed URL is a bearer token, stored with owner only permissions, never committed, rotated through Google's reset control. If a Workspace admin disables the secret address, setup falls back to the `gcalcli` path.

## Testing Decisions

- A good test here checks external behavior, not QML internals: given a fixture feed, the helper emits the expected JSON; given a trigger position, the panel lands clamped on screen.
- The fetch helper gets a script level test with a checked in fixture feed covering single events, recurrences, and multi day events.
- QML has no test harness in this repo, so panel behavior goes through the existing gates plus a live checklist: open and close on each monitor, clamp readout at both screen edges, dots plus agenda on an event day, empty state on a free day, year ahead browse with network off, stale marker after a failed poll, midnight rollover while open, and zone add, remove, and restart persistence.
- Prior art for gates: the type and style lints plus the toast smoke script run on every change, and live instance checks are the standing verification method.

## Out of Scope

- Two way sync, event creation or editing, and event reminders.
- The `gcalcli` upgrade, extra calendars, and event search.
- Full timezone search and more than 6 zones.
- A separate settings window. Inline editing is the decision.
- Weather panel and visualizer editors. They inherit the anchor plumbing later.
- Per screen duplicate panel instances. One instance moves to the clicked screen.

## Further Notes

- Feed freshness over the secret address is subscriber paced, with minutes to hours of lag possible. Fine for a day agenda, not for to the minute reminders.
- The backend choice and the precise over side aligned placement call both deserve architecture records when the tickets land, since both came from real trade offs against genuine alternatives.
