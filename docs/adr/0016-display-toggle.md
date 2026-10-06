# ADR 0016: displays toggle through the Hyprland Lua monitor API

Date: 2026-10-06. Feature: monitors (`#04`, follow-up).

## Context

Settings → Monitors could pick the primary output and the workspace count, but
not turn an output off. Hyprland's documented runtime toggle is
`hyprctl keyword monitor <name>,disable`, and the matching re-enable is
`hyprctl keyword monitor <name>,preferred,auto,1`. On this host Hyprland runs
with the Lua config parser (Omarchy quattro, Hyprland 0.56), and there the
legacy keyword path is gone:

```
$ hyprctl keyword monitor DP-2,disable
keyword can't work with non-legacy parsers. Use eval.
```

A toggle built on `keyword` would exit non-zero and no-op silently while the row
kept showing the old state. The same failure is live in Omarchy's own Display
panel (basecamp/omarchy#6968).

A disabled output is not a `wl_output`, so it disappears from
`Quickshell.screens`. The panel therefore cannot build its list from Quickshell
alone: a display that was already off would never be offered for re-enable.

## Decision

Displays are listed and toggled through the Hyprland Lua monitor API.

- `services/MonitorService.qml` polls `hyprctl monitors all -j`. The `all` list
  keeps inactive outputs with their geometry (name, description, model, x, y,
  width, height, refreshRate, scale) and a `disabled` flag, so a display that is
  off is still listed.
- The service normalizes each entry to `{name, description, model, disabled,
  mode, position, scale}`. `mode` is `WxH@round(refresh)`, `position` is
  `round(x)xround(y)`, `scale` is the reported scale; missing geometry falls
  back to `preferred` / `auto` / `1`.
- `setEnabled(name, enabled)` runs
  `hyprctl eval 'hl.monitor({ output = <name>, disabled = <bool> })'`, and for a
  re-enable appends the stored `mode`, `position`, and `scale`. The output name
  is escaped into the Lua string; a disabled output still reports its old
  geometry, so the re-enable restores what the user had rather than a guessed
  preferred mode. A no-op (the target is already in the requested state) returns
  without shelling out.
- Disabling is refused while only one display is on: `multiMonitor` is false,
  `setEnabled` early-returns, and the last display's pill goes inert through a
  new `SettingsToggleRow.locked` state (`PillButton.locked`) that keeps its real
  fill and label colour, with a "Last display, stays on" row hint. It is not
  dimmed, because a dimmed true-state switch reads as if the display were off.
  The same `locked` (inert, no dim) state covers an in-flight toggle, so the
  staying row does not flash as its state changes; the rows stay inert through
  the post-command poll (`toggleSettling`, folded into `toggleBusy`) and refuse
  while busy, so neither a same-instant double-click nor a click inside the
  refresh window can race past the guard and leave zero displays on. A toggle
  bumps `toggleEpoch`, a poll records the epoch it started for, and the poll only
  clears `toggleSettling` when its epoch matches: a background poll that started
  before the toggle cannot clear the guard while still holding pre-toggle data. A
  watchdog kills a hung command and re-polls; when only the post-command poll is
  slow it grants one extra window before forcing recovery, so a stuck `hyprctl`
  cannot freeze the toggles and a merely slow poll does not drop the guard early.
- The toggle list keys its `Repeater` on `MonitorService.monitorNames`, a list
  that changes only when the connected set changes. A toggle rewrites
  `MonitorService.monitors` (the per-display data) without touching the name
  list, so the delegates persist and their bindings update in place instead of
  being rebuilt. Each row reads one `MonitorService.rowState(name)` result for
  both its monitor and its `lastDisplay`, so those two cannot be seen
  half-updated: deriving `lastDisplay` from `multiMonitor` in a separate binding
  let the disabled row pass through a "last display" state for one evaluation
  pass and fire the hint swap. On a hotplug `monitors` is assigned before
  `monitorNames`, and a row is hidden while its monitor is absent, so a
  just-added row is built with its data and a just-removed one disappears
  without an empty flash. The hint text then swaps with a fade and a small
  scale nudge (`SettingsToggleRow`'s `idHintSwapAnimation`, the same shape as the
  volume module's label swap), so "Last display, stays on" arrives smoothly
  rather than snapping in.
- The list refreshes on `Quickshell.screens` count changes (hotplug and the
  shell's own toggle), after each command, and on a 10s fallback timer. A
  refresh request that lands mid-poll is queued and runs when the poll exits
  rather than being dropped, so the row cannot sit stale on a pre-toggle
  snapshot. The toggle list renders through a `Repeater` of the shared
  `SettingsToggleRow`, filtered by the shared `SettingsFilter` under the
  `Displays` label.
- The primary dropdown keeps reading `Quickshell.screens` (`screenNames`), so it
  only ever offers an active output.

## Alternatives considered

- **`hyprctl keyword monitor`.** Rejected: the Lua parser rejects it outright
  (the failure that motivated this ADR).
- **Persist the pre-disable mode to the `monitor-settings` state file.** The
  disabled output already reports its geometry in `monitors all -j`, so the
  snapshot adds a file and a schema for nothing; rejected.
- **Write the toggle into `~/.config/hypr/modules/monitors.lua`.** Makes the
  choice survive reboots but edits user-owned compositor config from the shell,
  and a bad write leaves the session unbootable; rejected.
- **List only `Quickshell.screens`.** A display disabled before the shell starts
  would never appear to be re-enabled; rejected.

## Consequences

- Toggling is runtime-only: a Hyprland config reload or reboot re-applies the
  compositor's own monitor rules and turns every display back on. Persisting a
  layout stays Hyprland's job.
- The panel works on any Hyprland with the Lua API even when the shell boots
  with a display already off, and shows `No displays detected` when `hyprctl`
  is absent.
- Disabling the display the settings card is open on closes that card; the
  remaining display keeps the shell.
