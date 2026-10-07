# 04: Monitor settings and workspace split in node-run JS

**What to build:** `services/MonitorLogic.js` holds the settings parse,
workspace-split arithmetic and Hyprland monitor-spec helpers now inline in
`MonitorService.qml`; the panel-logic tests run the real file.

**Blocking:** None

**Blocked by:** 01

**Status:** done

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`.

## Acceptance criteria

- [x] `MonitorLogic.js` exports `clampWorkspacesPerMonitor(value, fallback)`,
      `parseMonitorSettings(text, fallbackCount)` returning
      `{ primary, workspacesPerMonitor }` or `null`,
      `orderMonitors(primary, screenNames)`,
      `firstWorkspaceFor(ordered, monitorName, perMonitor)`, and `escapeLua`,
      `modeFor`, `positionFor`, `scaleFor` over plain monitor objects.
- [x] `MonitorService.orderedMonitors`, `firstWorkspaceFor`,
      `applySettings` and `setEnabled` delegate to it; `applySettings` still
      writes `Globals.primaryMonitorOverride`. Public names stay; ADR 0013's
      `Globals` shape (`screensByPosition`, `primaryMonitor`,
      `onPrimaryMonitor`) is untouched.
- [x] The three `MonitorService` mirrors in `test-panel-logic.sh`
      (`applySettings`; `orderedMonitors`/`firstWorkspaceFor`;
      `modeFor`/`positionFor`/`scaleFor`/`escapeLua`/`setEnabled`) become node
      runs; the Python copies are deleted.
- [ ] `scripts/check.sh` passes; live check: Settings → Monitors primary and
      workspace count still apply, and the workspace module numbers match.

## Measurement

- [x] `tests/mutation-probe.sh <repo>` reports `caught` for: the `MonitorService.firstWorkspaceFor` and `clampWorkspacesPerMonitor` mutants. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [x] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.

## Amendments

2026-10-07. AC2 said "public names stay"; `MonitorService.modeFor`,
`positionFor` and `scaleFor` were removed from the service because they moved
into `MonitorLogic.js`. No caller referenced them (grep clean), and the
service reaches them through `MonitorLogic`, so the intent holds. Recorded here
because the literal name list changed.
