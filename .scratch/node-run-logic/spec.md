# Node-run logic: test the shipped code, not Python copies

## Problem

No test runs QML. `scripts/test-panel-logic.sh` (525 `grep -q`, 22 "Mirror of"
blocks) and `scripts/test-dashboard-data.sh` (166 `grep -q`, 25 mirrors) check
source text or re-implement QML functions in Python and test the copy. The only
shipped logic that runs is `services/ThemeParsers.js`, under node via
`vm.runInContext` (test-panel-logic.sh:2077 and :2326). That node run exists
because bug B1 shipped in the real parser while its Python mirror passed.

## Direction

Pure logic moves into `.pragma library` JS files next to its service
(`services/<Domain>Logic.js`, matching the existing `StateParsers.js` /
`ThemeParsers.js`). The QML service imports the file and keeps only wiring:
property writes, Process and Timer handling, QML types. The tests load the
real file under node through one shared loader and the matching Python
mirror is deleted.

Functions that read service state or QML types take that input as a
parameter instead: `isStale(now, fetchedAt, failed, staleAfterMs)`,
`nextLoopState(current, states)`, a glyph *key* instead of an `Icons` value.
`qsTr` is a QML global available to any JS loaded in QML (Qt 6.11, "QML
Global Object"), so the node loader stubs it as identity.

## Mirror inventory (2026-10-07)

| Mirror source | Count | Ticket |
| --- | --- | --- |
| `ThemeParsers.js` (already JS) | 8 | 01 |
| `StateParsers.parseZones` (already JS) | 1 | 01 |
| `WeatherService` format/glyph/stale/parse/locations, `SpotifyService.parseResponse` | 8 | 02 |
| `MprisPlayers` loop/time/defaultAllowed/key+apps/toggleShuffle | 5 | 03 |
| `MonitorService` applySettings, ordering, mode/position/scale | 3 | 04 |
| `SystemInfo`, `SystemMonitor` parse/format | 12 | 05 |
| `AudioService` discovery and percent, `BarVisibilityService.parseVisibility` | 3 | 06 |
| Calendar `isStale`, `FontPickerRow.filtered`, `HyprlandFocus.keysFor/classMatches`, `PanelShell.anchorLeft`, `Globals.screensByPosition` | 5 | not yet ticketed |
| `PanelState` debounce, `HyprlandFocus` queueing (timer/Process behaviour) | 2 | stay as they are |

`MprisPlayers.toggleShuffle` writes a player property and stays in QML; its
mirror goes once the other MPRIS checks run under node. `Globals.screensByPosition`
is named by ADR 0013, so moving its comparator needs care and is left out.

## Measurement

The claim is that tests stop passing over broken code. Speed is not the
claim, and the migration will not make the suite faster.

**Baseline, 2026-10-07** (`tests/mutation-probe.sh` plants one
bug at a time in a repo copy and runs both logic scripts):

| Mutant (shipped code) | Caught today |
| --- | --- |
| `WeatherService.formatTemp` round → floor | no |
| `WeatherService.isStale` threshold doubled | no |
| `WeatherService.glyphFor` fog → cloudy | only by a source grep for `Icons.weatherFog` |
| `SpotifyService.parseResponse` truthy `ok` | no |
| `MprisPlayers.formatTime` drops zero pad | no |
| `MprisPlayers.nextLoopState` Track → Playlist | no |
| `MprisPlayers.parseApps` default not allowed | no |
| `MonitorService.firstWorkspaceFor` off by one | no |
| `MonitorService.clampWorkspacesPerMonitor` max 30 | no |
| `SystemMonitor.parseNetSample` untrimmed iface | no |
| `SystemInfo.formatPackages` precision | no |
| `AudioService.percentForVolume` round → floor | no |
| `BarVisibilityService.parseVisibility` falsy hides | no |
| `StateParsers.parseCavaSettings` no upper clamp | no |
| control: `ThemeParsers.isValidThemeName` accepts all (already node-run) | yes |

So the logic suites catch 0 of 14 behavioural bugs in shipped QML/JS logic.
The one code path already run under node catches its bug. Several mirrors
also lack a case that would expose the mutant even if it ran on real code
(`format_temp` checks 15.2 and -2.6, where floor and round agree), so moving
code is not enough: each ticket adds the missing cases.

**Runtime baseline** (5 runs each, this machine): `test-panel-logic.sh`
2.06 s, of which 1.0 s is one `sleep 1` (line 2574); `test-dashboard-data.sh`
0.18 s; `scripts/check.sh` 10.4 s. Python start-up is ~10 ms and node
~25 ms, so the mirrors are not where the time goes.

**Result, 2026-10-07** (all tickets merged): every mutant reports `caught`,
each in the script that owns its domain.

| Mutant (shipped code) | Caught by |
| --- | --- |
| `WeatherService.formatTemp` round → floor | dashboard-data |
| `WeatherService.isStale` threshold doubled | dashboard-data |
| `WeatherService.glyphFor` fog → cloudy | dashboard-data (behaviour) |
| `SpotifyService.parseResponse` truthy `ok` | dashboard-data |
| `MprisPlayers.formatTime` drops zero pad | dashboard-data |
| `MprisPlayers.nextLoopState` Track → Playlist | dashboard-data |
| `MprisPlayers.parseApps` default not allowed | dashboard-data |
| `MonitorService.firstWorkspaceFor` off by one | panel-logic |
| `MonitorService.clampWorkspacesPerMonitor` max 30 | panel-logic |
| `SystemMonitor.parseNetSample` untrimmed iface | dashboard-data |
| `SystemInfo.formatPackages` precision | dashboard-data |
| `AudioService.percentForVolume` round → floor | dashboard-data |
| `BarVisibilityService.parseVisibility` falsy hides | panel-logic |
| `StateParsers.parseCavaSettings` no upper clamp | panel-logic |
| control: `ThemeParsers.isValidThemeName` accepts all | panel-logic |

**Runtime, after** (5 runs each): `test-panel-logic.sh` 2.16–2.17 s,
`test-dashboard-data.sh` 0.27 s, combined ~2.44 s, under the 2.6 s target.
The dashboard script grew from 0.18 s to 0.27 s for the extra node runs.

## Out of scope

- Booting QML in tests.
- Deleting `grep -q` checks that assert wiring (imports, call sites); only the
  ones a node run makes redundant go.
