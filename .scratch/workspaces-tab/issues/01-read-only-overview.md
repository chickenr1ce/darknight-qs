# 01 — Read-only overview, one row per monitor

**Status:** done
**Blocked by:** none
**Blocking:** 02, 03, 04

## Objective

Replace the Workspaces placeholder with the design-1a overview: a section for each
enabled monitor, and in it one row of workspace maps that draw the windows at
their real positions and sizes, scaled down. The tab only displays; there are no
click actions yet. The spec is `../spec.md` (sections Layout, Data, Architecture).

## Scope

- New `services/WorkspaceLogic.js` (`.pragma library`):
  - `relativeRect(at, size, monitor)`: the window rectangle as a fraction of the
    monitor's logical size, clamped to [0, 1]. The logical size divides by `scale`
    and swaps width and height for `transform` 1, 3, 5, and 7.
  - `tileWidth(viewWidth, count, gap)`.
  - `monitorTiles(monitor, firstId, count, windows, activeIds, focusedMonitorName, focusedAddress)`:
    returns `[{ id, state: "current"|"shown"|"normal", empty, urgent, caption, windows: [{ address, cls, title, rect, floating, fullscreen, focused, urgent }] }]`.
    Floating windows sort after tiled ones and fullscreen windows sort last.
  - `caption(windows)`: the distinct app names comma-joined, or `"Empty"`.
  - `inBlocks(workspaceId, blocks)`: excludes special and named workspaces.
- New `services/WorkspaceService.qml` (singleton, registered in `services/qmldir`):
  - Holds `model` (a list of `{ monitor, tiles }`) and `visibleTab` (bound by the
    view).
  - Calls `Hyprland.refreshToplevels()` when the view becomes visible, and on
    layout-changing `Hyprland.rawEvent` names while visible, coalesced by one
    `Timer` (`Globals.workspacesRefreshMs`).
  - Uses one-line delegates to `WorkspaceLogic`.
- New `windows/DashboardWorkspacesView.qml`. It is mounted in
  `windows/DashboardCenter.qml` with
  `visible: DashboardService.activeTab === "workspaces"`, and
  `idDashboardPlaceholder` no longer shows for `workspaces`. It draws:
  - the section header (name, logical resolution, hairline, and the `focused`
    tag when more than one monitor is enabled);
  - one map row per monitor;
  - a caption under each map, compact below `Globals.workspaceTileCompactWidth`;
  - a pinned status line that shows `App — title` while a window is hovered.

  The content scrolls vertically past `Globals.dashboardMaxHeight` through
  `components/ScrollBar.qml`. The view registers
  `DevGeometry.register("dashboard.workspaces", …)`.
- New tokens in `config/Globals.qml`: `workspacesRefreshMs` (80) and
  `workspaceTileCompactWidth` (100). The window gap, the icon size, and the
  colour mixes (22% fill, 55% border, 45% *shown* border) are tokens too, not raw
  values.
- New `scripts/test-workspaces.sh` (node over `WorkspaceLogic.js` through
  `tests/qmljs.js`), added to `scripts/check.sh` as `run "workspaces"`.

## Acceptance criteria

- `WorkspaceLogic.relativeRect` is tested for:
  - a scaled monitor (`scale` 1.25);
  - a rotated monitor (`transform` 1);
  - a monitor at a non-zero origin (`x` 2560);
  - a window partly off the monitor, which clamps.
- `WorkspaceLogic.monitorTiles` is tested for:
  - the *current*, *shown*, and *normal* states across two monitors;
  - an empty workspace;
  - the urgent flag;
  - floating and fullscreen ordering;
  - exclusion of special workspaces (negative id).
- `WorkspaceLogic.tileWidth` is tested so that 5 tiles at width 696 with gap 8
  each come out 132.8 wide and always sum, with the gaps, to the view width.
- The view never reads `Globals.dashboardWidth`. A structure grep in
  `scripts/test-workspaces.sh` enforces this; it is a forbidden dependency, so a
  grep is allowed.
- Live: with one and with two monitors, each monitor shows exactly
  `MonitorService.workspacesPerMonitor` maps in one row, the window rectangles
  match the real layout, and opening, closing, or moving a window by keybind
  updates the map within about 0.2 s while the tab is shown.
- `scripts/check.sh` passes and `scripts/boot-check.sh <worktree>` reports
  loaded.
