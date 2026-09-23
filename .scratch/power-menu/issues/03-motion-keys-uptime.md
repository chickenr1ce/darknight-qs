# 03: Selection motion, keyboard flow, live uptime

**What to build:** Rows get their feel: hover warms over 140ms, arming
lights the glyph box and lavender hint chip, press squashes the row and
dips the icon. Footer buttons warm on hover and squash on press.
Keys 1-5 arm, Enter confirms, Esc clears. Uptime and hostname go live
on a slow poll that skips while a run is in flight. Reduced motion
makes every state change instant.

**Blocked by:** 02 (needs the confirm loop the motion annotates).

**Status:** done

- [x] Hover, armed, and press states animate on GPU-only properties
  within the duration budgets; no height or anchor animation.
- [x] Full keyboard flow works without a pointer.
- [x] Reduced-motion path verified: state changes with no transition.
- [x] Header shows live hostname and uptime without layout shift.
- [x] Type gate passes; live boot shows no binding-loop or focus
  warnings tied to this panel.

## Amendments

- 2026-09-23: "Footer buttons warm on hover" reads as the shared
  `PillButton` hover state (instant text/border swap, no CPU color
  animation per the GPU-only budget above); the 140ms hover warm
  applies to the rows via the opacity wash, press squash animates on
  both rows and footer buttons.
