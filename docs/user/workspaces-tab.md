# Workspaces tab

The dashboard's Workspaces tab shows every enabled monitor as a row of workspace
maps. Each map draws the windows on that workspace at their real positions and
sizes, scaled down. From a map you can switch workspace, focus a window from its menu, drag a
window to another workspace, or act on a window through its menu. Open it from
the dashboard's tab row.

## The maps

- One section per enabled monitor. The header shows the monitor name, its
  logical resolution, and a `focused` tag while more than one monitor is
  enabled.
- The section is a single row of maps, one per workspace in that monitor's
  block. The row shrinks to fit the card and never wraps or scrolls sideways.
- The map for the focused monitor's active workspace has an accent border. A map
  that is active on another monitor has a dimmer accent border. An empty map is
  transparent with a `+` glyph.
- Windows sit where they are on the screen. Tiled windows draw first, floating
  windows stack above them, and a fullscreen window covers the whole map with no
  inset. The focused window has an accent border, and an urgent window a red dot
  in its corner; a map with an urgent window also gets a red dot after its
  caption names.
- Under each map is the workspace number and the app names on it, or `Empty`. The
  names come from the window's desktop entry, falling back to its class when
  there is no entry. On a narrow map the names give way to the number alone.
- The status line at the bottom shows `Click a workspace or a window to switch.
  Drag a window onto another workspace to move it.`, or `App — title`
  while the pointer is over a window.

## Mouse

| Input | Where | What happens | Dashboard |
| --- | --- | --- | --- |
| Left click | A map | Switch to that workspace, as soon as the button goes down | Stays open |
| Left click | A window | Switch to the window's workspace, without focusing the window | Stays open |
| Drag | A window onto another map | Move the window to that workspace, without following it | Stays open |
| Right click | A window | Open the window menu | Stays open |
| Middle click | A window | Close the window gracefully | Stays open |
| Right or middle click | A map background | Nothing | Stays open |

A drop on the window's own workspace, or on the gaps between maps, does nothing.
While you drag, a map highlights only when it would take the window. A drag the
pointer never finishes, from a tab switch or a closed dashboard, moves nothing.

## Window menu

A right click on a window opens its menu at the pointer. The header shows the
app icon, the app name (the desktop entry's name, or the window class when there
is no entry), and the window title. Items, in order:

1. Focus window (↵): focuses the window, switching to its workspace, and closes
   the dashboard.
2. Move to workspace ▸: a label per enabled monitor, then one item per workspace
   in that monitor's block. The window's current workspace is shown but cannot be
   picked. When there is no other workspace to move to, this item is left out
   rather than shown empty.
3. Float or Tile: the label names the state it switches to.
4. Fullscreen or Exit fullscreen: toggles fullscreen.
5. A separator.
6. Copy window class, then Copy window title.
7. A separator.
8. Close window, last and styled in red.

Every item except Focus window leaves the dashboard open. The menu keeps the
card's width but may hang below the card down to the window's bottom edge, so it
stays readable on a short dashboard. It flips and scrolls like the Apps tab
menu, and takes the same keys as that menu: ↑/↓ move, → opens the submenu, ←
leaves a submenu and on the top level closes the menu, Enter runs the highlighted
item, and Escape leaves a submenu or, on the top level, closes the menu. Because
this tab has no search field, typing a printable character only closes the menu.

## How the maps stay current

The tab reads Hyprland's window list, so it updates while it is open. It
refreshes when you open the tab, after each action you take from a map, and on
the Hyprland layout events: a window opens, closes, moves, floats, fullscreens,
or changes workspace or title, a window becomes focused or urgent, a workspace is
activated, moved between monitors, or focused, and the focused monitor changes.
Resizing a window by its edge is not one of those events, so a resize shows the
next time the maps refresh.

## Known limits

- No keyboard navigation of the maps or the windows.
- No live window thumbnails: a map is an outline, not a picture.
- The scratchpad and other special workspaces are not shown, and neither are
  named workspaces outside the monitor blocks.
- Close is graceful. An app with unsaved changes may still prompt, and there is
  no force-kill.
- There is no renaming or creating a workspace here. The count and the per-monitor
  split come from Settings → Monitors.
