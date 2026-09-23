# 03 — Monitor policy as data, composed visibility (c2)

Status: done
Blocking: (none)
Blocked By: #01
Source: docs/plans/06-architecture-review.html Part 2 c2 (Strong); shell.qml, modules/Tray.qml, modules/Media.qml, modules/Workspaces.qml, config/Globals.qml.

## Objective

Stop shell.qml from shadowing module-owned `visible` bindings. The primary-monitor rule lives in one place; modules compose it with their own content rule.

## Acceptance criteria

- `config/Globals.qml` defines the policy once: `primaryMonitor` plus a pure `onPrimaryMonitor(monitorName)` helper (empty monitor name means shown, so unbound previews keep working).
- `modules/Tray.qml`, `modules/Media.qml`, `modules/Audio.qml`, `modules/PowerMenu.qml`, `modules/Cava.qml`, `modules/Notifications.qml` each declare `property string monitorName` and compose visibility as `Globals.onPrimaryMonitor(monitorName) && <own rule>` (modules with no content rule keep only the screen check).
- `shell.qml` passes `monitorName` instead of setting `visible: monitorName === "DP-1"` on those six modules. No instantiation sets `visible:` on a module that owns its own rule.
- `modules/Workspaces.qml` keeps its `firstWorkspaceId` split and gains no visibility gate (it shows on every monitor by design).
- Behavior unchanged: DP-1-only set still DP-1-only; Tray hides when empty; Media hides with no player.
- `scripts/lint.sh` and `scripts/lint-review.sh` pass.
