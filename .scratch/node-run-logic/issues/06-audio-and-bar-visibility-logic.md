# 06: Audio output discovery and bar visibility parsing in node-run JS

**What to build:** `services/AudioLogic.js` holds the output discovery,
ordering and volume conversion now inline in `AudioService.qml`, and
`parseVisibility` moves out of `BarVisibilityService.qml`; the tests run the
real files.

**Blocking:** None

**Blocked by:** 01

**Status:** done

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`. The
discovery functions read plain properties off PipeWire nodes (`isSink`,
`isStream`, `audio`, `name`, `description`, `nickname`, `id`), so they run on
plain objects under node.

## Acceptance criteria

- [x] `AudioLogic.js` exports `isSinkNode`, `keyFor`, `rawLabelFor`,
      `orderedNodes(nodes, orderKeys)`, `percentForVolume` and
      `volumeForPercent`. `AudioService.qml` delegates and keeps its public
      names; ADR 0014's discovery rule is unchanged.
- [x] `parseVisibility(jsonText, moduleKeys)` moves to a `.pragma library`
      file (`services/StateParsers.js` or a new `BarVisibilityLogic.js`);
      `BarVisibilityService.parseVisibility` delegates, passing the keys from
      `root.modules`.
- [x] The `AudioService` discovery and `percentForVolume`/`volumeForPercent`
      mirrors in `test-dashboard-data.sh` and the `parseVisibility` mirror in
      `test-panel-logic.sh` become node runs; the Python copies are deleted.
- [ ] `scripts/check.sh` passes; live check: Settings → Audio output list,
      order and hide still work, and hidden bar modules stay hidden after
      `scripts/restart.sh`.

## Measurement

- [x] `../mutation-probe.sh <repo>` reports `caught` for: the `AudioService.percentForVolume` and `BarVisibilityService.parseVisibility` mutants. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [x] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.

## Amendments

2026-10-07. AC1 said "public names stay"; `BarVisibilityService.defaultVisibility`
was removed because the all-visible default now lives inside
`StateParsers.parseVisibility`. No caller referenced it (grep clean), so the
intent holds. Also `AudioLogic.isSinkNode` now wraps its result in `Boolean()`
to keep the QML `: bool` coercion, and a `sink/no-flag` case covers it.
