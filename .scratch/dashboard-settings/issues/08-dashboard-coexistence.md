# 08: Dashboard plus panel visual coexistence

**What to build:** The dashboard plus one open quick panel stay visible at
the same time, sharing a single focus grab that whitelists both windows, so
outside click plus Escape still dismiss and the registry exclusion from #01
gains a visible counterpart.

**Blocked by:** 01 Dashboard shell

**Status:** ready-for-agent

- [ ] Dashboard plus one quick panel stay co-visible when opened in either order
- [ ] Outside click dismisses both and Escape dismisses from either surface
- [ ] Quick panels keep their mutual exclusion with each other
- [ ] Type lint plus review lint gates pass and live verification runs on a test instance

Discovered during #01. Live IPC probing there proved two PanelShell grabs
cannot coexist: whichever surface opens second clears the first through the
grab outside path, with no pointer involved. PanelShell reuse plus visible
beside-behavior conflict until one grab covers both windows.
