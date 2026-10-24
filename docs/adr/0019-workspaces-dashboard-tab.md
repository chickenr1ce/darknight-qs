# ADR 0019: the Workspaces tab is a per-monitor overview

Date: 2026-10-14. Feature: workspaces-tab (plan 13).

## Context

The dashboard's Workspaces tab was the "Coming soon" placeholder in
`windows/DashboardCenter.qml`. The bar's `modules/Workspaces.qml` shows workspace
numbers only, so nothing on screen says what sits on a workspace or where a
window is without switching to it. Moving a window between workspaces needed a
keybind or `hyprctl`.

The dashboard card has no fixed size (ADR 0008). A tab cannot lay out against
`Globals.dashboardWidth`: with three enabled monitors the content is taller than
the card's cap, and a narrow card has less room for the same tiles.

Hyprland reports window geometry in `HyprlandToplevel.lastIpcObject`, a snapshot
that moves only when Hyprland is asked again. In it `at` and `size` are
two-element arrays (`[x, y]`, `[w, h]`) in global logical coordinates, not
`{x, y}` objects; a live run caught the first implementation reading them as
objects and drawing every window 0×0 while all the headless tests passed, so the
unit fixtures now use the array shape. Hyprland 0.56 and later evaluate IPC as
Lua, so a legacy `dispatch` string fails, and the calls for moving, floating,
and fullscreening a window by address were not used anywhere in the repo before
this feature.

## Decision

The Workspaces tab is the overview from design 1a: one non-wrapping row of
workspace maps per enabled monitor, built from `windows/DashboardWorkspacesView.qml`,
`services/WorkspaceService.qml`, and the pure `services/WorkspaceLogic.js`.

- **One row per monitor, never wrapping.** A section per monitor in
  `MonitorService.enabledMonitors`, ordered by `MonitorService.orderedMonitors`.
  The header is the monitor name, its logical resolution, a hairline, and a
  `focused` tag while more than one monitor is enabled. The section is a single
  row of `MonitorService.workspacesPerMonitor` tiles starting at
  `MonitorService.firstWorkspaceFor(name)`.
- **The card size follows the view.** The tile width is
  `(viewWidth − (n − 1) × Globals.rowSpacing) / n`, read from the view's own
  width and never from `Globals.dashboardWidth`. The map height comes from the
  monitor's logical aspect. Tiles shrink to fit, and the row never wraps or
  scrolls sideways. Content taller than `Globals.dashboardMaxHeight` scrolls
  vertically inside the view, and the status line stays pinned under the scroll
  area.
- **Each map draws the workspace.** A rounded rectangle with current, shown, and
  empty states. Windows are rectangles at their real position and size as a
  fraction of the monitor's logical size, inset by `Globals.workspaceWindowGap`
  except a fullscreen window, which fills the map with no gap. Tiled windows
  draw first, floating windows stack above them, and a fullscreen window covers
  the map. The focused window carries an accent border and an urgent window a
  danger dot; a tile that holds an urgent window also adds a danger dot after
  the caption names. The caption is the workspace number then the distinct app
  names, or `Empty`, and the names give way to the number alone below
  `Globals.workspaceTileCompactWidth`.
- **Labels read the desktop entry.** The caption names, the status line
  (`App — title`), and the menu header show the desktop entry's app name from
  `AppService.appNameForClass` (a `DesktopEntries.heuristicLookup` on the window
  class), falling back to the class when no entry matches. Window icons resolve
  the same way through `AppService.iconForClass`, with the letter tile as
  fallback. `Copy window class` still copies the class itself.
- **Mouse map.** Left press on a map switches to that workspace
  (`hl.dsp.focus({ workspace = N })`, built by
  `services/HyprlandDispatchLogic.js` for `modules/Workspaces.qml`) and
  the dashboard stays open, so the `current` border shows the switch land. It
  fires on press, not release: the background has no drag to wait for. Left click
  on a window switches to its workspace the same way, without focusing the
  window, and fires on release because a press may start a drag. The menu's
  Focus window item is the way to focus one: `DashboardService.close()` then
  `HyprlandFocus.focusAddress(address)`, the ADR 0018 focus order. Dragging a window onto another map moves it silently and the
  dashboard stays open. Right and middle clicks on the map background do nothing.
