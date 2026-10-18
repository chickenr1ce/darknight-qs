# ADR 0021: bar modules are ordered by one global left/right layout

Date: 2026-10-18. Feature: bar-reorder (tickets 01–03).

## Context

The bar's module order was hardcoded in `shell.qml`: a `RowLayout` of Clock,
Workspaces, Tray, the `idSpacer` filler, then Cava, Media, Audio, Notifications,
and PowerMenu. Changing the order meant editing QML and reloading.
`services/BarVisibilityService.qml` could hide a module but had no notion of
order, so a hidden module kept no slot to come back to.

Omarchy's Quickshell bar keeps `left` / `center` / `right` arrays of widget ids
in `~/.config/omarchy/shell.json` and lets widgets be dragged within and across
the sections (`omarchy bar move`). That layout, not a per-widget x, is the
precedent this feature follows.

The center is not free space. `modules/ActiveWindow.qml` is the dashboard
trigger, and the dashboard junction is shaped around its edges (ADR 0005,
ADR 0008), so it has to stay under the card.

## Decision

The order is one global left/right layout, edited by holding and dragging a
module.

- **One global order, two sections, a fixed center.** `left` packs from the
  slab's left edge and `right` from its right edge; there is no center section.
  `modules/ActiveWindow.qml` stays fixed where it is and is neither draggable
  nor a drop target. The order is global: a drag on any bar edits it, and every
  bar applies it, each limited to the modules it shows (the secondary monitor's
  bar carries Clock and Workspaces; the rest stay gated by
  `Globals.onPrimaryMonitor`). A hidden module keeps its slot and takes no
  space, so turning it back on returns it to its place.
- **The keys are the visibility registry.** The eight keys of
  `BarVisibilityService.modules` (`clock`, `workspaces`, `tray`, `cava`,
  `media`, `audio`, `notifications`, `power`) are the one module registry;
  `BarLayoutService.keys` reads it. Default order is
  `left: [clock, workspaces, tray]`,
  `right: [cava, media, audio, notifications, power]`, the order shipped before
  this feature.
- **Modules are created once and positioned, not laid out.** `shell.qml` drops
  the `RowLayout` and the `idSpacer`; each module is created once inside a new
  `components/BarSlot.qml`, whose `x` comes from
  `BarLayoutLogic.positions(order, widths, visible, spacing, width)`. A
  `Behavior on x` (`Globals.barReorderMs`, 0 under `Globals.reducedMotion`)
  animates the move (disabled on the dragged slot, which tracks the pointer).
  This is why it is not a `Repeater` or a `RowLayout`: a
  model reorder recreates delegates, a move across two Repeaters always does,
  and positioners bypass `Behavior` (CODING_STANDARDS §4). It also means
  `PanelTrigger` registration, Cava, Tray, and Media state survive a reorder.
  The slab's `leftClusterEdge` / `rightClusterEdge` hairlines read `leftEnd` /
  `rightStart` from the positioner instead of the spacer.
