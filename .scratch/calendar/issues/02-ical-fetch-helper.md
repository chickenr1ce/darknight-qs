# 02: iCal feed becomes local JSON

**What to build:** a small fetch helper outside QML that polls the primary secret iCal URL on an interval, converts the feed to a local JSON cache QML can read, and keeps the last good file when the network fails. QML never touches the network.

**Blocked by:** None (can start immediately).

**Blocking:** 03.

**Status:** ready-for-agent

- [ ] Fixture feed covering single, recurring, and multi day events converts to the expected JSON, checked by a script level test
- [ ] Failed poll keeps the last good cache with file age available for the stale marker
- [ ] Secret URL handled like a password: owner only permissions, never committed, rotation path noted
- [ ] Backend choice recorded as an architecture record, naming `gcalcli` as the upgrade path
