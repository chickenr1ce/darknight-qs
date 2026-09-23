# 01: Panel opens under power with flat action list

**What to build:** Clicking the bar power glyph opens a native panel
directly beneath it showing hostname, uptime, and five actions (Lock,
Suspend, Logout, Reboot, Shutdown) as one flat lavender list with boxed
glyphs, inset dividers, and hint chips. Clicking a row arms it visually.
Esc and outside click close. Opening power closes calendar,
notifications, and cava, and vice versa. No command fires yet; Lock
also only arms in this slice.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Panel anchors under the power trigger on the trigger monitor and
  matches the other panels entrance.
- [ ] All five actions render monochrome with dividers and no red.
- [ ] Arming a row shows visually; only one row arms at a time.
- [ ] One-panel rule holds in both directions; Esc and outside click
  close and clear the armed row.
- [ ] Type gate passes on touched files.
