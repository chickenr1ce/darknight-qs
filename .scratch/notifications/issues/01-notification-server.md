# Ticket 01 — Native DBus Notification Server & State Service

**Status**: Done
**Blocking**: Blocks Ticket 02, Ticket 03, Ticket 04  
**Blocked By**: None  
**Spec Reference**: `docs/plans/04-phase-6b-notifications-spec.html` (ECO-HY3b §3 & §5)

---

## 1. Objective

Create the native notification server singleton service replacing external `swaync`. Implement `services/NotificationServer.qml` (and register in `services/qmldir`) using `Quickshell.Services.Notifications.NotificationServer` to handle the `org.freedesktop.Notifications` DBus protocol directly within Quickshell.

---

## 2. Technical Scope & Interfaces

- **File**: `services/NotificationServer.qml` (Singleton)
- **Registration**: Add `singleton NotificationServer 1.0 NotificationServer.qml` to `services/qmldir`.
- **Capabilities Configured**:
  - `actionsSupported: true`
  - `bodySupported: true`
  - `bodyMarkupSupported: true`
  - `inlineReplySupported: true`
  - `persistenceSupported: true`
  - `keepOnReload: true`
- **State Management**:
  - `dndEnabled: bool` (Do Not Disturb toggle state)
  - `unreadCount: int` (Computed dynamic unread count)
  - `activeToasts: list<Notification>` (Queue of currently displaying popup toasts)
  - Signal `toastReceived(Notification notification)`
- **Methods**:
  - `toggleDnd(): void`
  - `dismissAll(): void`
  - `dismissGroup(string appName): void`

---

## 3. Acceptance Criteria

- [x] `notify-send "Test" "Hello from DBus"` is successfully received by `NotificationServer` when Quickshell is active.
- [x] Notifications have `notification.tracked = true` set appropriately so they persist in `trackedNotifications`.
- [x] Enabling DND suppresses transient toast emissions while still recording notifications to history.
- [x] Code strictly follows `docs/coding-conventions.md` (`id: root`, `id` prefixes, versionless imports) and passes `qmllint`.
