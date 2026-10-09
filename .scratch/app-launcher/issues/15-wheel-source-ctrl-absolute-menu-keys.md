# 15: Wheel source detection, Ctrl+1…0, menu width, Right opens the menu

**Status:** done

**Blocked by:** 14

**Blocking:** none

User feedback from the fourth live run (2026-10-09), with a screenshot.

## 1. The mouse wheel is far too slow (bug)

A full spin of the wheel scrolls about two rows.

**Evidence:** the orchestrator added a temporary `console.warn` to
`SmoothWheel.handleWheel` and injected real wheel input with
`ydotool mousemove -w -x 0 -y N`. One notch arrived as `angleDelta.y = 120`,
`pixelDelta.y = 15`, and five coalesced notches as `angleDelta.y = 600`,
`pixelDelta.y = 15`. Hyprland and Qt Wayland send a `pixelDelta` with
ordinary mouse-wheel events too. `SmoothWheel` takes the 1:1 pixel path
whenever `pixelDelta` is non-zero, so every notch moves 15 px and coalesced
notches are lost.

**Fix:** pick the path by the event's scroll phase, not by whether
`pixelDelta` is non-zero.

- A discrete wheel arrives with `event.phase === Qt.NoScrollPhase`; use the
  stepped `angleDelta` path, scaled by `|angleDelta|/120` (ticket 12).
- A continuous source (a touchpad or momentum scroll) arrives with
  `ScrollBegin`/`ScrollUpdate`; use the 1:1 `pixelDelta` path.
- `event.device.type` cannot make this call: Qt Wayland registers only its
  gesture device and labels every seat pointer `PointerDevice.TouchPad`, so
  the type is `TouchPad` for a real mouse wheel too (verified live
  2026-10-09 with `wev` and a temporary probe).
- Keep the decision pure and node-tested in `SmoothWheelLogic`, e.g.
  `wheelMode(angleDelta, pixelDelta, isContinuous)`. Cases:
  - (120, 15, false) → angle;
  - (600, 15, false) → angle, five steps;
  - (0, 12, true) → pixel;
  - (8, 3, true) → pixel;
  - (0, 15, false) → pixel;
  - (0, 0, x) → none.

## 2. Ctrl+1…0 targets absolute workspaces

The user has 10 workspaces (5 per monitor × 2) and expects Ctrl+N to reach
any of them.

- Ctrl+1…9 opens on absolute workspace 1–9, and Ctrl+0 on workspace 10,
  when that workspace exists. It exists when it is at most
  `workspacesPerMonitor × number of enabled monitors` (at least the anchor
  block when the monitor list is not loaded yet). Out-of-range keys do
  nothing.
- This replaces the per-monitor slot mapping from ticket 05.
  `AppLogic.workspaceFor` becomes an absolute-range helper, or a new pure
  helper; node tests replace the slot tests.
- In the submenu, every workspace item gets its hint: `ctrl N` for 1–9 and
  `ctrl 0` for 10, on every monitor's group, not just the anchor's.
- The footer key cap reads `ctrl 1–9, 0` when 10 workspaces exist, and
  `ctrl 1–N` otherwise (N = the total, capped at 9).
- Update `docs/user/app-launcher.md`, the spec's keyboard section
  (`.scratch/app-launcher/spec.md`) and ADR 0018 where they state the
  per-monitor mapping. Keep the wording short: "Ctrl+N opens on workspace N;
  Ctrl+0 is workspace 10."

## 3. Context menu text is cut off

In the screenshot, "Open, keep dashboard open" renders as "Open, keep
dashbo…", because its `middle` hint eats the fixed `Globals.menuWidth`
(236).

- The menu's width fits its content: the widest item's glyph + text + hint
  + paddings, at least `Globals.menuWidth` and at most a new
  `Globals.menuMaxWidth` token (about 340). It also stays within the card,
  using the existing clamp and flip.
- Submenus fit their own content the same way.
- Measure with the items' implicit widths (e.g. a `TextMetrics`, or the
  widest delegate's `implicitWidth`) without a binding loop.

## 4. Right arrow opens the context menu

Right arrow replaces Shift+F10 for opening the context menu from the list.

- In the Apps view, Right opens the selected row's menu when the search
  field's cursor is at the end of the text (always true when it is empty).
  Otherwise it keeps moving the cursor.
- The Menu key still opens the menu. Shift+F10 is removed.
- Inside the menu, Left on the top level closes the menu and returns focus to
  the search field. Left inside a submenu still returns to the parent menu.
  Right on an item with a submenu still opens it.
- The footer hint becomes `→ More` (use the right-arrow character in the
  key cap).
- `docs/user/app-launcher.md` and the spec's keyboard section reflect this.

## Acceptance criteria

- [x] `wheelMode` is pure and node-tested; `SmoothWheel` uses the scroll
  phase and steps on angleDelta for a discrete wheel.
- [x] Ctrl+1…9 and Ctrl+0 target absolute workspaces within the available
  range, with node tests; submenu hints on every group; footer text updated.
- [x] The menu and submenu widths fit their content within the min/max
  tokens; "Open, keep dashboard open" is not elided.
- [x] Right opens the menu (cursor at the end), the Menu key still works,
  Shift+F10 is gone, Left on the top level closes the menu; the footer shows
  `→ More`.
- [x] `scripts/test-app-launcher.sh` structural and node checks for all four,
  mutation-verified.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [x] Live (orchestrator, via `ydotool` wheel injection and screenshots):
  one injected notch moves ~237 px (~four rows); the menu text is not cut
  off; the workspace submenu shows `ctrl 0` on workspace 10.

