# 14: "Open on workspace" lists every workspace

**Status:** done

**Blocked by:** 13 (it shares `windows/DashboardAppsView.qml` and
`scripts/test-app-launcher.sh`)

**Blocking:** none

User feedback (2026-10-09): the submenu should list every available
workspace. The user has 1–10 across two monitors (5 per monitor). Today
`AppLogic.workspaceMenu` lists only the anchor monitor's block, and labels
it by slot ("Workspace 1" is workspace 6 on the second monitor).

## What to build

The "Open on workspace ▸" submenu lists every workspace of every enabled
monitor, with absolute numbers, grouped by monitor.

- One `label` item per monitor, with the monitor name (e.g. `DP-1`), in
  `MonitorService.orderedMonitors` order, filtered to the enabled monitors.
  The anchor monitor (the one the dashboard is on) comes first.
- Under each label, one item per workspace in that monitor's block
  (`MonitorService.firstWorkspaceFor(name)` …
  `+ workspacesPerMonitor - 1`), with the text `Workspace <absolute>`.
- Each monitor's active workspace is marked `(current)` with the existing
  current glyph. Occupied workspaces keep the occupied glyph.
- Ctrl hints (`ctrl N`) appear only on the anchor monitor's items, because
  Ctrl+1…9 stays per-monitor (spec and ticket 05, unchanged).
- "New empty workspace" stays at the end: the first empty workspace in the
  anchor monitor's block, hidden when that block is full.
- Pure logic: `AppLogic.workspaceMenu` takes plain data, a list of
  `{ name, first, active }` per monitor plus `perMonitor`, `anchorName` and
  `occupiedIds`. `AppService.workspaceMenuItems()` builds that from
  `MonitorService` and `Hyprland.monitors` (each monitor's `activeWorkspace`).
  With one monitor the result is the same as today, except for the label and
  the absolute numbering.
- The submenu clamps and scrolls inside the card as ticket 03 requires; 10
  workspaces plus 2 labels must fit or scroll.
- Update the node tests in `scripts/test-app-launcher.sh`:
  - two monitors, 5 each, anchor on either one;
  - the order is anchor first;
  - absolute numbers;
  - ctrl hints only on the anchor;
  - `(current)` per monitor;
  - occupied flags;
  - "New empty workspace" computed from the anchor's block;
  - a single monitor;
  - a disabled monitor excluded.
- `docs/user/app-launcher.md` describes the submenu.

## Acceptance criteria

- [x] The submenu shows 1–10 grouped under the two monitor labels, anchor
  first, with absolute numbers.
- [x] Ctrl hints only on the anchor monitor's items; Ctrl+N behavior
  unchanged.
- [x] Node tests cover the cases above.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [ ] Live: from each monitor, the submenu lists 1–10, and picking workspace
  8 from DP-1 opens the app on 8.

## Amendments

- 2026-10-09 — `AppLogic.workspaceMenu(monitors, perMonitor, anchorName,
  occupiedIds)` replaces the single-block signature. `monitors` is a list of
  `{ name, first, active }` (an optional `disabled: true` entry is dropped).
  It emits one `label` per monitor, anchor first then the input order, and
  under each label one `workspace` item per slot with the absolute number
  (`Workspace <absolute>`), `(current)` on that monitor's active slot, the
  occupied flag from `occupiedIds`, and `ctrl N` hints only when the monitor is
  the anchor and `N <= 9`. "New empty workspace" stays last: the first free
  slot of the anchor's block, hidden when that block is full. `workspaceFor`
  and `firstEmptyWorkspace` are unchanged, so Ctrl+1…9 still resolves the
  anchor monitor's slot.
- 2026-10-09 — `AppService.workspaceMenuItems()` now builds the per-monitor
  plain data: it walks `MonitorService.orderedMonitors`, keeps the names in
  `MonitorService.enabledMonitors`, sets `first` from
  `MonitorService.firstWorkspaceFor(name)`, and reads each monitor's
  `activeWorkspace.id` from `Hyprland.monitors`. The anchor name
  (`DashboardService.anchorScreen.name`, via `anchorMonitorName()`) is passed
  through and reordered first in `AppLogic`. Occupied ids still come from the
  toplevel workspaces. The submenu is unchanged structurally: tickets 03/13
  already clamp and scroll it, and `components/ContextMenu.qml` already renders
  `kind: "label"` rows in the submenu path (`idMenuEntry`), so no ContextMenu
  or `windows/DashboardAppsView.qml` change was needed.
- 2026-10-09 — `scripts/test-app-launcher.sh` replaces the old single-block
  `workspaceMenu` expectations with two monitors × 5 slots: labels in anchor
  first order, absolute numbers 1–10, per-monitor `(current)`, occupied flags,
  ctrl hints only on the anchor (and none past 9), the anchor-block
  "New empty workspace" (including a full other block not freeing the anchor),
  a single monitor, an excluded disabled monitor, empty/zero-count/bad-first
  inputs, and the updated `menuItems` order check. Structural greps assert
  `MonitorService.enabledMonitors`, `MonitorService.orderedMonitors`,
  `Hyprland.monitors`, and the `menuItem("label")` emitter.
- 2026-10-09 — `docs/user/app-launcher.md` describes the grouped submenu:
  a label per enabled monitor with the dashboard's monitor first, absolute
  workspace numbers, per-monitor current/occupied marks, ctrl hints only on
  the dashboard monitor, and "New empty workspace" from its block.
- 2026-10-09 — Verification. `scripts/check.sh` prints `check: all gates ok`;
  `scripts/boot-check.sh <worktree>` reports `loaded` with no new QML
  warnings. The Live bullet stays unchecked: it needs a real Hyprland session
  and a throwaway GUI app, which this change deliberately did not launch.
- 2026-10-09 (orchestrator, live screenshot): Shift+F10, Down, Right on
  Firefox from DP-1 shows `DP-1` (workspaces 1–5 with ctrl 1–5, 1 current)
  and `DP-2` (6–10 with no hints, 6 current), with occupied rings on 2, 5, 7
  and 10, then "New empty workspace"; it fits inside the card. Launching on
  workspace 8 and opening from DP-2 remain the user's live check.
