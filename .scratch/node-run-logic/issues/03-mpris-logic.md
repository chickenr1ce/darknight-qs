# 03: MPRIS player logic in node-run JS

**What to build:** `services/MprisLogic.js` holds the pure player-key, app-list
and formatting logic now inline in `MprisPlayers.qml`; the dashboard-data tests
run the real file.

**Blocking:** None

**Blocked by:** 01

**Status:** done

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`.

## Acceptance criteria

- [x] `MprisLogic.js` exports `playerKey(player)` (duck-typed: reads
      `desktopEntry`, `identity`, `dbusName`), `defaultAllowed(key)` with the
      browser lists as file constants, `parseApps`, `sameApps`,
      `mergeApps(stored, current)` (the merge now in `applyApps`),
      `formatTime`, and `nextLoopState(current, states)` where `states` is
      `{ None, Track, Playlist }`.
- [x] `MprisPlayers.qml` delegates to it, passing `MprisLoopState` values to
      `nextLoopState`. `MprisPlayers.browserTokens`/`browserExact` are removed
      or read from the JS constants. Public `MprisPlayers` functions keep their
      names.
- [x] The `nextLoopState`, `formatTime`, `defaultAllowed` and
      `playerKey`/`parseApps`/`applyApps` mirrors in `test-dashboard-data.sh`
      become node runs; the Python copies are deleted. The `toggleShuffle`
      mirror is deleted or reduced to a wiring grep (it writes a player
      property and stays in QML).
- [ ] `scripts/check.sh` passes; live check: Settings → MPRIS app filter and
      the dashboard player still work.

## Measurement

- [x] `../mutation-probe.sh <repo>` reports `caught` for: the `MprisPlayers.formatTime`, `nextLoopState` and `parseApps` mutants. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [x] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.

## Amendments

2026-10-07. AC3 allowed the `toggleShuffle` mirror to go once the other MPRIS
checks run under node, but `toggleShuffle` stays in QML (it writes a player
property), so dropping its Python mirror left the "flip only while
shuffleSupported" rule unchecked. A wiring grep now asserts the
`if (!player || !player.shuffleSupported)` guard in `MprisPlayers.qml`.
