# 02 — Left click to switch or focus, drag to move

**Status:** done
**Blocked by:** 01
**Blocking:** 03, 04

## Objective

Make the overview act on left clicks and drags: a click on a map switches to its
workspace, a click on a window focuses that window, and dragging a window onto
another map moves it there. The spec is `../spec.md` (the Behaviour table and
Known pitfalls).

## Scope

- `WorkspaceService.switchTo(id)`: calls
  `Hyprland.dispatch("hl.dsp.focus({ workspace = N })")`, the call
  `modules/Workspaces.qml` already uses, then `DashboardService.close()`.
- `WorkspaceService.focusWindow(address)`: calls `DashboardService.close()`, then
  `HyprlandFocus.focusAddress(address)`, in that order.
- `WorkspaceService.moveWindow(address, id)`: a silent move. The dashboard stays
  open, and the service calls `Hyprland.refreshToplevels()` after the dispatch.
  **First confirm the Lua call** against the installed Hyprland with
  `hyprctl dispatch '<lua>'`, and put the confirmed call in a comment above the
  dispatch.
- In the view:
  - a left click on the map background or an empty map calls `switchTo`;
  - a left click on a window calls `switchTo` with the window's workspace (changed 2026-10-14 on user request; `focusWindow` stays for the menu item);
  - a drag (`DragHandler` or `Drag` inside the window) on a window shows the
    window rectangle under the pointer, highlights the map under it with
    `Colors.accentDim` fill and an accent border, and calls `moveWindow` on drop;
  - a drop on the window's own workspace does nothing.
- Hover, press, and drag states do not change any item's size.

## Acceptance criteria

- `WorkspaceLogic.dropTarget(point, tileRects)` returns the workspace id under a
  point, or -1, and is tested in `scripts/test-workspaces.sh`. This covers a gap
  between tiles (-1) and the window's own workspace.
- Live:
  - clicking map 3 switches to workspace 3 on press and the card stays open (changed 2026-10-14 on user request);
  - clicking a window on another workspace switches to that workspace, the card stays open (changed 2026-10-14; was: focuses it and restores the cursor
    through the `HyprlandFocus` path);
  - dragging a window from workspace 1 onto map 4 moves it, the card stays open,
    and both maps redraw.
- The confirmed `hl.dsp.*` move call is in the code comment and in the hand-off
  note for ticket 04.
- `scripts/check.sh` passes and `scripts/boot-check.sh <worktree>` reports
  loaded.
