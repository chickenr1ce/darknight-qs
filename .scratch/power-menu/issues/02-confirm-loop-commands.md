# 02: Confirm loop runs the real commands

**What to build:** The footer completes the loop: it names the armed
action with a crossfading question, Confirm stays inert while nothing
is armed, Cancel clears the row, and confirming runs the mapped command
and closes the panel. Lock fires at once with no confirm. Suspend
pauses media before sleeping, logout exits Hyprland, lock falls back
through hyprlock, betterlockscreen, i3lock. The rofi script stays until
this verifies live.

**Blocked by:** 01 (needs the panel, list, and arm state).

**Status:** ready-for-agent

- [ ] Confirm inert with nothing armed; footer never reflows between
  states.
- [ ] Lock runs immediately on click; the other four need one confirm.
- [ ] Cancel and close paths clear the armed row.
- [ ] Destructive commands verified by argv without firing; Lock
  verified live.
- [ ] Type gate passes on touched files.
