# 03: Event dots plus selected day agenda

**What to build:** the month grid marks every day that has events and the panel shows a read only agenda with start times for the selected day. Browsing any month or year renders from cache with no network on month shift. Days with no events show an explicit empty state, and a stale marker with sync age shows after a failed poll.

**Blocked by:** 01, 02.

**Blocking:** none.

**Status:** ready-for-agent

- [ ] Dots appear on event days in the current and shifted months, recurrences included
- [ ] Agenda lists start time plus title for the selected day, empty state otherwise
- [ ] Year ahead browsing works with networking off
- [ ] Stale marker shows after a failed poll instead of blank
- [ ] Type and style gates pass plus the live panel checklist for this ticket
