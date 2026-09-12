# Ticket 03 — Notification Center Panel & Collapsible App Accordions

**Status**: Done  
**Blocking**: Blocks Ticket 04  
**Blocked By**: Ticket 01  
**Spec Reference**: `docs/plans/04-phase-6b-notifications-spec.html` (Frozen decisions 1A + 2A + 3A + 4A)

---

## 1. Objective

Build the floating notification center flyout panel featuring per-app collapsible accordions (`2A`), click-to-reveal inline quick replies (`3A`), unread count badges, DND switch, and bulk/per-app clearing (`4A`).

---

## 2. Technical Scope & Interfaces

- **Files**:
  - `windows/NotificationCenter.qml` (`PopupWindow` or `PanelWindow` anchored below the bar's notification button)
  - `components/NotificationCard.qml` (History notification item inside the center)
  - `components/NotificationGroup.qml` (Accordion wrapper for grouping items by `appName`)
- **Layout & Framing (1A)**:
  - Width: `380px`, Max Height: `540px`, Corner Radius: `Globals.slabRadius (9px)`.
  - Floating inset: 8px below bar, right-aligned to notification module.
  - Background: `Colors.background` with `Colors.surface` 1px border.
- **Accordion Grouping (2A)**:
  - Header: App icon glyph, app title with count badge (e.g., `Slack (3)`), expand/collapse chevron, and "Clear App" button.
  - Height animation: Smooth 140ms ease height transition.
- **Inline Quick Reply (3A)**:
  - Clicking `↩ Reply` pill reveals an inline `TextInput` field with auto-focus.
  - `Enter` submits via `notification.sendInlineReply(text)` and dismisses card.
  - `Escape` collapses the reply field.
- **Header Controls (4A)**:
  - Title: "Notifications", unread count badge pill.
  - DND toggle button (` DND`).
  - "Clear All" button (`dismissAll()`).

---

## 3. Acceptance Criteria

- [x] Notification Center opens/closes smoothly with 140ms/120ms transitions matching the Unified Slab system.
- [x] Notifications are clustered under collapsible app accordions with accurate counts.
- [x] Clicking "Clear" on an app header dismisses all notifications for that specific app.
- [x] Clicking "Clear All" in the header empties the entire history.
- [x] Messaging notifications with inline reply capabilities allow typing and sending replies with Enter key.
- [x] Empty state renders a clean "No notifications" placeholder when queue is clear.
- [x] Passes `qmllint` without errors.

- **2026-08-24 (user-reported fix)**: Toasts and the center share the
  top-right corner and the toast layer rendered on top, hiding the center;
  dismissing those toasts also removed them from history. Fix: while the
  center is open it *is* the notification surface — new arrivals skip
  toast announcement (history only, no hidden backlog), and the toast layer
  hides while the center is open (unexpired toasts reappear on close).
  Verified live: center open + three arrivals → no toasts, history badge 3.

## Amendments

- **2026-09-12 (manual-test feedback)**: Toast action pills and the close
  button never highlighted on hover — the topmost decay-pause probe captures
  every hover event above them (clicks pass through, hover does not). Fix:
  pills/close bind their highlight to probe-relative geometry
  (`probeOver()` mapping the probe cursor into their own bounds) instead of
  their own `containsMouse`. Same pass adds the missing pressed state to
  `PillButton` (Phase 6a squash at `pressScalePill` via `PressScale`), so all
  seven buttons — including the center's DND toggle — now give finger-down
  feedback instead of only a color change.
- **2026-09-12 (option B, user pick)**: Hover forced the ON-fill in both
  states, masking DND on/off until the cursor moved away. `PillButton` hover
  no longer touches the fill — fill is strictly state-driven, hover only
  draws a contrasting ring + brightens the label (no lighten filter exists in
  QML without new tokens). Explored via `/tmp/opencode/dnd-toggle-options.html`
  (options A–E; B picked, B+C noted as composable later).
- **2026-09-12 (manual verification complete)**: User ran the full 24-item
  suite live (toasts → open/close → suppression → grouping/clear/badge/DND →
  inline reply → edge cases). All pass, including the click/keyboard flows
  the 2026-08-24 note left as code-path-only (accordion toggling, reply
  typing + Enter/Escape, per-app Clear, Clear All, DND toggle, open/close
  transitions). Round 2 found four real bugs, all fixed same-day on this
  branch: dead per-app Clear (C++ type shadowing), transient null TypeErrors,
  DND sliding on empty history, unfocusable reply field. Ticket 03 is done;
  ticket 04 is unblocked.
- **2026-09-12 (manual-test round 2)**:
  - Per-app Clear silently dead: bare `NotificationServer` in
    `NotificationGroup.qml` resolved to quickshell's C++ type (imported for
    the delegate's role type), shadowing our singleton — `dismissGroup is not
    a function` in the log. Fix: alias that import (`as Notif`), with a
    comment so nobody un-aliases it. Only that file imported both.
  - Same log showed transient `modelData.text` / `toast.expire()` null
    TypeErrors during action rebuild and toast teardown — null-guarded all
    three sites.
  - DND slid sideways when Clear All hid on empty history: Clear All is now
    always laid out, `disabled` (dim + inert) when there is nothing to clear.
    New `disabled` prop on `PillButton`.
  - Reply field untypeable: keys went to the focused app because
    `PanelWindow.focusable` defaults to false (no compositor keyboard focus).
    Set `focusable: true` on the center (OnDemand — takes focus on click,
    never steals it unprompted).

- **2026-08-24 (scope)**: The ticket's file list cannot satisfy "opens/closes" on its
  own — something must host the window and trigger it. Added, kept minimal so
  ticket 04's migration scope is untouched: `toggleCenter()`/`centerVisible` on the
  notification server singleton, `NotificationCenter {}` instantiated in `shell.qml`,
  and a one-line `onClicked` swap in `modules/Notifications.qml` (the swaync
  process call remains for ticket 04 to remove).
- **2026-08-24 (verification note)**: Verified live on Hyprland via grim captures:
  collapsed accordions with counts, expanded cards, action pills, the `↩ Reply`
  pill (real DBus `inline-reply` action via `gdbus`), DND/Clear-All header, and
  the empty state; `scripts/smoke-toasts.sh` passes and `qmllint` exits 0 with
  warning parity to the pre-change baseline. Pointer/keyboard injection tooling
  was unavailable, so click-driven flows (accordion toggling, reply typing +
  Enter submit, clear buttons) and the open/close transition itself are verified
  by code path + render, not interaction; ticket 04 owns the toggle UX and
  should exercise them during its live pass.
