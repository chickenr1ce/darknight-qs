# 05: Dashboard live blocks

**What to build:** The dashboard card gains live blocks in V1 order. Fastfetch summary with distro plus compositor plus uptime, live CPU plus RAM use, one volume slider per audio output, and a player block with track plus transport plus repeat plus shuffle.

**Blocked by:** 01 Dashboard shell

**Status:** ready-for-agent

- [ ] Fastfetch block reads distro plus compositor plus uptime on open
- [ ] CPU plus RAM values update on lightweight polling with no shell stutter
- [ ] Each audio output has a working slider beside the existing default control
- [ ] Player shows track plus artist with working play pause plus next plus previous plus repeat plus shuffle
- [ ] Type lint plus review lint gates pass and live verification runs on a test instance
