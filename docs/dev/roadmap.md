# Roadmap

Planned work that is not done yet. Completed plan artifacts are frozen under
`docs/plans/archive/` (index: `docs/plans/README.md`). Decisions behind shipped
work are in `docs/adr/`; domain terms in `CONTEXT.md`; coding rules in
`docs/dev/coding-conventions.md`.

Last updated: 2026-10-03.

## Open

### Hotplug verification

Phase 5 shipped DP-1 gating and the 1–5 / 6–10 workspace split, but the unplug
run never happened. Source: the `Variants` block in `shell.qml`. Done when each
output is unplugged and replugged, the bar recreates with no errors, and the
date is recorded.

## Candidate

Build only if it earns daily use.

- **Idle inhibitor.** `Quickshell.Wayland._IdleInhibitor`, a private API.
  Recheck the type name at build time; works or dropped.

## Done

- Displays: turn an output off or back on from Settings → Monitors through
  `hyprctl eval` plus the Lua `hl.monitor` API, with the last display guarded.
  ADR 0016.
- Theme switching: omarchy v4 (`quattro`) theme directories as the palette
  source, live repaint, and desktop retint (Hyprland, kitty, hyprlock). The
  switcher is the Settings Theme section plus the dashboard Theme block, with
  each theme's backgrounds pickable per theme. ADRs 0010 and 0011. The matugen
  pipeline is dropped (the palette comes from `colors.toml`, not the wallpaper);
  GTK, icon themes, rofi, and a switching keybind are deferred.
- Bundled darknight theme: `assets/themes/darknight` (the old hardcoded
  `config/Colors.qml` fallback, plus two backgrounds) is seeded into the theme
  root by `scripts/install.sh`, and `ThemeService` selects it when no selection
  is saved, so a fresh install has a theme in the picker. ADR 0010 amendment.
- Waybar migration, Phases 0–7
  (`docs/plans/archive/01-master-quickshell-migration.html`).
- Unified slab (`02`), notifications exploration and spec (`03`, `04`),
  architecture review (`docs/plans/archive/06-architecture-review.html`),
  deepening (`07`).
- Calendar: month view, events, agenda, and world clocks. ADR 0001 (panel
  placement) and ADRs 0002–0004 (iCal backend and per-calendar fetch).
- Weather: dashboard block with city search. `docs/user/weather.md`.
- Cpu module: deleted 2026-09-23; the bar slot went to cava. Restore from git
  history if a CPU readout earns daily use.
- Polkit agent: a native Quickshell authentication dialog
  (`services/PolkitService.qml` + `windows/PolkitDialog.qml`, B2 "Context
  Runner"), replacing the external `polkit-kde-agent`. ADR 0015; the 2026-08-23
  incident is closed in `docs/incidents/polkit-agent-incident.md`.