- **Right click is the window menu.** The shared `components/ContextMenu.qml`
  with the same fitting, scrolling, submenu-flip, input-box, and
  arrow/Enter/Escape rules as the Apps tab (ADR 0018 and its 2026-10-10
  amendment); this tab has no input box, so a typed character only closes the
  menu. Items: Focus window (↵), Move to workspace ▸, Float or Tile, Fullscreen
  or Exit fullscreen, a separator, Copy window class, Copy window title, a
  separator, and Close window in danger. Move to workspace is a submenu with one
  label per enabled monitor, and the window's current workspace is shown but
  inert. When the window has no other workspace to move to — a single-workspace
  setup, or a window alone on its only workspace — the item is omitted entirely
  rather than offered empty. Every item except Focus window keeps the dashboard
  open.
- **Middle click closes gracefully.** `toplevel.wayland.close()`, the same call
  as the Apps tab Kill. Nothing is force-killed, an app may still prompt to save,
  the dashboard stays open, and the map redraws when the window goes.
- **Refresh on demand, with accepted staleness.** `WorkspaceService` calls
  `Hyprland.refreshToplevels()`, `refreshMonitors()`, and `refreshWorkspaces()`
  when the tab becomes visible, after each of its own window dispatches (a
  workspace switch needs none: its `workspacev2` event moves the `current`
  border), and on the
  `Hyprland.rawEvent` names that change layout, coalesced by one restartable
  `Timer` (`Globals.workspacesRefreshMs`, 80 ms) and only while the tab is
  visible. A tile resize, which Hyprland reports with no event, shows on the next
  trigger. That staleness is accepted.
- **A drag freezes the rendered model.** While a drag is active the view keeps
  its own copy of the model, so a rebuild cannot destroy the pressed delegate
  mid-gesture. A cancelled drag, from a tab switch or a dashboard close, never
  moves the window.
- **Fullscreen is a mode.** `lastIpcObject.fullscreen` is 0 none, 1 maximized,
  2 fullscreen, 3 both. The overview treats mode ≥ 2 as fullscreen, so it covers
  the map and stacks on top, and draws a maximized window at its real work-area
  geometry.
- **The scratchpad is excluded.** Only workspaces in the enabled monitors'
  blocks are drawn. Special workspaces (negative ids) and named workspaces
  outside the blocks do not appear.

The confirmed calls, on Hyprland 0.56.2, against an unfocused window:

```lua
hl.dsp.focus({ workspace = N })
hl.dsp.window.move({ workspace = N, follow = false, window = "address:0x<hex>" })
hl.dsp.window.float({ action = "toggle", window = "address:0x<hex>" })
hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", window = "address:0x<hex>" })
```

The silent move leaves the active workspace and focus alone, and so does the
floating toggle; toggling fullscreen leaves the active workspace alone but moves
focus to the fullscreened window.

## Alternatives considered

- **Overview · current workspace large (1b).** The current workspace spans two
  columns of a dense grid. Rejected: it gives one map more room at the cost of
  the uniform row, and on a narrow card the large map crowds the rest.
- **Overview · occupied only (1c).** Empty workspaces become chips in the monitor
  header and the occupied maps take one row when they fit. Rejected: the chip row
  changes the tile set as windows open, and an empty workspace, the place a drag
  lands, loses its drop area.
- **Lanes · empty columns full width (2a), only occupied columns (2b), and
  workspace rows (2c).** A lane per monitor with a column or row per workspace.
  Rejected: a column holds window chips, not positions, so the lane designs show
  what is on a workspace but not where. They also wrap at narrow widths, and 2b's
  header chips reflow as windows move.
- **Round 1's other three.** A rail of workspaces with a detail pane, a flat
  searchable window list grouped by workspace, app, or monitor, and an app ×
  workspace matrix. Round 2 dropped each: the rail and the list lose the spatial
  view and repeat the Apps tab's list idea, and the matrix is a window-centric
  table that reads worse than maps for "what is on workspace 4".
- **A Scratchpad cell (round 1).** The first round drew the scratchpad beside the
  focused monitor's tiles. Dropped: special workspaces are not in the monitor
  blocks and do not belong in an overview of the blocks.
- **A legacy `dispatch` string.** Rejected in favour of the Lua `hl.dsp.*` API,
  the path the rest of the shell uses under the quattro config.
- **Wayland drag and drop.** The drag never leaves the card, so Qt Quick input
  handles it. A Wayland drag would buy nothing and needs a second surface.

## Consequences

- The tab is read-through: it shows Hyprland's state and dispatches through
  Hyprland, with no state file of its own.
- Actions are the ones the bar and keybinds already use, so a window moved from a
  map lands wherever Hyprland places that workspace's monitor.
- The card's height changes with the monitor count and the view scrolls past the
  cap, so the status line and the map rows keep their layout while the content
  scrolls.
- Keyboard navigation of maps and windows, live window thumbnails, and renaming
  or creating workspaces are out of scope. The scratchpad stays out.
- The user page is `docs/user/workspaces-tab.md`.
