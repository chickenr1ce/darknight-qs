# Ticket 04 — Bar Module Migration & Final Shell Integration

**Status**: Blocked by Ticket 01, Ticket 02, Ticket 03  
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

- [ ] Bar displays notification bell in right cluster without any external `swaync` processes.
- [ ] Receiving a notification dynamically increments the bar's numeric badge counter.
- [ ] Left-clicking the bar module smoothly toggles the Notification Center panel.
- [ ] Right-clicking toggles DND mode; bell icon updates to `` and badge hides.
- [ ] DP-2 / secondary monitors inherit the bar module seamlessly without duplicate server registrations.
- [ ] Full repo passes `qmllint` and `qt-qml-review`.
