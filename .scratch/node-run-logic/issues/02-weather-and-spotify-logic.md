# 02: Weather and Spotify logic in node-run JS

**What to build:** `services/WeatherLogic.js` and `services/SpotifyLogic.js`
hold the pure functions now inline in `WeatherService.qml` and
`SpotifyService.qml`; the services delegate to them; the dashboard-data tests
run the real files.

**Blocking:** None

**Blocked by:** 01

**Status:** ready-for-agent

## Origin

Candidate 2 of the 2026-10-07 architecture review. See `../spec.md`.

## Acceptance criteria

- [ ] `WeatherLogic.js` exports `formatTemp`, `formatPrecip`, `parseWeather`,
      `parseLocations`, `isStale(nowMs, fetchedAtMs, failed, staleAfterMs)`,
      and `glyphKeyFor(code)` returning an `Icons` property name
      (`"weatherSunny"`, …) so the file does not depend on `qs.config`.
- [ ] `WeatherService.glyphFor(code)` returns `Icons[WeatherLogic.glyphKeyFor(code)]`;
      `WeatherService.isStale` passes `root.staleAfterMs`. The public
      `WeatherService` functions keep their names and signatures, so callers
      do not change.
- [ ] `SpotifyLogic.js` exports `parseResponse(text)`; its `qsTr` messages
      stay as they are.
- [ ] The `WeatherService` mirrors (`parseWeather`, `formatTemp`,
      `formatPrecip`, `glyphFor`, `isStale` in `test-dashboard-data.sh`;
      `parseLocations` and the `applyLocation` validation in
      `test-panel-logic.sh`) and the `SpotifyService.parseResponse` mirror
      become node runs through `tests/qmljs.js`; the Python copies are deleted.
- [ ] `scripts/check.sh` passes; live check: the dashboard weather block
      and the Spotify device list still render.

## Measurement

- [ ] `../mutation-probe.sh <repo>` reports `caught` for: the `WeatherService.formatTemp`, `isStale` and `glyphFor` mutants (glyphFor by behaviour, not only the source grep) and `SpotifyService.parseResponse`. Retarget a mutant at its new `*Logic.js` file when the function moves; add the test case it needs if the moved mirror cases do not expose it.
- [ ] `test-panel-logic.sh` plus `test-dashboard-data.sh` stay under 2.6 s combined (baseline 2.24 s); the commit message records the before and after probe result and timing.
