# ADR 0001: Panels open under their triggers

Date: 2026-09-16. Feature: calendar (`#01`).

## Context

Floating panels (calendar, notification center) were single global
`PanelWindow` instances anchored top-right of the primary screen. Clicking
the clock on DP-2 opened the calendar on DP-1, far from the cursor, and the
bell-anchored center sat in the same corner by coincidence rather than by
rule. Future panels (weather, …) would each re-solve the same placement.

## Decision

Shared anchor plumbing lives in `components/PanelShell.qml`. The trigger
reports its screen plus its center x on click; the shell centers the 380px
panel on that point and clamps it inside the screen edges:

- `finalLeft = clamp(triggerCenter − panelWidth / 2, panelEdgeMargin, screenWidth − panelWidth − panelEdgeMargin)`,
  with the 8px gap under the slab kept. Taken from the approved click-through
  prototype (`panel-under-trigger.html`); the bell case shifts left while the
  clock case barely shifts.
- Geometry tokens are shared (`Globals.panelTopGap`, `Globals.panelEdgeMargin`);
  no hardcoded pixels outside them.
- The anchor is set on the service (`anchorScreen`, `anchorCenterX`) before
  visibility flips, never mid-fade. Re-clicking the same monitor toggles;
  clicking another monitor moves the open panel there.
- One panel at a time (triggers hide the other panel first — unchanged).
  Outside click closes via the existing `HyprlandFocusGrab`; Escape closes via
  a `Shortcut` firing while the panel holds keyboard focus.

## Alternatives considered

- `PopupWindow` anchored to the trigger item: tracks the trigger for free,
  but popups are transient grabs tied to the parent window lifecycle — wrong
  fit for a persistent toggle panel shared across bar instances.
- Per-screen duplicate panel instances: doubles state and risks the two
  copies disagreeing; one instance moving to the clicked screen keeps the
  existing singletons (`CalendarService`, `NotificationServer`) as the state
  seam.

## Consequences and known limits

- Weather and later panels get placement free by composing `PanelShell` and
  reporting their own trigger geometry.
- Escape only reaches the panel while it holds keyboard focus (compositor
  routes keys to the focused app otherwise — verified platform behavior, not
  something the shell can override without an exclusive grab). Mouse
  dismissal is always one gesture via outside click.
- "Focus returns to the trigger" is implicit: the bar never takes keyboard
  focus, so closing the focusable panel surface hands compositor focus back
  to the app under the cursor, which sits over the trigger just clicked.
