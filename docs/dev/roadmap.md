# Roadmap

Planned work that is not done yet. Completed plan artifacts are frozen under
`docs/plans/archive/` (index: `docs/plans/README.md`). Decisions behind shipped
work are in `docs/adr/`; domain terms in `CONTEXT.md`; coding rules in
`docs/dev/CODING_STANDARDS.md`.

Last updated: 2026-10-09.

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

- Persisted-settings schema: decided against a schema. `StateFile` owns the
  load guard and a `saveJson(payload)` helper, so every JSON writer goes through
  it; parsing stays per service.
- Logic tests run the shipped code: pure parsing, formatting and ordering moved
  into per-service `.pragma library` modules (`services/*Logic.js`, see
  `CONTEXT.md`), tested under node through `tests/qmljs.js` instead of Python
  copies. `tests/mutation-probe.sh` catches 15 planted bugs, up from 0; the Cava
  settings save waits for the state file to load like the rest.
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
- IPC targets: `power`, `calendar`, `notifications`, `dashboard`, `dnd`, and
  `volume` `IpcHandler`s, with the bar-anchor wiring extracted into
  `services/BarAnchor.qml` so an IPC toggle reuses the click path. DND state
  persists in the `notifications` state file. User page `docs/user/ipc.md`.
- Volume OSD: an event-driven level readout (`windows/VolumeOsd.qml`) raised by
  PipeWire volume or mute changes from any source, bottom-center on the focused
  monitor, click-through, and off-switchable in Settings → Audio. ADR 0017.
- App launcher: the dashboard's Apps tab (`windows/DashboardAppsView.qml`,
  `services/AppService.qml`, `services/AppLogic.js`) replaces the Media
  placeholder: ranked search with Pinned/Recent/All sections, inline
  Focus/Kill/Pin on a running app, a shared context menu, absolute-workspace
  launch through the Hyprland Lua API, a hidden-apps Settings section, and the
  `dashboard apps` IPC target. ADR 0018; user page `docs/user/app-launcher.md`.
- Cava restart backoff: a repeatedly crashing cava process retries at 1.5 s,
  doubling to a 30 s ceiling, and a settings-driven restart does not count as a
  crash (`services/CavaLogic.js`).
- Portable scratch dirs: scripts create temp dirs under `${TMPDIR:-/tmp}`
  instead of a fixed path, and `scripts/lint-shell.sh` guards against
  reintroducing the old one.
