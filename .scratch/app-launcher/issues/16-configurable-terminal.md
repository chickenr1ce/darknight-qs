# 16: Configurable terminal emulator

**Status:** in progress

**Blocked by:** 06

**Blocking:** none

The launcher hardcodes `kitty -e` for `Terminal=true` entries and the Run
"query" row (`services/AppService.qml:13`). The launcher spec lists "A
configurable terminal; `kitty -e` is a constant for now" as out of scope. This
makes the terminal a Settings value under Apps.

## Acceptance criteria

- [x] `AppService` gains a terminal setting persisted in the existing
  `app-launcher` state file as a `terminal` string key; default `kitty -e`.
- [x] A pure `AppLogic.terminalArgv(value)` turns the stored string into an argv
  prefix (whitespace split, empty returns `[]`), node-tested.
- [x] `launch`, `launchOnWorkspace`, and `runQuery` all use the configured
  prefix, so a custom terminal applies everywhere.
- [x] Settings → Apps gains a Terminal text row, built from a shared
  `components/SettingsTextRow.qml`, registered in
  `SettingsService.sectionRegistry` under the `apps` options; the Settings
  search finds it under "Terminal".
- [x] `scripts/test-app-launcher.sh` and `scripts/test-panel-logic.sh` assert
  the state key, the delegation, the row, and the search label.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [x] Docs updated: `docs/user/app-launcher.md`, ADR 0018, the spec, CONTEXT.

## Amendments (2026-10-10)

Landed: the `terminal` key in the `app-launcher` state file (unset or empty
falls back to `kitty -e`), `AppLogic.terminalArgv`, and
`AppService.defaultTerminal` / `terminalCommand` / `terminalPrefix` /
`setTerminal`. `launch`, `launchOnWorkspace`, and `runQuery` all use
`terminalPrefix`. Settings gained the shared `components/SettingsTextRow.qml`,
the Apps → Terminal row in `windows/AppsSettingsView.qml`, and the `Terminal`
option in `SettingsService.sectionRegistry`, so Settings search finds it.

`scripts/test-app-launcher.sh` asserts the state key, the `terminalArgv`
delegation, and the `terminalArgv` node cases. `scripts/test-panel-logic.sh`
asserts the AppsSettingsView row, the `SettingsTextRow` composition, the
`setTerminal` call, and the `Terminal` search option.

`scripts/check.sh` passes all gates and `scripts/boot-check.sh` reports loaded.

Live (2026-10-10, orchestrator): Settings → Apps → Terminal renders the
effective command; setting it to `alacritty -e` (through the state file and
through the field) round-trips; a `Terminal=true` entry (btop) launched as
`alacritty -e btop`; the Run "query" row ran `alacritty -e sh -c sleep 30`.

Review fixes (2026-10-10): `components/SettingsTextRow.qml` sets
`restoreMode: Binding.RestoreNone` on its text Binding, so focusing the field
no longer blanks it and blurring no longer commits empty; it releases focus on
commit so the field shows the trimmed value; the unused placeholder was dropped.
`scripts/test-app-launcher.sh` and `scripts/test-panel-logic.sh` gained the
per-path prefix gates and the Terminal-label match gate.

`CONTEXT.md` names no launcher terminal, so it needed no change; the README
optional-tools row now calls `kitty` the default terminal.
