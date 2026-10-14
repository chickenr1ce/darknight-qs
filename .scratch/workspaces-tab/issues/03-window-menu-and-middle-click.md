# 03 — Right-click window menu and middle-click close

**Status:** done
**Blocked by:** 02
**Blocking:** 04

## Objective

Define the right and middle mouse buttons on a window inside a map. A right
click opens the window menu, and a middle click closes the window gracefully.
On the map background, both buttons do nothing. The spec is `../spec.md`
("Window menu (right click)" and the Behaviour table).

## Scope

- `WorkspaceLogic.windowMenuItems(window, moveTargets)` returns the item list in
  the order below, using the item shape `components/ContextMenu.qml` already
  takes (`kind`, `label`, `submenu`, danger and inert flags, the same shape
  `AppLogic.menuItems` produces):
  1. Focus window (↵)
  2. Move to workspace ▸, with a monitor label per block and the current
     workspace inert
  3. Float or Tile
  4. Fullscreen or Exit fullscreen
  5. separator
  6. Copy window class, then Copy window title
  7. separator
  8. Close window (danger)
- `WorkspaceLogic.moveTargets(monitors, blocks, currentId)` builds the submenu,
  the same way `AppService.workspaceMenuItems()` builds its own.
- `WorkspaceService.toggleFloating(address)`,
  `WorkspaceService.toggleFullscreen(address)`, and
  `WorkspaceService.closeWindow(address)`. `closeWindow` calls
  `toplevel.wayland.close()`, with no force-kill.
  **Confirm the Lua calls for floating and fullscreen** with
  `hyprctl dispatch '<lua>'` before wiring them.
  Each action refreshes the toplevels afterwards.
- The view gets a `ContextMenu` whose header is the app icon, the app name, and
  the window title, with `boundsHeight` set to the room down to the dashboard
  window's bottom (the ADR 0018 amendment). It exposes `menuInputBox`, which
  `DashboardCenter.inputOverlay` uses when the Workspaces tab is active.
  - `acceptedButtons` on the window delegate is
    `Qt.LeftButton | Qt.MiddleButton | Qt.RightButton`.
  - A right click opens the menu at the pointer.
  - A middle click calls `closeWindow`.
  - The map background's mouse area does not accept the middle or right button.
- The dashboard stays open for every action except Focus window.

## Acceptance criteria

- `windowMenuItems` is tested for: the item order; the Float/Tile and
  Fullscreen/Exit fullscreen labels following window state; Close window last
  and danger; the current workspace inert in the move submenu; and three
  monitors grouped under three labels.
- Live:
  - a right click on a window opens the menu inside the card, and it flips and
    scrolls like the Apps tab menu;
  - Move to workspace moves the window with the card left open;
  - Float/Tile and Fullscreen toggle;
  - both Copy items reach the clipboard (`wl-paste`);
  - a middle click on a window closes it gracefully (an editor with unsaved
    changes still prompts) and the map redraws;
  - right and middle clicks on the map background do nothing.
- `scripts/check.sh` passes and `scripts/boot-check.sh <worktree>` reports
  loaded.
