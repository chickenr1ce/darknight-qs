# 01: Shared node loader; run ThemeParsers.js and StateParsers.js for real

**What to build:** One node loader for `.pragma library` QML JS files, and the
nine Python mirrors of code that is already JS replaced by node runs of the
shipped files. No QML changes.

**Blocking:** 02, 03, 04, 05, 06

**Blocked by:** None

**Status:** done

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`.

## Acceptance criteria

- [x] `tests/qmljs.js` exports `load(path, globals)`: reads the file, strips
      the `.pragma` line, creates a `vm` context with `console`, an identity
      `qsTr`, and any `globals` passed, runs the file, returns the context.
- [x] The two existing node blocks in `scripts/test-panel-logic.sh` (B1
      regression near :2077, catalog cross-check near :2326) load through
      `tests/qmljs.js` instead of their own inline `vm` setup.
- [x] The eight `ThemeParsers.js` mirrors in `scripts/test-panel-logic.sh`
      (`parseColors` tables and cascade, `isTrustedStat`,
      `parseSelection`/`serializeSelection`, `displayName`, `parseTomlString`,
      `parseCatalog`, `backgroundMaxBytes`/`encodePath`/`parseBackgroundList`)
      become node runs of `services/ThemeParsers.js` with the same cases;
      the Python copies are deleted.
- [x] The `StateParsers.parseZones` mirror becomes a node run of
      `services/StateParsers.js`, plus cases for `parseCavaSettings`,
      `parseAudioSettings` and `parseFontSettings`; the Python copy is deleted.
- [x] Every case the deleted mirrors checked is still checked.
- [x] `scripts/check.sh` passes.

## Measurement

- [x] `../mutation-probe.sh <repo>` reports `caught` for: the `StateParsers.parseCavaSettings` mutant, and the `ThemeParsers.isValidThemeName` control still. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [x] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.
