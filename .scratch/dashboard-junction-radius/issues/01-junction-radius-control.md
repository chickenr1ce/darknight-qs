# 01: Junction radius control in settings

**What to build:** A Dashboard section in the settings window exposes the
dashboard junction radius over the intended 0 to 32 range, persists the choice
in a new state file, and applies it live so the bar junction re-shapes without
a shell restart.

**Blocking:** None

**Blocked by:** None

**Status:** ready-for-agent

## Origin

Discovered during the dashboard-settings branch's Spec review. ADR 0005 and
`CONTEXT.md` both say the junction radius is user adjustable 0 to 32, and
ticket `#02` closes with "#03 adds the settings control and its state-file
persistence for the radius". `#03` was reopened and moved settings to a
Hyprland-managed window (ADR 0007) with no Dashboard section, so neither the
control nor the persistence shipped. The runtime value is fixed at
`Globals.junctionRadiusDefault` (16) on `services/DashboardService.qml` with no
`FileView`. The geometry, the default, and `Globals.junctionRadiusMax` (32) are
unchanged; only the control and its persistence are outstanding.

## Acceptance criteria

- [ ] Settings gains a Dashboard section: an entry in
      `SettingsService.sections` with searchable `options` labels and a view in
      `windows/`, following `docs/settings-sections.md`.
- [ ] The control sets `DashboardService.junctionRadius` across 0 to
      `Globals.junctionRadiusMax` (32), where 0 renders the square join, and the
      dashboard junction re-shapes live with no shell restart.
- [ ] The chosen radius persists across shell restart through a state file under
      the quickshell state dir, with the `FileView` echo guard the other state
      files use (`services/BarVisibilityService.qml`).
- [ ] The section appears in settings search, and searching its labels shows the
      control rather than an empty body.
- [ ] Type lint plus review lint gates pass; `scripts/test-panel-logic.sh`
      asserts the control wiring and the persistence guard.