## Amendments (2026-10-09)

### 1. Wheel source detection

- `SmoothWheelLogic.wheelMode(angleDelta, pixelDelta, isContinuous)` returns
  `"angle" | "pixel" | "none"`: a continuous source (touchpad or momentum)
  takes pixels, a discrete wheel takes angleDelta whenever it is non-zero and
  only falls back to pixels when the angle is zero. All six ticket cases are
  node-tested, plus a continuous source with an angleDelta but no pixelDelta.
- `SmoothWheel.isContinuousScroll(event)` returns
  `event.phase !== Qt.NoScrollPhase`; `handleWheel` picks the path through
  `wheelMode` before touching either delta.
- **Correction (2026-10-09, live).** The first implementation keyed on
  `event.device.type === PointerDevice.TouchPad`. That cannot work on Qt
  Wayland: `QWaylandWindow::handleMouse` picks the device through
  `QPointingDevice::primaryPointingDevice(seatName)`, and Qt Wayland registers
  only its gesture device (`"touchpad"`, type `TouchPad`), so every pointer
  event, a real mouse wheel included, carries `TouchPad`. A temporary probe on
  the live shell logged the real mouse wheel as `angle=-120 pixel=-15 phase=0
  dev=4 name=touchpad`, which the device check routed to the pixel path. The
  scroll phase is the usable signal: the real wheel reports `NoScrollPhase`, a
  continuous source reports `ScrollBegin`/`ScrollUpdate`. The offscreen
  `tests/app-launcher-wheel.qml` now guards `Qt.NoScrollPhase` and that a
  synthetic mouse wheel reports it, not the pointer device.

### 2. Absolute Ctrl workspaces

- `AppLogic.workspaceFor(n, totalWorkspaces)` returns the absolute workspace
  (`0` means 10) when it is within `1..totalWorkspaces`, else `-1`; the old
  slot mapping is gone. `AppService.totalWorkspaces()` is
  `workspacesPerMonitor × enabled monitors`, falling back to one monitor's
  block while the list is not loaded.
- The Ctrl branch maps `event.key - Qt.Key_0` and launches the resolved
  absolute workspace; the old `slot >= 1` floor that discarded Ctrl+0 is gone,
  so Ctrl+0 targets workspace 10.
- `workspaceMenu` now hints by absolute workspace on every monitor's group
  (`ctrl N` for 1–9, `ctrl 0` for 10), not just the anchor's.
- The footer cap is pure: `AppLogic.workspaceKeys(total)` reads
  `ctrl 1–9, 0` at ten or more and `ctrl 1–N` otherwise (N capped at 9);
  `AppService.workspaceKeys()` feeds the footer `KeyHint`.
- Node tests replace the slot tests and cover the hint shift (including the
  anchor-second order and the hidden `ctrl 0`).

### 3. Menu width fits its content

- New `Globals.menuMaxWidth` (340). `ContextMenu` measures the widest main
  item and the widest submenu item with `FontMetrics` at the delegates' own
  fonts (`uiFontFamily`/`uiBodySize`, `fontFamily`/`uiCaptionSize`, label
  `Font.Medium` + `uiLetterSpacing`, icon `chevronRight`) and clamps each
  between `menuWidth` and `menuMaxWidth`.
- Each item's width is its glyph column + label + gap + `max(hint, chevron)`
  + paddings + scrollbar, plus the `2 × menuMargin` the item column is inset
  by; the submenu is measured and flipped with its own width. Measurement is
  imperative (`measureWidths()` on `items` change and completion), so no
  `TextMetrics` binding loop is possible.
- Verified the measured width of "Open, keep dashboard" (+ `middle`) is
  ~241 px, above the old fixed 236, so it is no longer elided.

### 4. Right opens, Left closes

- `DashboardAppsView.handleKey` gains a Right branch that opens the selected
  row's menu only while `idAppsSearch.cursorPosition === idAppsSearch.length`
  (always true when empty); otherwise the event is left for `TextInput` to move
  the cursor. The Menu key still opens it and Shift+F10 is gone.
- `ContextMenu.handleKey` Left now closes the menu on the top level (routing
  through `closeMenu()` → `onMenuClosed` → search focus) and still returns to
  the parent from a submenu.
- The footer's third `KeyHint` reads `→` More.

### Verification

- `scripts/test-app-launcher.sh` `app-launcher: all ok`; new structural gates
  and node cases. All new gates mutation-verified (mutate → gate FAIL →
  restore): the pixel-first `wheelMode`, a dropped `Qt.NoScrollPhase`
  compare, an off-by-one workspace range, a dropped `ctrl 0` hint, a dropped
  menu-width inset, unmeasured main/submenu widths, a Right branch without the
  cursor gate, a Left top-level that does not close, and a dropped
  `AppService.workspaceKeys` delegation each fail.
- `scripts/check.sh` prints `check: all gates ok`;
  `scripts/boot-check.sh <worktree>` reports `loaded` with no new warnings.
- Live (orchestrator, 2026-10-09): one `ydotool` notch moved the browse list
  ~237 px (~four rows), the context menu rendered "Open, keep dashboard"
  unelided, and the workspace submenu showed `ctrl 0` on workspace 10. A real
  mouse wheel was captured with `wev` (`axis_source=wheel`, `value120=120`)
  and a temporary probe (`phase=0`), matching the ydotool path.
