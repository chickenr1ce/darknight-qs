# Spec: dashboard Workspaces tab (overview, one row per monitor)

Date: 2026-10-13. Design source: plan 13 (`docs/plans/13-workspaces-tab-designs.html`),
round 2 option **1a "Overview · one row per monitor"**, chosen over 1b, 1c, and the
lane options 2a–2c.

## Problem

The dashboard's Workspaces tab is the "Coming soon" placeholder in
`windows/DashboardCenter.qml` (`idDashboardPlaceholder`). The bar's
`modules/Workspaces.qml` shows only numbers, so there is no way to see what is on
a workspace, or where a window is, without switching to it. Moving a window
between workspaces needs a keybind or `hyprctl`.

## Goal

The Workspaces tab shows every enabled monitor's workspace block as a row of small
maps. Each map draws the workspace's windows at their real positions and sizes,
scaled down. From the maps you can switch workspace, focus a window, move a
window by dragging it, and act on a window through a right-click menu or a
middle-click close.

## Layout (design 1a)

- **Sections.** One section per monitor in `MonitorService.orderedMonitors`,
  limited to enabled monitors (`MonitorService.enabledMonitors`). The section
  header is the monitor name, its logical resolution in `textFaint`, a hairline
  that fills the rest of the row, and a `focused` tag (accent) on the focused
  monitor. The tag shows only when more than one monitor is enabled.
- **One row per monitor, never wrapping.** Each section is a single row of
  `MonitorService.workspacesPerMonitor` tiles, starting at
  `MonitorService.firstWorkspaceFor(name)`. The tile width is
  `(viewWidth − (n − 1) × Globals.rowSpacing) / n`, and the map height is
  `tileWidth / (monitor logical width / logical height)`. Tiles shrink to fit,
  and the row never wraps or scrolls sideways.
- **Card size is not fixed.** The view reads its own width from layout and never
  reads `Globals.dashboardWidth`. The tab keeps
  `panelMaxHeight: Globals.dashboardMaxHeight` and fits its content up to that
  height. Content taller than the cap (three monitors, or a short screen)
  scrolls vertically inside the view with the shared `components/ScrollBar.qml`,
  and the status line stays pinned below the scroll area.
