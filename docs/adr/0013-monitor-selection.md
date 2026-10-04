# ADR 0013: the primary monitor is a runtime choice

Date: 2026-10-04. Feature: monitors (`#04`).

## Context

The full-bar monitor was the literal `"DP-1"` in `config/Globals.qml`. Six
modules (`Tray`, `Media`, `Audio`, `PowerMenu`, `Cava`, `Notifications`) hide on
every non-primary screen by composing `Globals.onPrimaryMonitor(monitorName)`,
so a friend whose outputs have different names saw the full bar nowhere and the
minimal bar everywhere. The only fix was to edit tracked source, which then
blocked `scripts/update.sh`, because it refuses a dirty tree.

Quickshell exposes the connected screens as `Quickshell.screens`, each with an
`x`, `y`, and `name`. The six modules already receive their screen's name from
the shell, so the policy needs a runtime value, not a code branch.

## Decision

The primary monitor resolves at runtime from the connected screens, with a
persisted override.

- `config/Globals.qml` imports `Quickshell` and exposes `screensByPosition`:
  `Quickshell.screens` sorted by `x`, then `y`, then `name`, so "first" is
  stable across connects.
- `Globals.primaryMonitorOverride` holds the chosen screen name, empty when
  unset. `Globals.primaryMonitor` is the override when it names a currently
  connected screen, otherwise the first screen in `screensByPosition`, otherwise
  `""`. An override pointing at a disconnected screen therefore falls back
  instead of leaving the bar with no primary.
- `Globals.onPrimaryMonitor(monitorName)` keeps its name and shape
  (`monitorName === "" || monitorName === primaryMonitor`), so the six modules
  need no change.
- `services/MonitorService.qml` owns the override and persists it to the
  `monitor-settings` state file. It validates a choice against the connected
  names, exposes `screenNames`, and guards saves on the `StateFile`
  loading/loaded flags, like `DashboardService`.
- `config/Globals.qml` does not import `qs.services`, because services already
  import `qs.config`; the reverse would be a cycle. `Globals` reads
  `Quickshell.screens` directly and `MonitorService` lives on the services side.
- Settings gains a Monitors section whose `Primary monitor` dropdown offers
  `Auto` plus each connected screen. `Auto` clears the override.
- `MonitorService.workspacesPerMonitor` (default 5) sets how many workspaces
  each monitor owns. `orderedMonitors` lists the primary first, then the rest of
  `screensByPosition`; `firstWorkspaceFor(name)` is that monitor's index times
  the count, plus one, so the primary owns `1–N`, the next `N+1–2N`, and so on.
  An empty or unknown name yields 1.
- `modules/Workspaces.qml` sizes its row from `workspacesPerMonitor` and starts
  at `firstWorkspaceFor(root.monitorName)`, with no `DP-2` literal.
- The Monitors section adds a `Workspaces per monitor` slider (1–20) that writes
  through `setWorkspacesPerMonitor`, which rounds, clamps, and persists in the
  same `monitor-settings` file.

## Alternatives considered

- **Keep the literal and tell friends to edit it.** Blocks `git pull` (dirty
  tree) and turns every update into a merge conflict; rejected.
- **Choose the primary by resolution or connector type.** Guessing from hardware
  picks the wrong monitor too often and cannot express preference; rejected in
  favour of an explicit choice plus a positional default.
- **Resolve in `MonitorService` and have `Globals` call it.** Circular, since
  services import `qs.config`; rejected.
- **Persist the override in `Globals`.** `Globals` is compiled configuration,
  not a state owner, and the `StateFile` seam lives in services; rejected.

## Consequences

- A friend with any output names gets a working bar with no source edit; the
  default is the leftmost/topmost screen.
- The full bar follows the choice live: `onPrimaryMonitor` is a binding on
  `primaryMonitor`.
- The `monitor-settings` file holds `{primary, workspacesPerMonitor}`.
- The workspace split is configurable: each monitor owns a contiguous block of
  `workspacesPerMonitor` workspaces, primary first. The fixed 5-per-monitor
  `DP-1`/`DP-2` split is gone.
- The two-monitor layout assumption stays: the bar is still built for a primary
  plus a secondary screen.
