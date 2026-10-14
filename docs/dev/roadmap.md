# Roadmap

Planned work that is not done yet. Completed plan artifacts are frozen under
`docs/plans/archive/` (index: `docs/plans/README.md`). Decisions behind shipped
work are in `docs/adr/`; domain terms in `CONTEXT.md`; coding rules in
`docs/dev/CODING_STANDARDS.md`.

Last updated: 2026-10-14.

## Open

### Hotplug verification

Phase 5 shipped DP-1 gating and the 1–5 / 6–10 workspace split, but the unplug
run never happened. Source: the `Variants` block in `shell.qml`. Done when each
output is unplugged and replugged, the bar recreates with no errors, and the
date is recorded.

### Architecture review follow-ups

Cards 05 to 11 of `docs/plans/12-architecture-review.html` are pending; its
status block tracks them. The done cards left five gaps:

- **MPRIS shuffle guard untested.** The card 03 review ruled the grep on the
  `shuffleSupported` guard in `MprisPlayers.toggleShuffle()` out, and no
  behaviour test replaced it. Done when a test drives `toggleShuffle()` on a
  player without shuffle support and sees `shuffle` unchanged.
- **Calendar zone times requested twice on boot.** In
  `services/CalendarService.qml`, `idZoneTimer` (`triggeredOnStart`) requests a
  zone run, and the `calendar-zones` state load then changes `worldZones`, whose
  handler requests another. Done when boot issues one `calendar-clock.py` run
  for the loaded zones.
- **Card 01 drain race has no regression test.** The race fixed in the third
  review round of the coalesced-run pass (a request landing around the deferred
  drain in `services/CoalescedRun.qml`) is fixed in code only. Done when
  `tests/coalesced-run.qml` fails on the pre-fix ordering.
- **`app launcher` gate flake unexplained.** `scripts/test-app-launcher.sh`
  failed once during card 01 and passed on rerun; the cause was never found.
  Done when the flake is reproduced and fixed, or ruled out with a recorded
  reason.
- **Card 01 failed-start check can close twice.** `CoalescedRun.checkLaunch`
  runs twice for one `launchSeq` when a failed start and a queued request land
  in the same tick, arming a spurious retry (reproduced with a synthetic tick
  order under qmltestrunner). Done when one close is guaranteed in that tick
  and a regression case covers it.

## Candidate

Build only if it earns daily use.

- **Idle inhibitor.** `Quickshell.Wayland._IdleInhibitor`, a private API.
  Recheck the type name at build time; works or dropped.

## Done

- Architecture review 12, cards 01 to 04: one `CoalescedRun` module for
  every Process lifecycle, the launcher menu-item set behind `AppService`, gates
  that test behaviour at the interface (`CODING_STANDARDS.md` §7), and the
  Background lifecycle in `services/ThemeBackground.qml`
  (`docs/plans/12-architecture-review.html`).
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
- IPC targets: `power`, `calendar`, `notifications`, `cava`, `audio`,
  `dashboard`, `dnd`, and `volume` `IpcHandler`s, with the bar-anchor wiring
  extracted into `services/BarAnchor.qml` and the per-module trigger adapter
  into `services/PanelTrigger.qml` so a bar-panel IPC toggle reuses the click
  path. DND state persists in the `notifications` state file. User page
  `docs/user/ipc.md`.
- Audio card: right-clicking the bar's audio module opens a floating card
  (`windows/AudioCenter.qml`) with output, input (default mic, volume, live
  level meter, "in use by"), and a per-app mixer, replacing `pavucontrol` as
  the everyday path. Defaults go through `AudioService` with `wpctl
  set-default`; WirePlumber restores every choice, so the shell adds no state
  file. ADR 0020; user page `docs/user/audio.md`.
- Volume OSD: an event-driven level readout (`windows/VolumeOsd.qml`) raised by
  PipeWire volume or mute changes from any source, bottom-center on the focused
  monitor, click-through, and off-switchable in Settings → Audio. ADR 0017.
- App launcher: the dashboard's Apps tab (`windows/DashboardAppsView.qml`,
  `services/AppService.qml`, `services/AppLogic.js`) replaces the Media
  placeholder: ranked search with Pinned/Recent/All sections, inline
  Focus/Kill/Pin on a running app, a shared context menu, absolute-workspace
  launch through the Hyprland Lua API, a hidden-apps Settings section, and the
  `dashboard apps` IPC target. ADR 0018; user page `docs/user/app-launcher.md`.
- Workspaces tab: the dashboard's Workspaces tab
  (`windows/DashboardWorkspacesView.qml`, `services/WorkspaceService.qml`,
  `services/WorkspaceLogic.js`) shows one non-wrapping row of workspace maps per
  enabled monitor, each map drawing its windows at their real positions. Left
  click on a map or a window switches to that workspace, a drag moves a window to another workspace, a right
  click opens the window menu, and a middle click closes the window gracefully.
  ADR 0019; user page `docs/user/workspaces-tab.md`.
- Cava restart backoff: a repeatedly crashing cava process retries at 1.5 s,
  doubling to a 30 s ceiling, and a settings-driven restart does not count as a
  crash (`services/CavaLogic.js`).
- Portable scratch dirs: scripts create temp dirs under `${TMPDIR:-/tmp}`
  instead of a fixed path, and `scripts/lint-shell.sh` guards against
  reintroducing the old one.
