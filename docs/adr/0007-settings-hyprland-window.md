# ADR 0007: settings is a Hyprland-managed window

Date: 2026-09-26. Feature: dashboard-settings (`#03`, supersedes the settings
half of ADR 0006). Superseded by ADR 0012 (2026-10-03): settings is the
dashboard's Settings tab, not a toplevel.

## Context

`#03` shipped settings as another `PanelShell`, a layer-shell surface, and
folded it into the dashboard's focus grab because two layer-shell grabs could
not coexist (ADR 0006). The result was a panel that wanted to be a window.
Hyprland did not manage it: no move or resize, no window-switcher entry, no
keybind target, no independent dismissal, and its stacking came from
declaration order on the shared layer. The `grabEnabled` and `extraGrabWindows`
properties existed only to hold that arrangement together.

A layer-shell surface cannot be managed by the compositor, so the fix is a
toplevel. Quickshell provides `FloatingWindow`, "standard toplevel operating
system window that looks like any other application."

One constraint decides the rest. Hyprland draws layer-shell surfaces above
every toplevel, so a `FloatingWindow` settings can never appear above the
layer-shell dashboard. Both visible at once, the acceptance criterion `#03`
shipped with, is not reachable once settings is a toplevel.

## Decision

Settings is a `FloatingWindow`, and the dashboard closes when it opens.

- `windows/SettingsCenter.qml` is a `Loader` hosting a `FloatingWindow`;
  `SettingsService.visible` drives `Loader.active`. Opening closes the
  dashboard, and `DashboardService` closes settings when the dashboard opens,
  so the two are mutually exclusive and never stack.
- Escape and the close button close it. Outside click no longer does, which is
  what a normal window does, and Hyprland owns focus.
- The window is a fixed 900 by 600 (`Globals.settingsWidth` and
  `settingsHeight`) with a pinned search field and a scrolling section body, so
  the settings list can grow without resizing the window. A toplevel cannot be
  placed on a chosen monitor at creation:
  `screen:` is ignored before mapping, and assigning it after mapping destroys
  the window (both verified live). So on Hyprland's `openwindow` event,
  `SettingsCenter` moves the matching window to the monitor named by
  `SettingsService.anchorScreen` and re-centers it, with
  `hl.dsp.window.move({ monitor, window })` then `hl.dsp.window.center({ window })`.
  Both dispatches target the window by title selector, so they never move or
  center the user's active window by mistake.
- Float and centering come from a Hyprland window rule keyed on class
  `org.quickshell` and title `Settings`, added to
  `~/.config/hypr/modules/windowrules.lua`. Without that rule the toplevel
  tiles.
- A compositor close destroys the surface for good, so the `Loader` recreates
  it on the next open (`onClosed` resets the service). Setting `visible` false
  and true again cannot revive a closed `FloatingWindow` (verified live).
- `PanelShell.grabEnabled` and `PanelShell.extraGrabWindows` are removed. `#09`
  must reintroduce whatever whitelist mechanism its dashboard plus quick-panel
  coexistence needs.

## Alternatives considered

- **Keep settings a layer-shell panel and only restyle it.** That does not make
  Hyprland manage it, which is the point.
- **Keep both visible by putting settings on the overlay layer.** Layer
  surfaces are not compositor-managed either, so it is the same panel problem
  one layer up.
- **Make the dashboard a toplevel too, so both stack normally.** The dashboard
  is anchored under the bar and leans on `PanelShell`'s junction and mask.
  Moving it off layer-shell discards `#02` and reintroduces the placement
  problem layer-shell solves.
- **Let Hyprland place settings on the focused monitor instead of the anchor
  screen.** The bar is a layer surface and clicking it does not move the
  compositor's focused monitor, so the window can land on the monitor the user
  is not working on.

## Consequences

- The Hyprland rule lives outside this repository, in the user's
  `~/.config/hypr`. If it is missing, settings tiles with no error from the
  shell.
- The window title comes from one QML constant, `settingsWindowTitle` in
  `windows/SettingsCenter.qml`, used by the window and the post-map selectors;
  the Hyprland rule matches the same literal `^Settings$`. The constant is not
  translated, because Hyprland matches the title literally. Renaming it
  without updating the rule breaks float or placement silently.
- Settings leaves the panel registry and the shared grab, so it needs neither
  `PanelShell` nor the outside-click timing.
- The window gets Hyprland's decoration (border, rounding, shadow) instead of
  the shell's 1px panel border. It reads as a window on purpose.
- Hosting the window in a `Loader` costs a create and destroy per open. That is
  cheap and buys recovery from a compositor close.

## Amendments

- 2026-09-28 (dashboard-settings `#09`): the whitelist mechanism this ADR asked
  `#09` to reintroduce shipped as `services/PanelGrab.qml`, a single shared
  `HyprlandFocusGrab` over every visible `PanelShell`, not as per-surface
  properties. Settings is unaffected; it is still a `FloatingWindow` with no
  grab.
