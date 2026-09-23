# 02: Confirm loop runs the real commands

**What to build:** The footer completes the loop: it names the armed
action with a crossfading question, Confirm stays inert while nothing
is armed, Cancel clears the row, and confirming runs the mapped command
and closes the panel. Lock fires at once with no confirm. Suspend
pauses media before sleeping, logout exits Hyprland, lock falls back
through hyprlock, betterlockscreen, i3lock. The rofi script stays until
this verifies live.

**Blocked by:** 01 (needs the panel, list, and arm state).

**Status:** done

- [x] Confirm inert with nothing armed; footer never reflows between
  states.
- [x] Lock runs immediately on click; the other four need one confirm.
- [x] Cancel and close paths clear the armed row.
- [x] Destructive commands verified by argv without firing; Lock
  verified live.
- [x] Type gate passes on touched files.

## Amendments

- 2026-09-23: No locker backend (hyprlock, betterlockscreen, i3lock)
  is installed on this machine, so the "Lock verified live" half of
  the argv checkbox holds argv/static only. Live lock re-verifies
  once a locker is installed; everything else verified live.
