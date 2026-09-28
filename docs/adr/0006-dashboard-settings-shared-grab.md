# ADR 0006: dashboard and settings share one focus grab

Date: 2026-09-25. Feature: dashboard-settings (`#03`).
Superseded by ADR 0007 for the settings window (2026-09-26); retained as the
record of the shared-grab arrangement that `#03` first shipped.

## Context

Every floating surface derives `PanelShell`, which owns a `HyprlandFocusGrab`
over its own window. `#01` discovered that two of them cannot coexist:
whichever surface opens second clears the first through the grab's outside
path, with no pointer involved. That is why the dashboard could not actually
have a quick panel open beside it, and `#09` now owns the general fix.

`#03` needs a settings window open above the dashboard with both surfaces
visible, so the settings window cannot simply own a second grab.

## Decision

The dashboard keeps the single grab and whitelists the settings window into
it. `PanelShell` gains two opt-in properties:

- `extraGrabWindows` (default `[]`) is appended to the grab's window list:
  `windows: [root].concat(root.extraGrabWindows)`.
- `grabEnabled` (default `true`) switches the internal grab off.

`SettingsCenter` sets `grabEnabled: false` and registers its window on
`SettingsService.window`. `DashboardCenter` binds
`extraGrabWindows: SettingsService.window ? [SettingsService.window] : []`.

One grab means one clear: an outside click fires the dashboard's
`outsideClicked`, which closes the settings window and then the dashboard.
Escape stays per-window: the focused surface's `Shortcut` handles it, so
Escape closes settings when settings holds focus and closes both when the
dashboard does.

## Alternatives considered

- **The settings window owns its own grab (the standard panel pattern).**
  Two grabs clear each other; the dashboard vanishes as settings opens, which
  fails the ticket's first acceptance box.
- **Layer settings inside the dashboard's own window and mask (one surface).**
  No second grab and no coexistence risk, but it is not a standalone window,
  and `PanelShell`'s mask is built for one attached card, not two floating
  rects.
- **Hand the grab from the dashboard to settings while settings is open.**
  Still needs both window references, and adds a handoff window in which
  neither grab is active, so an early click can dismiss both.

## Consequences

- `#09` reuses `extraGrabWindows` to whitelist a quick panel; the grab, not
  the registry, was the only thing blocking visible coexistence.
- The settings window has no independent dismissal. Closing the dashboard
  closes settings, enforced in `DashboardService.onDashboardVisibleChanged`.
- A window object crosses a singleton (`SettingsService.window`). It is a
  reference, not a parent, and it is cleared in `Component.onDestruction`.
- The settings window sits above the dashboard by declaration order on the
  shared layer; a future surface between them would need an explicit layer.

## Amendments

- 2026-09-28 (dashboard-settings `#09`): the shared grab returned as a
  redesign, not by restoring `extraGrabWindows` and `grabEnabled`.
  `services/PanelGrab.qml` owns the single `HyprlandFocusGrab`, every
  `PanelShell` registers its window, and `PanelShell` no longer declares a
  grab. The window list is the always-visible bar plus the registered shells
  whose `panelVisible` is true, so the owner never changes with open order.
  This supersedes the "whitelist a second window into one owner" shape above,
  which could not stay order-independent.
