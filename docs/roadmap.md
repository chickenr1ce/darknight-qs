# Roadmap

Planned work that is not done yet. Completed plan artifacts are frozen under
`docs/plans/archive/` (index: `docs/plans/README.md`). Decisions behind shipped
work are in `docs/adr/`; domain terms in `CONTEXT.md`; coding rules in
`docs/coding-conventions.md`.

Last updated: 2026-09-29.

## Open

### Theme switching

Switch the desktop palette from one place, using omarchy v4 (`quattro`) theme
directories as the supply. The shell owns the selection, repaints live, and
re-renders Hyprland, kitty, and hyprlock. The switcher is a Settings Theme
section plus the dashboard Theme block, and each theme's backgrounds are pickable
per theme. Decisions in ADRs 0010 and 0011.

The matugen pipeline this replaces is dropped for now: the palette comes from the
theme's `colors.toml`, not from the wallpaper. GTK, icon themes, rofi, and other
apps are deferred, and a switching keybind is a later addition.

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

- Waybar migration, Phases 0–7
  (`docs/plans/archive/01-master-quickshell-migration.html`).
- Unified slab (`02`), notifications exploration and spec (`03`, `04`),
  architecture review (`docs/plans/archive/06-architecture-review.html`),
  deepening (`07`).
- Calendar: month view, events, agenda, and world clocks. ADR 0001 (panel
  placement) and ADRs 0002–0004 (iCal backend and per-calendar fetch).
- Weather: dashboard block with city search. `docs/weather.md`.
- Cpu module: deleted 2026-09-23; the bar slot went to cava. Restore from git
  history if a CPU readout earns daily use.
