# 08: Taller Apps tab, scrollbar, smooth wheel

**Status:** done

**Blocked by:** 06

**Blocking:** none

Discovered during the first live run (user feedback, 2026-10-09): the Apps tab
shows too little, the card should grow downward instead of sitting at a fixed
size, the list has no scrollbar, and mouse-wheel scrolling feels rigid.

**What to build:** On the Apps tab the dashboard grows downward to fit the
list, up to a screen-relative ceiling, and the list fills the card. The list
gets a themed scrollbar and smooth wheel scrolling. Both come from shared
components so other panels can adopt them later.

## Acceptance criteria

- [x] The Apps list is no longer capped by `Globals.appListMaxHeight`; it takes
  its content height up to the space the card has. On the Apps tab,
  `windows/DashboardCenter.qml` passes `PanelShell` a `panelMaxHeight` of
  `Globals.dashboardAppsMaxFraction` (new token, 0.8) × the anchor screen's
  height, bounded below by `Globals.dashboardMaxHeight`. Other tabs keep
  `Globals.dashboardMaxHeight` unchanged. The card grows downward only (top
  edge and junction stay put), and the window input mask follows the real card
  height.
- [x] The card height changes only when the list's content changes (query,
  hide, unhide), never on hover, selection, inline buttons, or the context menu
  (the menu still clamps inside the card, now with more room).
- [x] New `components/ScrollBar.qml` (shared): a thin themed vertical bar built
  on QtQuick.Controls `ScrollBar`, tokens only (`Colors.border` /
  `Colors.textSubtle` / `Colors.accent` on hover or press, `Globals` width and
  radius tokens). Shown only when content overflows; draggable; clicking the
  track pages. The Apps list and the context menu's scroll area use it; list
  rows keep their right edge clear of the bar (no overlap with inline buttons).
- [x] New shared smooth-wheel helper (e.g. `components/SmoothWheel.qml`)
  attached to a `Flickable`: a mouse wheel notch (`angleDelta`) animates
  `contentY` by a token step (`Globals.wheelStep`, about three rows) over a
  token duration (`Globals.wheelMs`), accumulating rapid notches into one
  target and clamping to bounds; trackpad input (`pixelDelta`) scrolls
  1:1 with no animation. With `Globals.reducedMotion` the wheel jumps without
  animating. Keyboard `ensureVisible` scrolling still works and does not fight
  the animation.
- [x] The Apps list and the context menu use the helper. Drag-flick still
  works, and `boundsBehavior` stays `Flickable.StopAtBounds`.
- [x] `scripts/test-app-launcher.sh`: structural checks for the panel max-height
  switch on the Apps tab, the removed list cap, both components wired in the
  list and the menu, and the reduced-motion branch. Any pure math (target
  clamping, notch accumulation) lives in a `.pragma library` JS file with node
  tests.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [ ] Live: the tab fills most of the screen height with a long app list; the
  scrollbar shows, drags, and pages; one wheel notch glides about three rows;
  trackpad scrolling tracks the fingers; with reduced motion on, nothing
  animates.

## Amendments

- 2026-10-09: The live criterion stays unchecked. The wheel, trackpad, drag,
  and scrollbar interactions need a real pointer, and `scripts/boot-check.sh`
  only proves the config loads. Every headless gate passes.
- 2026-10-09: `Globals.appListMaxHeight` is removed; `Globals` gains
  `dashboardAppsMaxFraction` (0.8), `scrollbarWidth`, `scrollbarRadius`,
  `wheelStep` (144, about three rows), and `wheelMs` (160).
  `docs/user/app-launcher.md` notes the growing card and the scrollbar and
  wheel behavior.
- 2026-10-09: Blessed one deliberate `BND-2` advisory in
  `scripts/lint-review-baseline.txt`: `SmoothWheel.qml` writes its plain
  `target` state property, which has no binding to destroy.
  `scripts/lint-review.sh --update-baseline` added only that line.
- 2026-10-09: Review fixes. The `angleDelta` (mouse notch) path now composes
  `SmoothWheelLogic.wheelStep(contentY, target, running, delta, step, minY,
  maxY)` — it seeds from the in-flight target while the glide runs and from
  `contentY` otherwise, clamps to the view bounds with `originY` respected,
  and reports `moved` — then routes through one `moveTo(value)` that jumps
  under `Globals.reducedMotion` and glides otherwise. The dead `scrollTo`
  and `setTarget` entry points are gone; `stop()` remains for programmatic
  scrolls. Both wheel paths only set `event.accepted = true`
  when the clamped position actually changes, so a view at an edge or one
  that does not overflow leaves the event to its parent, and a horizontal-only
  wheel is ignored. `scripts/test-app-launcher.sh` now composes clamp plus
  wheel in node (`wheelStep`: accumulation in bounds, overshoot clamped top
  and bottom, reverse-after-overshoot, no-overflow `moved: false`,
  pinned-edge `moved: false`) and asserts `handleWheel` uses `wheelStep` and
  that the reduced-motion branch sits inside the live `moveTo` path.
  `docs/user/app-launcher.md` already claimed the clamped wheel and the
  reduced-motion jump, so it needed no change.

- 2026-10-09: Review fixes. The two root-level `SmoothWheel` mounts whose
  targets were not parent-or-sibling — `windows/DashboardAppsView.qml`'s list
  and `components/ContextMenu.qml`'s main list — now sit in a plain `Item` slot
  beside their `Flickable`, carrying the layout/size constraints, so
  `anchors.fill` reaches a sibling and the overlay is no longer 0×0. Header
  rows assign `(idAppRow.info.query || "")` to `AppIcon.name`, dropping the
  `Unable to assign [undefined] to QString` boot warnings. `SmoothWheel`'s
  `WheelHandler` became a full-size `MouseArea` with
  `acceptedButtons: Qt.NoButton`; it sets `wheel.accepted = false` and forwards
  to `handleWheel`, which accepts only when the clamped position moves, so the
  wheel is conditionally forwarded to the `Flickable` below — a blocking
  `WheelHandler` cannot do that. `scripts/boot-check.sh` and
  `scripts/check-live-log.sh` now fail on "Cannot anchor to an item that
  isn.t a parent or sibling" and "Unable to assign [undefined] to QString";
  `scripts/test-boot-check.sh` exercises both signatures, and
  `scripts/test-app-launcher.sh` asserts the MouseArea wheel path and that no
  `WheelHandler` remains.
