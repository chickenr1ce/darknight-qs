# 04: Inline world clock editing with persistence

**What to build:** zones are added and removed inside the calendar panel with no separate settings window. Adding offers a short common list plus manual IANA entry, at most 6 zones, and edits survive restart from a persisted string list defaulting to the current 4.

**Blocked by:** 01.

**Blocking:** none.

**Status:** ready-for-agent

- [ ] Add from the common list and from manual entry, remove inline, capped at 6
- [ ] Zones persist across shell restart, defaults intact on first run
- [ ] Invalid manual entry degrades to a plain label instead of breaking the row
- [ ] Type and style gates pass plus the live panel checklist for this ticket
