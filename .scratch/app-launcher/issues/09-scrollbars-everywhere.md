# 09: Scrollbar and smooth wheel on every scrolling surface

**Status:** done

**Blocked by:** 08

**Blocking:** none

Discovered during the first live run (user feedback, 2026-10-09): anything
that scrolls should show a scrollbar. Ticket 08 builds the shared
`components/ScrollBar.qml` and smooth-wheel helper for the Apps list and the
context menu; this ticket rolls them out to the rest of the shell so scrolling
looks and feels the same everywhere.

**What to build:** Every user-scrollable view gets the shared scrollbar and
the smooth-wheel helper. Today that is the Settings body
(`windows/SettingsView.qml`), the calendar panel body
(`windows/CalendarCenter.qml`), and the notification center list
(`windows/NotificationCenter.qml`). The toast stack
(`windows/NotificationPopups.qml`, `interactive: false`) does not scroll and is
out of scope.

## Acceptance criteria

- [x] `windows/SettingsView.qml`, `windows/CalendarCenter.qml`, and
  `windows/NotificationCenter.qml` each attach the shared `ScrollBar` and
  smooth-wheel helper to their `Flickable`; no copied scrollbar or wheel code.
- [x] The bar shows only when content overflows, and each view reserves its
  width so content never reflows when it appears (section 5 "No layout reflow
  on state change"); rows and cards do not sit under the bar.
- [x] Existing scroll behavior still works: the notification center's
  expand-a-group glide into view, the calendar's capped body height
  (`bodyScrollMax`), Settings section switching resetting or keeping scroll
  as it does today, drag-flick, `Flickable.StopAtBounds`.
- [x] Reduced motion: the wheel jumps without animating in all three views.
- [x] A structural gate (extend `scripts/test-panel-logic.sh` or the scroll
  test from ticket 08) asserts every user-scrollable `Flickable`/`ListView`
  under `windows/` and `components/` (excluding ones with
  `interactive: false`) composes the shared `ScrollBar`, so a new scrolling
  surface without one fails the gate.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [ ] Live: Settings, calendar, and the notification center (with enough
  notifications to overflow) each show the bar, drag and page with it, and
  glide on one wheel notch.

## Amendments

- 2026-10-09: Rolled the shared `ScrollBar` and `SmoothWheel` into the three
  views. Each `Flickable` moved inside a plain `Item` slot because
  `PanelShell` and `SettingsView` route declared children into a
  `ColumnLayout`, where `anchors.fill` on the wheel overlay is undefined; the
  slot carries the `Layout` constraints and the wheel fills the `Flickable`
  inside it. Content reserves `Globals.scrollbarWidth` (the body column is
  `Flickable.width - Globals.scrollbarWidth`), so the bar never reflows rows.
  The notification center calls `idGroupsSmoothWheel.stop()` before its
  expand-a-group glide and stops that glide on `SmoothWheel.wheelStarted`, so
  the programmatic glide and the wheel never fight. The structural gate lives
  in `scripts/test-panel-logic.sh` (section 25) and scans `windows/` and
  `components/` for `Flickable`/`ListView`/`GridView`/`ScrollView`, skipping
  `interactive: false` (the toast stack). The live criterion stays unchecked:
  it needs a real pointer and an overflowing notification list, which
  `scripts/boot-check.sh` cannot exercise.

- 2026-10-09: Review fixes. `scripts/test-panel-logic.sh` section 25 is now
  per-scrollable: `scripts/scroll-chrome-check.py` parses each
  `Flickable`/`ListView`/`GridView`/`ScrollView` block, skips only a view that
  sets `interactive: false` in its own block, and requires that view's own id,
  an attached shared `ScrollBar`, and a same-file `SmoothWheel` whose
  `flickable:` names it. The old per-file gate let one attached bar excuse a
  second bare view and one inert view excuse the whole file; section 25
  self-tests both with a temporary fixture. The shared `SmoothWheel` change
  (MouseArea instead of `WheelHandler`, and the two slot fixes) is recorded in
  ticket 08.
