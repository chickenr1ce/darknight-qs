# 04: Bar visibility plus persistence

**What to build:** Settings gains a layout section with one checkbox per bar module. Choices persist in a new state file and the bar honors them on all screens after restart.

**Blocked by:** 02 Settings shell plus Cava section

**Status:** ready-for-agent

- [ ] One checkbox per bar module with immediate effect on the bar
- [ ] Choices survive shell restart through the new state file with echo guard behavior
- [ ] Section appears in settings search results
- [ ] Type lint plus review lint gates pass and live verification runs on a test instance
