# Power menu spec

Status: ready-for-agent

## Problem Statement

The bar power button shells out to a rofi script. It looks and behaves
foreign next to the native panels, and its logout branch knows nothing
about Hyprland.

## Solution

A native power panel that opens under the power glyph on DP-1. One flat
lavender list, five actions, confirm on everything but Lock. Popup
behavior matches the other panels exactly.

## User Stories

1. As a desktop user, I want the power panel to open under the power
   button, so that it reads as part of the bar.
2. As a desktop user, I want Lock, Suspend, Logout, Reboot, Shutdown in
   one list, so that I stop reaching for rofi.
3. As a desktop user, I want Lock to fire at once, so that the common
   case stays one click.
4. As a desktop user, I want Suspend, Logout, Reboot, Shutdown to ask
   once by name, so that a mis-tap never kills my session.
5. As a Hyprland user, I want Logout to end the compositor session, so
   that the button works on this machine.
6. As a music listener, I want Suspend to pause media first, so that
   playback does not resume into the void.
7. As a keyboard user, I want keys 1-5 to arm an action, Enter to
   confirm, Esc to close, so that I never touch the mouse.
8. As a mouse user, I want hover to warm the row and arming to light the
   glyph box, so that I always know what is armed.
9. As a trackpad user, I want the press squash on rows and footer
   buttons, so that clicks feel landed.
10. As a cautious user, I want the footer question to crossfade by action
    name, so that the confirm never reads stale.
11. As a cautious user, I want Confirm inert while nothing is armed, so
    that Enter on an empty footer does nothing.
12. As a cautious user, I want Cancel to clear the armed row, so that I
    can back out in one click.
13. As a multi-monitor user, I want the panel to follow the trigger
    monitor pixel aligned, so that it never opens on the wrong screen.
14. As a bar user, I want opening power to close calendar, notifications,
    and cava, so that only one panel ever shows.
15. As a reader, I want hostname and uptime in the header, so that the
    rofi context survives the move.
16. As a low-vision user, I want danger carried by labels and the confirm
    step, never color alone, so that monochrome costs no safety.
17. As a reduced-motion user, I want every transition off and state
    changes instant, so that the panel stays usable.
18. As a reviewer, I want no new visual primitives and no raw theme
    values, so that the panel inherits the bar family.

## Implementation Decisions

- New PowerService singleton owns visibility through PanelState,
  anchor screen and center X, the armed action id, hostname and uptime,
  and the five-action model. A draft already exists untracked and gets
  finished, not rewritten.
- New PowerCenter window composes PanelShell plus PanelHeader plus one
  flat list. Rows are dividers only, no inner or outer card around them.
  Boxed 28px lavender glyphs, inset dividers, kbd hints.
- PowerMenu trigger drops the rofi Process and calls the Panels
  one-panel rule with its trigger screen and center X.
- Panels registry gains the power toggle and closes power from the
  calendar, center, and cava paths.
- Shell wires the trigger screen into PowerMenu and mounts PowerCenter
  beside the existing centers.
- Commands: Lock tries hyprlock, then betterlockscreen, then i3lock.
  Suspend pauses media, then sleeps. Logout dispatches Hyprland exit.
  Reboot and Shutdown call systemctl. Rofi stays until live verify
  passes.
- Motion: A1 system entrance untouched (PanelShell fade plus 8px rise,
  140ms). Rows combine S3 icon glow (box brightens, scale 1.08, hint to
  lavender, 140ms) with S4 press squash (row .985, icon .94, 120ms).
  Footer uses C1: question crossfade 140ms, buttons fade dim to live,
  hover warms 140ms, press squashes to the pill token .86 over 120ms.
  Confirm flash on run is the only accent beyond lavender.
- From prototypes (primary sources, /tmp/opencode): power-menu-flat
  F2 for the list, power-menu-select S3 plus S4 for rows,
  power-menu-footer C1 for the footer, power-menu-anim A1 for the
  entrance. Trimmed to the decisions above.

## Testing Decisions

- Good tests assert external behavior only: panel opens under the
  trigger, arming and confirm run the right command, footer states never
  reflow, Esc and outside click close.
- Seams, highest first: Panels one-panel rule for exclusivity,
  PowerService arm and confirm functions for command mapping,
  scripts/lint.sh (qmllint) as the type gate. No new test harness; the
  repo has qmllint plus live boot only.
- Live verify runs `quickshell -p` against the config and clicks every
  row, but never fires Reboot, Shutdown, Suspend, or Logout for real.
  Confirm the armed label, footer wake, and command argv from logs or a
  dry run. Stop or mask the daily Notifications holder first and never
  run a second instance while it holds the bus.
- Prior art: scripts/smoke-toasts.sh as the regression-gate pattern for
  the toast layer; lint-review.sh for style.

## Out of Scope

- Removing the rofi script before the native path verifies live.
- Center modal, icon strip, split drawer, and palette variants.
- Extra actions such as reboot to BIOS.
- New lock backends beyond the fallback chain.
- Strings beyond qsTr coverage already in the panel.

## Further Notes

- Monochrome is deliberate: no red anywhere, Confirm is lavender.
- Uptime repolls every 60 seconds and skips while a run is in flight.

## Amendments

- 2026-09-23: Dropped the "Confirm flash on run" (Motion decision
  above). It would need a mint token outside `config/Colors.qml` and
  would hold the panel open across a destructive run; the panel now
  closes at once on run with no accent beyond lavender.
