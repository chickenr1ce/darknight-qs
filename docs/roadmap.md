# Roadmap

Planned work that is not done yet. Completed plan artifacts are frozen under
`docs/plans/archive/` (index: `docs/plans/README.md`). Decisions behind shipped
work are in `docs/adr/`; domain terms in `CONTEXT.md`; coding rules in
`docs/coding-conventions.md`.

Last updated: 2026-09-29.

## Open

### Matugen theme pipeline

The palette is hardcoded in `config/Colors.qml`. The goal is to derive Material
roles from the wallpaper with matugen and map them onto the shell's tokens,
keeping the hardcoded palette as the fallback when the generated file is absent.

- **Theme map.** Freeze the mapping from generated roles to `config/Colors.qml`
  tokens before writing any loader code. Sources: `~/.config/matugen/config.toml`
  and the generated `colors.json`. Done when the mapping table is recorded here.
- **Theme load.** A file-backed loader for the generated `colors.json` that
  falls back to the hardcoded palette. Done when regenerating the file repaints
  the bar with no restart and no dropped state.
- **Switcher.** One place to switch themes. Open question: bar module, power
  menu, or keybind. Answer it, then build.

Risk: generated roles may not cover every bar token. The frozen map bounds it.

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
