# 02 — One Panels registry owns the one-panel rule (c1, F9)

Status: done
Blocking: #07
Blocked By: #01
Source: docs/plans/06-architecture-review.html Part 2 c1 (Strong, top recommendation), Part 1 F9 (Low); ADR 0001.

## Objective

Collapse the N-squared mesh of triggers writing each other's visibility into one registry. Each service keeps its own state (composition per ADR 0001 alternatives). The registry owns the one-panel rule and `anyOpen`. Fix the toasts-over-cava leak as part of this.

## Acceptance criteria

- New `services/PanelState.qml` plain component owns the debounce (300 ms re-click), anchor-before-visibility branch, and outside-close stamp. All three services compose it (delegate existing property names so current bindings keep working).
- New `services/Panels.qml` singleton owns the one-panel rule: `anyOpen`, plus `toggleCalendarAt`, `toggleCenterAt`, `toggleCavaAt` (or equivalent) that close the other two before toggling the target. Registered in `services/qmldir`.
- `modules/Clock.qml`, `modules/Notifications.qml`, `modules/Cava.qml` call the registry instead of writing the other services directly. No trigger writes another service's visibility property.
- `windows/NotificationPopups.qml` hides while any panel is open (calendar, center, cava). Toasts no longer render over the cava panel.
- ADR 0001 gets an amendment note: the "triggers hide the other panel first" line now points at the registry.
- `scripts/lint.sh` and `scripts/lint-review.sh` pass (no new findings vs baseline except the new files' accepted entries).
