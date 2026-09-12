# Ticket 02 — Transient OSD Notification Popups Layer

**Status**: Done  
**Blocking**: Blocks Ticket 04  
**Blocked By**: Ticket 01  
**Spec Reference**: `docs/plans/04-phase-6b-notifications-spec.html` (ECO-HY3b §1, §3)

---

## 1. Objective

Build the transient on-screen display (OSD) popup window and toast component to display incoming desktop notifications in the top-right corner with auto-dismiss timers, urgency indicators, and action triggers.

---

## 2. Technical Scope & Interfaces

- **Files**:
  - `windows/NotificationPopups.qml` (`PanelWindow` anchored `Edges.Top | Edges.Right`)
  - `components/NotificationToast.qml` (Individual toast card)
- **Visual Design & Tokens** *(amended 2026-08-24: width tokenized; colors
  superseded by the typography/critical verdicts in Implementation Notes)*:
  - Width: `Globals.toastWidth` (320px), padding: `10px 12px`, corner radius: `Globals.radius (5px)` / `6px`.
  - Colors: `Colors.background` / `Colors.surface` background, `Colors.lavender` app label, `Colors.text` summary, `Colors.textSubtle` body.
  - Urgency handling: Critical urgency (`urgency === 2`) displays red left accent border + subtle pulsing glow.
  - Linear countdown timer indicator: `2px` height bar at bottom decaying over notification `expireTimeout` (default 5000ms).
- **Interactions** *(amended 2026-08-24, review verdict)*:
  - Hovering pauses decay timer.
  - Close button (`✕`) calls `notification.dismiss()`.
  - Click anywhere on the card also calls `notification.dismiss()` — required
    for criticals ("sticky until clicked"); approved as card-wide behaviour,
    with a pointing-hand cursor across the whole card.
  - Action pills invoke corresponding `action.invoke()`.
  - Snappy entrance transition: `Globals.toastMs` (180ms) ease-out translateX + opacity fade.

---

## 3. Acceptance Criteria

- [x] `notify-send "Meeting" "Starts in 5 minutes"` renders a toast at the top-right of the primary screen.
- [x] Toast automatically closes after 5 seconds with a visible smooth progress bar.
- [x] Hovering over the toast pauses the timer and prevents premature dismissal.
- [x] Critical notifications (`notify-send -u critical "Warning" "Overheat"`) display distinct red alert styling and remain sticky until clicked.
- [x] Multiple rapid notifications stack vertically without overlap or layout jitter.
- [x] Passes `qmllint` without errors.

---

## Implementation Notes

- `windows/NotificationPopups.qml` binds to `NotificationServer.activeToasts`
  (ticket 01 singleton); window is only visible while toasts are active and
  uses `ExclusionMode.Ignore` so it never shifts the bar's exclusive zone.
  No explicit `screen` binding — PanelWindow defaults to the primary screen.
- `components/NotificationToast.qml` drives its countdown with a linear
  NumberAnimation on `decayProgress`; hover pause uses Animation.paused so
  the exact remaining time resumes (no restart, no timeout extension).
- Quickshell 0.3.1 delivers `expireTimeout` in **milliseconds** (verified at
  runtime, contradicting the docs' "seconds"); handled with a 5s fallback
  for `-1`, and stickiness for critical or explicit `0`.
- Hover detection needs a topmost click-transparent probe MouseArea
  (`acceptedButtons: Qt.NoButton`): StyledText body text accepts hover and
  would otherwise shadow a probe placed underneath.
- Critical urgency styling (**prototype verdict**): quiet red-tinted card
  over border decoration; pulsing glow + left accent strip were rejected as
  tacky. Full variant set preserved on branch `prototype/toast-critical`
  (primary source). The derived pair now lives in `Colors.qml` as
  `criticalCard` / `criticalCardBorder` so tickets 03/04 can reuse it.
- Typography pass (2026-08-24, HTML preview verdict, then user scale bump):
  all-Geist card at Globals' named `ui*` scale (caption 12 Medium uppercase
  letter-spaced / title 15 DemiBold / body 14 / pills 13 Medium); body +
  pills moved to new `Colors.textSubtle` (#9d93ad, ~7:1) because
  `textSecondary` measured ~2.2:1 on the card. Iosevka stays bar-only;
  tickets 03/04 inherit `uiFontFamily` and the scale.
- Reflow fix (2026-08-24): toasts stack in a ListView with a `displaced`
  transition, not Column+Repeater — Column repositioning bypasses
  `Behavior on y` (verified: y moved in one step), and binding window
  height to `contentHeight` collapsed the viewport mid-animation,
  destroying delegates (visible as jank + stray decay-fill ghosts). Window
  is a fixed 720px canvas with an input `mask` tracking real content;
  toast bindings null-guard the model role (ListView assigns required
  properties after instantiation).
- Entrance: `Globals.toastMs` ease-out translateX + opacity fade per toast.
- Visible-stack cap (2026-08-24, review fix): `NotificationServer` expires
  the oldest toast beyond `maxVisibleToasts` (6) on arrival, so the fixed
  canvas never hides toasts past its clip. Expire (not dismiss) keeps the
  DBus close reason honest.
- Body text truncates at 4 lines with elision — intentional for a transient
  OSD layer; full text lives in the history for the notification center
  (ticket 03).
- Known minor: the input `mask` height tracks `contentHeight`, which follows
  *animated* positions, so the clickable area transiently mis-sizes during
  the displaced reflow (~180ms). Harmless at current toast cadence.