- **Hold-to-drag, no edit mode.** `components/BarSlot.qml` holds a
  `DragHandler` (`target: null`) on the slot itself, behind the module. The
  module's `MouseArea` takes the press, and the slot's `DragHandler` still
  gets a passive grab, whose `grabChanged` starts `idHoldTimer`
  (`Globals.barDragHoldMs`, 300 ms). Holding lifts the module (`z`, `scale:
  Globals.barDragLiftScale` 1.05, a neutral hairline outline,
  `Qt.ClosedHandCursor`)
  and arms the drag; a `DragHandler` only reports the pointer position to
  `BarLayoutService` while armed, so moving before the hold elapses, and a
  right or middle click or the wheel, behave exactly as before. The handlers
  must not sit in an overlay above the module: a handler there takes the
  press, and the module's `MouseArea` (and Workspaces' and Tray's per-item
  ones) never sees it, so no click lands (found live 2026-10-18;
  `tests/bar-slot-handlers.qml` pins the working shape). A `TapHandler` or
  `PointHandler` on the slot never fires either, because the child
  `MouseArea` holds the exclusive grab; the `DragHandler`'s passive grab is the
  one signal that survives. Tooltips and hover tints keep
  working (Audio's tooltip hides while `BarLayoutService.dragging`).
- **Drop preview.** While a drag runs, `components/BarDropPreview.qml` marks
  the landing slot on the dragging bar: a Geist-style neutral placeholder (a
  faint fill and a `Globals.hairlineHeight` border mixed from the theme's text
  into its background, inset like the hover pill) that glides between slots.
  In the cancel zone (`BarLayoutService.wouldCancel`) the preview order is the
  committed order, so the placeholder and the other modules return to the
  original slot and show that a release cancels.
- **Drop, cancel, and no stray click.** The other modules animate to the slot
  under the pointer while a drag runs; a release commits the preview through
  `BarLayoutService.move(key, section, index)` and a drop at the original slot
  writes nothing. A drop that changes the order closes an open
  floating panel (`Panels.closeAll()`) and the tray menu, at release rather
  than at drag start: Hyprland sends the bar a button release within a few
  milliseconds of any panel surface unmapping, so closing one while the
  button is held ends the hold (found live 2026-10-18). For the same reason a
  press on a module other than the tray defers the bar's tray-menu dismiss to
  the release (`idBarModules.defersDismissAt` in `shell.qml`, `BarSlot`'s
  release branch). A press that became a drag fires no
  click on the module below. Cancel is a release more than a bar height below
  the bar (`BarLayoutLogic.shouldCancelRelease`), and a drag whose module
  hides or unloads mid-drag also cancels; both restore the order from before
  the drag and write nothing. Escape is not wired: a layer surface takes no
  keyboard focus, so there is no key to bind it to.
- **Parsing lives in `services/StateParsers.js`.** `parseBarLayout(jsonText,
  keys, defaults)` returns a `{left, right}` holding every key in `keys`
  exactly once: unknown keys and repeats drop (first occurrence wins), a
  missing key is re-inserted at its default section and index (clamped), and
  malformed JSON or a non-object returns the defaults. A module added in a
  later release therefore appears in its default place.
- **A `bar-layout` state file.** `services/BarLayoutService.qml` composes
  `StateFile { name: "bar-layout"; createDir: true }` and writes the payload
  only on a drop that changed the order or on reset. `bar-visibility` is
  unchanged and stays the visibility owner.
- **A `bar` IPC target.** `IpcHandler { target: "bar" }` on the service:
  `order(): string` (the JSON payload), `move(key, section, index): string`
  (`"ok"` or `"error: ..."`), and `reset(): void`. It is the headless test seam
  and the scripting equivalent of `omarchy bar move`.
- **Reset in Settings → Layout.** `windows/LayoutSettingsView.qml` gains a
  "Reset bar order" row (`components/PillButton.qml`) that calls
  `BarLayoutService.reset()` and is disabled while
  `BarLayoutService.isDefaultOrder` (`BarLayoutLogic.sameOrder(order,
  defaults)`) is true. The label joins the `layout` entry's `options` in
  `SettingsService.sectionRegistry` and the view's `matches()`, so search finds
  it.

## Alternatives considered

- **An edit mode.** A toggle that reveals handles, the way a phone home screen
  works. Rejected: it makes the common gesture two steps (enter the mode, then
  drag) and needs a visible affordance and an exit; a hold is discoverable the
  same way a long press is elsewhere, and the module itself is the handle.
- **Per-monitor orders.** A separate `left`/`right` per screen. Rejected: the
  order is a personal preference, not a property of the monitor, and the
  secondary bar shows a subset of the same modules; one order keeps dragging on
  either bar meaningful and the state file small. Per-monitor ordering stays
  out of scope.
- **`Repeater` plus `ListModel.move`.** A model driven by the order list.
  Rejected: a model reorder destroys and recreates delegates, and a move
  across two Repeaters (one per section) always does. That resets
  `PanelTrigger` registrations and Cava, Tray, and Media state on every drop.
  The manual `BarSlot` positioner keeps one instance per module for the life of
  the shell.
- **A plain drag threshold without the hold.** `DragHandler` arm on its own
  threshold. Rejected: `DragHandler` steals the exclusive grab from the
  module's `MouseArea` once the threshold is crossed, so a twitchy click on a
  workspace would half-drag instead of switching workspace. Gating the drag on
  the hold timer and making an unheld steal a no-op keeps a quick click
  intact.
- **A drop into the center.** Rejected: the center is the dashboard trigger,
  and the junction depends on its edges (ADR 0005, ADR 0008); nothing drops
  into it.

## Consequences

- The bar order is a file (`bar-layout` under `$XDG_STATE_HOME/quickshell/`),
  restored on the next start and applied to every monitor; drag edits it and
  Settings → Layout resets it.
- Modules are never recreated on a reorder, so a drag leaves panel anchors,
  the cava process, tray state, and media state untouched.
- The center, per-monitor orders, dragging a module off the bar to hide it, and
  reordering items inside a module (tray icons, workspaces) stay out of scope.
- Keyboard cancel is not offered: the bar takes no keyboard focus. The cancel
  gesture is a release well below the bar.
- The `bar` target is in `docs/user/ipc.md`; the glossary entry is "Bar layout"
  in `CONTEXT.md`.
