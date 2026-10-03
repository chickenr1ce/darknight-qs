# ADR 0008: dashboard is a centered card outside the panel registry

Date: 2026-09-28. Feature: dashboard-settings (`#01`, `#02`, `#08`).

## Context

ADR 0001 places every floating panel under its trigger. The trigger reports its
screen plus its center x, and `PanelShell` centers a `Globals.centerWidth`
(380px) panel on that point, then clamps it inside the screen. The rule assumes
a panel roughly the width of the trigger module it belongs to.

The dashboard breaks both halves of that assumption. It opens from the bar
center title (`modules/ActiveWindow.qml`) and holds a wide block grid, so it
uses `Globals.dashboardWidth` (720px) and `Globals.dashboardMaxHeight` (600px)
instead of the quick panel tokens. `#02` also attaches it to the bar, so its
top edge joins the bar's bottom edge through the junction fillet (ADR 0005)
rather than floating below with `panelTopGap`.

The registry poses the second problem. The quick panels share
`services/Panels.qml`, whose one-panel rule closes every other panel before it
opens the target. A dashboard in that registry would close when a quick panel
opened, which contradicts user story 16, where the dashboard stays open beside
a quick panel.

The spec records this departure in its Further Notes and asks for a decision
record.

## Decision

`windows/DashboardCenter.qml` composes `PanelShell` like the quick panels, but
with its own geometry and its own service, and it stays out of the registry.

- Geometry is a centered, attached card. `PanelShell` centers the card on the
  trigger's center x and clamps it to `Globals.panelEdgeMargin`, so it lands
  centered near the top edge of the clicked screen. `attachedToBar: true` joins
  it to the bar through `PanelShell.effectiveJunctionRadius`. It is
  `Globals.dashboardWidth` wide and capped at `Globals.dashboardMaxHeight`
  tall.
- State is `services/DashboardService.qml`, a singleton composed from
  `services/PanelState.qml` like the quick panels. It is absent from
  `services/Panels.qml`, and `Panels.anyOpen` does not read it, so the
  one-panel rule never closes the dashboard.
- The dashboard and the settings window are mutually exclusive through direct
  service calls (ADR 0007). Superseded by ADR 0012: settings is the dashboard's
  Settings tab, so there is no second surface to exclude.
- Dismissal reuses the shared shell behavior: outside click through the
  `HyprlandFocusGrab`, Escape through the shell `Shortcut`, the panel state
  anti-reopen window, and reduced motion gating.

Coexistence with an open quick panel needs one focus grab over both windows and
is not solved here. Ticket `#09` owns it.

## Alternatives considered

- **Join `services/Panels.qml` and accept the exclusion.** A quick panel would
  close the dashboard, which fails user story 16 and the spec line that the
  dashboard stays open beside quick panels.
- **Reuse the under-trigger rule unchanged.** `Globals.centerWidth` (380px) is
  too narrow for the block grid, and a card wider than its trigger has no left
  or right trigger edge to align to. Separate width and height tokens mark the
  geometry as deliberately different rather than a drifted quick panel.
- **Make the dashboard a toplevel like settings (ADR 0007).** The card leans on
  `PanelShell` for the junction fillet and the input mask that keeps the
  widened window from intercepting desktop clicks. A toplevel discards `#02`
  and returns placement to Hyprland, which is the problem layer-shell placement
  solved.
- **Anchor a popup to the trigger item rather than the bar-center point.**
  The card is much wider than the title label, and popups tie to the parent
  window lifecycle. ADR 0001 already rejected that shape for the quick panels.

## Consequences and known limits

- Toasts are not suppressed while the dashboard is open, because
  `Panels.anyOpen` does not include it. The spec lists toast suppression as
  story 29, proposed and still unconfirmed.
- The dashboard can be open when a quick panel opens, but until `#09` the two
  grabs clear each other. The quick panel's grab closes the dashboard through
  the outside path rather than through the registry. `#09` replaces that with a
  whitelist.
- The trigger is the bar center title, which hides when no window is focused,
  so the dashboard is unreachable on an empty workspace. Ticket `#10` covers
  that separately.
- `Globals.dashboardWidth` is the body width. The window widens by
  `2 × junctionRadius` at runtime, matching the `#02` junction geometry.

## Amendments

- 2026-09-28 (dashboard-settings `#09`): coexistence with an open quick panel
  landed. `services/PanelGrab.qml` holds one shared `HyprlandFocusGrab` over
  every visible `PanelShell` window plus the always-visible bar, replacing the
  per-shell grabs that cleared each other. The registry and the dashboard
  service stay as this ADR decided:
  `Panels` never reads `DashboardService`, and the dashboard stays outside it.
  The known limit above (the two grabs clear each other until `#09`) no longer
  applies. Outside click closes both surfaces; Escape closes the surface that
  holds focus.
