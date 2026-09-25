# ADR 0005: dashboard card joins the bar with a concave fillet

Date: 2026-09-25. Feature: dashboard-settings (`#02`).

## Context

`#01` shipped the dashboard as a centered card toggled from the bar center.
`#02` attaches it to the bar. The reference screenshot is a floating card
with convex corners and a drop shadow, so it fixes the layout but says
nothing about the junction: there is no bar in it. Attached with the shared
`Globals.panelRadius` (9), the card's two convex top corners leave
background-coloured notches against the bar's straight bottom edge, so the
card reads as detached and merely touching.

## Decision

Attached mode shapes the junction as a concave fillet. The card widens to
`dashboardWidth + 2 × junctionRadius` and arcs are centred outside the body
at `(bodyL − r, r)` and `(bodyR + r, r)`, tangent to the bar's bottom edge
and to the card's side, so bar and card read as one surface.

- Default `r = 16`, user adjustable `0..32`; `0` renders the square join, so
  one property covers both.
- The value lives on `DashboardService.junctionRadius`. `PanelShell` gains an
  opt-in `junctionRadius` (default `0`) so quick panels keep plain chrome.
  Ticket `#03` adds the settings control and its state-file persistence.
- Top margin is 31: a 1px underlap beneath the bar, safe because both
  surfaces are `Colors.panel`. The border stroke runs left-arc → side →
  bottom → side → right-arc, omitting the top straight segment, so no line
  crosses the join.
- The input mask is a nested `Region` matching the outline: body rect, top
  strip, and a small staircase per corner. The widened window keeps its empty
  side strips from swallowing clicks meant for the desktop.
- The widened window is clamped to `panelEdgeMargin`; the card body shifts
  inward by up to `r` only when the screen runs out.

## Alternatives considered

- **Convex rounded top corners (the reference shape).** Two notches at the
  join; the card reads as detached. This is the state the ticket started in.
- **Square top, radius 0.** No notch and no new geometry, but a hard right
  angle against a bar whose own corners round at 9. Kept as the `r = 0` case
  of the same property rather than a separate mode.
- **Copying the reference's curvature.** It is a floating card over wallpaper
  with a drop shadow, so its corner radius is a different problem; it cannot
  answer a junction that does not exist in it.

## Consequences

- The window widens to 752 at `r = 16` and shifts left by `r`; the anchor
  clamp and the input mask both follow the widened window, not the body.
- The 1px underlap depends on bar and card sharing `Colors.panel`; a future
  border or gradient on either surface would expose it.
- `r = 16` exceeds `panelPadding` (12), but content is inset from the body, so
  it stays clear of the fillet at every radius in range.
- Motion is unchanged. The entrance translates from 8px above final, so the
  shaped top crosses the bar while opening; that is a verify-live item, and
  the fix if it reads is to drop the upward translate in attached mode.

The verdict came from `.scratch/dashboard-settings/prototype-junction.html`
(variants A/B concave at r=9/16, C/D convex anchors, E square).
