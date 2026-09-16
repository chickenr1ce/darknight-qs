# 01: Panels open under their triggers

**What to build:** shared anchor plumbing with the calendar and the notification center as its first users. Clicking the clock opens the calendar centered under the clock on the clicked monitor. Clicking the bell opens the notification center centered under the bell. Panels shift only to stay on screen. One panel open at a time, outside click and Escape close, focus returns to the trigger.

Placement math, taken from the approved click through prototype: final left equals trigger center minus half the panel width, clamped into the screen edge margins. The anchor is set before the panel shows, never moved mid fade.

**Blocked by:** None (can start immediately).

**Blocking:** 03, 04.

**Status:** ready-for-agent

- [ ] Calendar centers on the clock on DP-1 and DP-2, clamped at both screen edges
- [ ] Notification center centers on the bell, shifted left off the bar edge, mutual exclusion with calendar preserved
- [ ] Outside click and Escape close either panel with focus back on the trigger
- [ ] Type and style gates pass, no new hardcoded geometry outside shared tokens
- [ ] Placement call recorded as an architecture record
