# 01: Cava settings save waits for the state file to load

**What to build:** `services/CavaService.qml` uses the same save guard as the
other `StateFile` callers, `loading || !loaded`, so a settings change made
before `cava-settings` finishes loading cannot overwrite the saved file.

**Blocking:** None

**Blocked by:** None

**Status:** ready-for-agent

## Origin

Discovered during the 2026-10-07 architecture review. Seven services guard
their save with `x.loading || !x.loaded` (`AudioService`, `BarVisibilityService`,
`DashboardService`, `FontService`, `MonitorService`, `MprisPlayers`,
`ThemeService`). Cava's five change handlers (`onSensitivityChanged`,
`onAutoSensitivityChanged`, `onBarCountChanged`, `onStyleModeChanged`,
`onMaxHeightChanged`, lines 37-65) check `idSettingsState.loading` only.

This is a latent race, not a demonstrated data-loss bug. The incident that
introduced `StateFile.loaded` (archived deepening plan, BarVisibility rebase
note) was a `property var` map firing `onChanged` at construction. Cava's five
settings are literal `int`/`bool` properties, written only by
`applySettings` (inside `loading`), `setStyleMode`/scroll, and
`windows/CavaSettingsView.qml`. Reaching the pre-load write needs a real user
change inside the async load window. `StateFile` sets `loaded` on
`onLoadFailed` too, so the stricter guard does not block saves for a user
with no file yet.

Calendar (`saveZones`, `saveHiddenCalendars`) and Weather (`saveLocation`,
`saveCache`) stay unguarded and are out of scope: the first three are user
actions, and `saveCache` writes a cache file after a fetch, where overwriting
is harmless.

## Acceptance criteria

- [ ] All five Cava change handlers return early on
      `idSettingsState.loading || !idSettingsState.loaded`, before
      `saveSettings()` and before `requestEngineRestart()`.
- [ ] `onBarCountChanged` still resets `root.levels` before the guard, as it
      does today.
- [ ] `scripts/test-panel-logic.sh` asserts the Cava guard includes `!loaded`
      alongside the existing guard checks.
- [ ] `scripts/check.sh` passes.
- [ ] Live check: changing a Cava setting in Settings still persists across
      `scripts/restart.sh`.