- **Map (tile).** A rounded rectangle (`Globals.cardRadius`) filled with
  `Colors.backgroundSecondary` and bordered with `Colors.border`. States:
  - *current* (the focused monitor's active workspace): an accent border, drawn 2px wide;
  - *shown* (active on another monitor): a border mixed 45% toward accent;
  - *empty*: a transparent fill and a centred `+` glyph in `textFaint`. The
    prototype's dashed border is not required, because `Rectangle` has no dashed
    border and the coding standards forbid a new primitive.
- **Windows inside a map.** Each window on the workspace is a rectangle at its
  position relative to the monitor, as a fraction of the monitor's logical size,
  inset by a small gap so neighbours separate:
  - Fill `Colors.appColor(class)` at 22% over the background, with a border of the
    same colour at 55%.
  - The app icon is centred (`components/AppIcon.qml`, size 18) and hidden when
    the rectangle is too small to hold it with 2px of margin.
  - A floating window stacks above tiled windows. A fullscreen window covers the
    whole map and stacks on top.
  - The focused window (`Hyprland.activeToplevel`) gets an accent border.
  - An urgent window shows a `Colors.danger` dot in its top-right corner.
- **Caption under each map.** The workspace number (in accent when *current*),
  then the distinct app names on it, comma-joined and elided, or "Empty". An
  urgent window adds a danger dot after the names. When the tile is narrower
  than `Globals.workspaceTileCompactWidth` (new token, 100), the names hide and
  the number centres.
- **Status line.** Pinned under the sections behind a hairline. It shows the
  hint "Click a workspace to switch, a window to focus it. Drag a window onto
  another workspace to move it." While the pointer is over a window, the hint is
  replaced by `App — title`. The line keeps its height, so nothing reflows.

## Behaviour

| Input | Target | Result | Dashboard |
| --- | --- | --- | --- |
| Left click | Map background or empty map | Switch to that workspace (`hl.dsp.focus({ workspace = N })`, as `modules/Workspaces.qml` does) | Closes |
| Left click | Window | Focus it: `DashboardService.close()`, then `HyprlandFocus.focusAddress(address)` (the ADR 0018 Focus order) | Closes |
| Drag | Window onto another map | Move it silently to that workspace; the drop map highlights while hovered | Stays open |
| **Right click** | Window | Opens the **window menu** (below) at the pointer | Stays open |
| **Middle click** | Window | **Close the window gracefully**: `toplevel.wayland.close()`, the same call as the Apps tab's Kill. Nothing is force-killed, and apps may still prompt to save | Stays open; the map updates when the window goes |
| Right or middle click | Map background | Nothing | — |

### Window menu (right click)

The shared `components/ContextMenu.qml`, with the same fitting, scrolling,
submenu-flip, input-box, and keyboard rules as the Apps tab (ADR 0018 and its
2026-10-10 amendment). The header shows the app icon, the app name, and the
window title. Items, in order:

1. **Focus window** (↵): same as a left click on the window; closes the dashboard.
2. **Move to workspace ▸**: a submenu listing every enabled monitor's block under
   a label per monitor, built the same way as
   `AppService.workspaceMenuItems()`. The window's current workspace is shown
   but inert. Choosing an item moves the window silently. The dashboard stays
   open.
3. **Float** / **Tile**: the label names the state it switches to, and it toggles
   floating. Stays open.
4. **Fullscreen** / **Exit fullscreen**: toggles fullscreen. Stays open.
5. separator
6. **Copy window class**, then **Copy window title**, through
   `AppService.copyText`.
7. separator
8. **Close window**, last, in danger: the same graceful close as a middle click.

## Data

- **Source.** `Hyprland.toplevels`, `Hyprland.workspaces`, and
  `Hyprland.monitors`. Window geometry (`at`, `size`, `floating`, `fullscreen`,
  `workspace`) comes from `HyprlandToplevel.lastIpcObject`. That object updates
  only when Hyprland is asked again, so the service calls
  `Hyprland.refreshToplevels()`:
  - when the Workspaces tab becomes visible;
  - after each of its own dispatches;
  - on `Hyprland.rawEvent` names that change layout (open, close, move, float,
    fullscreen, and workspace changes), coalesced through one restartable
    `Timer` (`Globals.workspacesRefreshMs`, new token), and only while the tab
    is visible.

  A tile resize, which Hyprland reports with no event, shows on the next refresh
  trigger. That staleness is accepted.
- **Coordinates.** `at` and `size` are in global logical layout coordinates. The
  relative rectangle is `(at − monitor origin) / monitor logical size`, where the
  logical size is the pixel size divided by `scale`, with width and height
  swapped for a 90° or 270° `transform`. A rectangle is clamped to [0, 1] on
  each axis.
- **Scope.** Only workspaces in the enabled monitors' blocks are drawn. Special
  workspaces (negative ids) and named workspaces outside the blocks are
  excluded, so the scratchpad does not appear.

## Architecture

- `services/WorkspaceLogic.js` (`.pragma library`, pure). Holds the coordinate
  normalization, the tile-size math, the per-monitor tile model (workspace id,
  state, windows with relative rectangles, caption text, urgent flag), the
  window-menu items, and the move targets. It is tested under node through
  `tests/qmljs.js`.
- `services/WorkspaceService.qml` (singleton). Owns the refresh triggers, builds
  the model from the Hyprland objects through one-line `WorkspaceLogic`
  delegates, and owns the dispatch actions: `switchTo(id)`,
  `focusWindow(address)`, `moveWindow(address, id)`, `toggleFloating(address)`,
  `toggleFullscreen(address)`, and `closeWindow(address)`.
- `windows/DashboardWorkspacesView.qml`. The view, mounted in
  `DashboardCenter.qml` with `visible: DashboardService.activeTab === "workspaces"`.
  The placeholder no longer covers the `workspaces` key; it stays for
  Performance. The view's menu input box joins `PanelShell.inputOverlay` the same
  way `DashboardAppsView.menuInputBox` does. It registers
  `DevGeometry.register("dashboard.workspaces", …)`.

## Known pitfalls

- **Lua dispatch.** Hyprland ≥ 0.56 evaluates IPC as Lua, and a legacy
  `dispatch` string fails (`modules/Workspaces.qml` notes this). The exact
  `hl.dsp.*` calls for a silent move to a workspace by address, toggling
  floating, and toggling fullscreen are **not yet used anywhere in the repo**.
  Confirm each against the installed Hyprland with `hyprctl dispatch '<lua>'`
  before wiring it, and record the confirmed calls in the ADR.
- **Stale `lastIpcObject`.** Never read geometry without a refresh path; a
  binding on `Hyprland.toplevels` alone does not update `at` or `size`.
- **Focus order.** Close the dashboard before `HyprlandFocus.focusAddress`, so
  the focus path waits for `PanelGrab.closing` and restores the cursor.
- **Drag inside a layer shell.** Use the Qt Quick `DragHandler` or `Drag`
  attached property inside the dashboard window. The drag never leaves the card,
  so there is no Wayland drag-and-drop.
- **No reflow.** Hover, menu, and drag states must not change any size
  (CODING_STANDARDS §5, "No layout reflow on state change").

## Out of scope

Keyboard navigation of maps and windows, live window thumbnails (screencopy),
the scratchpad and special workspaces, renaming or creating workspaces, and
dragging a window between monitors' blocks as a monitor move (a drop on another
monitor's workspace is just a move to that workspace id, which Hyprland places
on that workspace's monitor).

## Acceptance (feature level)

- Every ticket under `issues/` is done.
- `scripts/check.sh` passes, including the new `scripts/test-workspaces.sh` gate.
- `scripts/boot-check.sh <worktree>` reports loaded.
- A live run shows the tab at the 720 default width and with three monitors
  enabled, and every behaviour in the table above works.
- ADR 0019 is written and `CONTEXT.md` is updated.
