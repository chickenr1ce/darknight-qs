# Ticket 04 — Bar Module Migration & Final Shell Integration

**Status**: Done
**Blocking**: None (Final milestone)  
**Blocked By**: Ticket 01, Ticket 02, Ticket 03  
**Spec Reference**: `docs/plans/04-phase-6b-notifications-spec.html` & `docs/plans/01-master-quickshell-migration.html` (D7, Q1)

---

## 1. Objective

Complete the migration by replacing the legacy `swaync-client` process call in `modules/Notifications.qml` with declarative bindings to `services/NotificationServer.qml`, wiring the click handler to toggle `windows/NotificationCenter.qml`, and adding active unread badge counters and DND icons.

---

## 2. Technical Scope & Interfaces

- **Files**:
  - `modules/Notifications.qml` (Bar module)
  - `shell.qml` (Instantiating popup window and center window)
- **Module Features**:
  - Bell glyph `` in `Colors.lavender` when active.
  - Slashed bell `` in `Colors.textSecondary` when DND is enabled.
  - Pill badge displaying `unreadCount` when `unreadCount > 0 && !dndEnabled`.
  - Right-click / Middle-click shortcut to toggle DND directly from the bar.
  - Left-click opens/closes `NotificationCenter`.
  - Press feedback and hover underline matching Phase 6a `ModuleBox` contracts.
- **Cleanup**:
  - Remove all `swaync` commands and dependencies.
  - Update `docs/plans/01-master-quickshell-migration.html` task checkboxes.

---

## 3. Acceptance Criteria

- [x] Bar displays notification bell in right cluster without any external `swaync` processes.
- [x] Receiving a notification dynamically increments the bar's numeric badge counter.
- [x] Left-clicking the bar module smoothly toggles the Notification Center panel.
- [x] Right-clicking toggles DND mode; bell icon updates to `` and badge hides.
- [x] DP-2 / secondary monitors inherit the bar module seamlessly without duplicate server registrations.
- [x] Full repo passes `qmllint` and `qt-qml-review`.

## Amendments

- **2026-09-12 (scope)**: `ModuleBox` only accepted Left/Right clicks, so the
  ticket's middle-click DND shortcut could never arrive. Extended the shared
  `acceptedButtons` to include `Qt.MiddleButton` (one line + comment); per-module
  `onClicked` handlers decide the per-button action. Blast radius checked:
  Workspaces/Tray disable the shared MouseArea (unaffected), Clock/Cpu have no
  handler (pulse-only no-op), Media/PowerMenu treat any button identically
  already, Audio middle-click now cycles sinks like left-click.
- **2026-09-12 (verification)**: `qmllint` full-repo exit 0 (289 pre-existing
  `qs.*` import/unqualified warnings, parity with baseline); Python review
  linter reports only pre-existing ModuleBox items plus two ORD-1 flags on the
  new badge that are false positives per `docs/coding-conventions.md` §4
  (`Layout.*` directly under `id` is deliberate project style). Live instance
  auto-reloaded the change: one intermediate reload transiently failed
  (`Notif.Notification is not a type`) while the two QML files saved in quick
  succession, the very next reload logged `Configuration Loaded` and the tail
  since is free of TypeErrors/`Failed to load`. Click/badge flows compose only
  live-verified primitives (ticket-03 `toggleCenter`, center DND `toggleDnd`,
  center `unreadCount` badge), but no pointer-injection tooling exists here —
  left/right/middle-click and badge-increment confirmation is by the user's
  eyes before merge.
- **2026-09-12 (scope)**: §2 Files lists `shell.qml`, but ticket 03 already
  instantiated `NotificationCenter {}` there — no `shell.qml` change needed.
- **2026-09-13 (live verification, eyes + screenshots)**: badge 0→4→5 and
  0→1 across arrivals (increments, hides at 0); left toggles center open/closed;
  right/middle toggle DND both directions (slashed grey bell, pill hides).
  Toasts returning on center close is intended (`NotificationPopups.qml:36-37`;
  `-t 0` test toasts are sticky so all returned). Residual width shift on DND
  toggle is the spec'd pill hide, not the glyph swap — glyph advance reserved
  via `minWidth` + `TextMetrics` measurers (first attempt used `FontMetrics`,
  which has no `text`; caught by the runtime log same session, fixed,
  error-free since). DP-2 bar shows workspaces only (no right cluster).
  Setup note: swaync is dbus-activated (`Type=dbus`), so kill-then-stop races
  it — `systemctl stop` + launch quickshell in one command wins the bus.
