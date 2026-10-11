# 10 — Deepen four seams (architecture review follow-up)

Branch `arch/deepen-seams`, worktree `~/worktrees/quickshell-arch-seams`, base
`main` at `aaaf471`. Source: the 2026-10-11 architecture review
(`/tmp/opencode/architecture-review-1791749186.html`, corrected copy), which
proposed twelve cards. After verification against the code, four were judged
worth doing; the rest are deferred (see the end of this file).

Done means: every card below is implemented, reviewed, committed on this
branch, `scripts/check.sh` passes, `scripts/boot-check.sh` reports `loaded`, and
the branch rebases cleanly onto `main`.

## Workflow (resume from here after a reboot)

1. Read the **Progress log** at the bottom; pick the first card not `done`.
2. Implement the card: implementer agent = OpenCode
   `opencode-go/deepseek-v4.1-flash`, reasoning `high`. One card per pass, no
   commits by the agent.
3. Review the uncommitted diff: reviewer agent = OpenCode
   `opencode-go/muse-spark-1.3-contributor`, reasoning `xhigh`. Feed High and
   Medium findings back to a fresh implementer pass; re-review only after a
   High finding (per `docs/dev/CODING_STANDARDS.md`, "Review fanout").
4. Orchestrator verifies (`scripts/check.sh`, `scripts/boot-check.sh
   $PWD`), commits the card as one conventional commit, and updates the log.

Cards run strictly in order: each one edits `scripts/test-panel-logic.sh`, so
parallel passes would conflict.

Rules every pass follows: `docs/dev/CODING_STANDARDS.md` (pure logic in a
`.pragma library` JS file beside its service, one-line QML delegates, node
tests through `tests/qmljs.js`, Python oracles only for logic node cannot
load), `id: root` file roots, `id`-prefixed child ids, comment density of the
surrounding code.

---

## Card 1 — One bar-trigger seam (`PanelTrigger`)

**Verified facts**
- `modules/Clock.qml`, `modules/Notifications.qml`, `modules/PowerMenu.qml`
  each carry the same adapter: `property ShellScreen triggerScreen`,
  `toggleAtBar()` calling `Panels.toggleAt(<Svc>.panelState, root.triggerScreen,
  Globals.triggerCenterX(root, root.triggerScreen))`, `syncAnchor()`
  registering/unregistering with `<Svc>.barAnchor`, a `Connections` on
  `<Svc>.barAnchor` whose `onToggleRequested` is guarded (Clock on
  `root.anchorActive`, the other two on `root.visible`), plus
  `onClicked`/`on…Changed`/`Component.onCompleted`/`Component.onDestruction`
  lifecycle lines.
- `modules/Cava.qml:198-203` toggles its panel by click with the same
  `Panels.toggleAt` + `triggerCenterX` preamble but has no `BarAnchor`, and
  `CavaService` has **no** `IpcHandler` — Cava is the only bar panel with no IPC
  toggle target.
- `services/BarAnchor.qml` (25 lines) only re-emits `toggleRequested`; the
  dispatch lives in every module. IPC targets: `calendar` and `notifications`
  return `"ok"` / `"error: … is hidden"`; `power.toggle()` returns `void`.
- Cava, Notifications, PowerMenu gate `visible` on
  `Globals.onPrimaryMonitor`; Clock is on every bar and uses `anchorActive`.
- `ActiveWindow.qml` opens the dashboard (not a `Panels` panel); out of scope.
- Gate: `scripts/test-panel-logic.sh` section 22 asserts the current shape by
  grep (lines ~4089-4181). ADR: `docs/adr/0001-under-trigger-panel-placement.md`.

**Scope**
- Add `services/PanelTrigger.qml`, a non-visual `QtObject` (it must not be an
  `Item`: modules are `ModuleBox` layouts and an `Item` child would take layout
  space), registered non-singleton in `services/qmldir`. Interface:
  `anchor: BarAnchor`, `panelState`, `trigger: Item`, `triggerScreen`,
  `active: bool`; `function toggle()` does the `Panels.toggleAt` dispatch with
  `Globals.triggerCenterX`. It owns register/unregister on `active` changes,
  on completion and on destruction, and answers `anchor.toggleRequested` only
  while `active` (keeps the per-monitor double-toggle guard).
- Clock, Notifications, PowerMenu declare one `PanelTrigger` each and call its
  `toggle()` from `onClicked`; their adapter functions and `Connections` go.
- Cava: `CavaService` composes a `BarAnchor` exposed as `barAnchor` and an
  `IpcHandler { target: "cava" }` with `toggle(): string` (`"ok"` /
  `"error: cava module is hidden"`) and `close(): string` matching the calendar
  target; `modules/Cava.qml` declares a `PanelTrigger` (active =
  `root.visible`) and its left click calls it.
- Rewrite gate section 22 to assert the new shape (PanelTrigger interface,
  each of the four modules composes one bound to its service, guard on
  `active`, the cava IPC target and its error string). Do not weaken the
  per-monitor guard check.
- Add a short amendment note to ADR 0001 and mention `cava` in the IPC docs
  wherever the other panel targets are listed (grep `target: "calendar"` /
  `qs ipc call calendar` in `docs/` and `README*`).
- Leave `power.toggle()` returning `void` (separate finding, not in scope).

**Acceptance**
- No module contains `toggleAtBar`, `syncAnchor`, or a `Connections` on a
  `barAnchor`; `grep -rn 'Panels.toggleAt' modules/` shows nothing (dispatch
  lives in `PanelTrigger`).
- `scripts/check.sh` passes; `scripts/boot-check.sh $PWD` reports `loaded`.
- Live: `qs ipc call cava toggle` opens the Cava panel under its bar module.

## Card 3 — Settings filter predicate into `SettingsLogic.js`

**Verified facts**
- `services/SettingsFilter.qml` (17 lines) is a QML singleton holding pure
  string logic: `filtering(filter)` and `matches(filter, label)` (lowercase
  substring, empty filter matches everything).
- `windows/SettingsView.qml:38-45` `sectionMatches(section)` re-implements the
  same lowercase-substring rule at section scope (title or any option) instead
  of calling it.
- 40 `SettingsFilter.matches` call sites under `windows/`. The gate
  (`test-panel-logic.sh` ~1397-1415) only greps for presence.

**Scope**
- Add `services/SettingsLogic.js` (`.pragma library`): `filtering(filter)`,
  `matches(filter, label)`, `sectionMatches(query, title, options)` built on
  `matches`.
- `SettingsFilter.qml` imports it and keeps `filtering`/`matches` as one-line
  delegates (call sites unchanged). `SettingsView.sectionMatches` becomes a
  one-line delegate passing `root.query`, `section.title`, `section.options`.
- Add a node block in `test-panel-logic.sh` loading the real file through
  `tests/qmljs.js` (pattern: the `MonitorLogic.js` block near line 351):
  empty filter, case folding, non-match, section title hit, option hit,
  no-option miss. Keep the existing presence greps; add a grep that both
  delegates call `SettingsLogic.`.
- Update the "Pure QML logic" file list in `docs/dev/CODING_STANDARDS.md`.

**Acceptance**: no `toLowerCase().includes` left in `SettingsFilter.qml` or
`SettingsView.qml`; gate and boot check pass; settings search behaves as before.

## Card 8 — Calendar date math into `CalendarLogic.js`

**Verified facts**
- `services/CalendarService.qml` (383 lines) has no Logic file; inline:
  the `monthCells` binding (lines ~54-98: lead days, prev/next month wrap,
  42 cells), `isStale` (246), `shiftMonth` (277), `isoFor` (292), `zoneLabel`
  (298), `zoneDiff` (308), `zoneTitle` (321), `isValidZoneName` (359),
  `addZone`/`removeZone` (363/373).
- Gate section 6 holds a Python mirror of `isStale` ("Mirror of
  CalendarService.isStale", ~line 224) that the standards say should be a node
  test once the logic is loadable.

**Scope**
- Add `services/CalendarLogic.js` (`.pragma library`) with the pure parts:
  `isoFor(y, m, d)`, `monthCells(year, month, todayIso, selectedIso,
  eventDays)` (returns the 42-cell array), `shiftMonth(year, month, delta)` →
  `{ year, month }`, `isStale(nowMs, fetchedAtMs, failed)`, and the pure string
  parts of `zoneLabel`/`zoneDiff`/`zoneTitle`, `isValidZoneName`, and pure
  list transitions for add/remove (`withZone(list, iana, max)`,
  `withoutZone(list, iana)`). Anything that reads QML state or a `Process`
  stays in the service and passes state in.
- `CalendarService` keeps every public function name as a one-line delegate;
  `monthCells` keeps its reactive dependency reads (`root.todayIso`,
  `root.eventDays`, `root.viewYear`, `root.viewMonth`, `root.selectedIso`) by
  passing them as arguments.
- Node block in the gate: leap February (2024 vs 2023), a month starting on
  Monday (lead 0) and Sunday (lead 6), December→January and January→December
  wrap in both `shiftMonth` and `monthCells`, `isStale` cases from the Python
  mirror, zone add (dedupe, max cap) / remove. Delete the Python `is_stale`
  mirror and its checks once the node cases cover them.
- Update the "Pure QML logic" file list in `docs/dev/CODING_STANDARDS.md`.

**Acceptance**: calendar grid, month navigation, world clock unchanged live;
gate and boot check pass; `CalendarService.qml` shrinks.

## Card 4 (reduced) — One volume glyph rule, bar percent through the tested helper

**Verified facts**
- `modules/Audio.qml:23` and `windows/VolumeOsd.qml:25` carry the identical
  ternary `audioNode === null ? Icons.volumeOff : (audioNode.muted ?
  Icons.volumeMute : Icons.volumeHigh)`.
- `modules/Audio.qml:24` hand-rolls the percent text with its own NaN guard;
  `AudioService.percentText` (→ `AudioLogic.percentText`, node-tested) gives the
  same result and the OSD already uses it.
- `windows/DashboardVolumeBlock.qml` already delegates via
  `AudioService.percentForVolume` and renders per-sink rows whose node is never
  null, so its two-arm glyph is correct. **Leave it unchanged.**

**Scope**
- `AudioService.volumeGlyph(audioNode): string` (QML, because `Icons` is a QML
  singleton a `.pragma library` file cannot import) holding the three-arm rule.
- `Audio.qml` and `VolumeOsd.qml` bind `volumeGlyph` to it; `Audio.qml`'s
  `volumeText` becomes `root.audioNode === null ? "" :
  AudioService.percentText(root.audioNode.volume) + "%"`.
- Gate: assert the ternary appears only in `AudioService.qml` and that both
  surfaces call `AudioService.volumeGlyph(` and the bar calls
  `AudioService.percentText(`.

**Acceptance**: bar and OSD glyph/percent unchanged live (mute, unmute, no
sink); gate and boot check pass.

---

## Deferred (not in this branch)

Card 2 (Settings section shell), 5 (Cava geometry), 6 (launcher rows), 7
(dashboard page adapters), 9 (themed-app manifest), 10 (palette JSON), 11
(remaining Python mirrors, beyond `isStale`), 12 (render seam), and the
secondary findings. Reasons are in the review discussion: large churn for
rare pain, or cross-language changes against ADR 0018.

## Progress log

| Card | Status | Commit | Notes |
| --- | --- | --- | --- |
| baseline | done | `aaaf471` | `scripts/check.sh` all gates ok before any change |
| 1 bar-trigger seam | done | see git log | impl r1 + review r1 (ship; Low #1 rejected: QtObject has no default property, Low #2 applied). check + boot ok. Live `qs ipc call cava toggle` untested |
| 3 SettingsLogic.js | done | see git log | impl r1 + review r1 (ship, no findings). check + boot ok |
| 8 CalendarLogic.js | done | see git log | impl r1 + review r1 (ship; 3 deviations accepted; Low applied: stale boundary checks, mutation-verified). check + boot ok |
| 4 audio glyph/percent | done | see git log | impl r1 + review r1 (ship; Low #1 applied: glyph rule pinned whole, mutation-verified; Low #2 rejected: AudioLogic.js is node-tested in test-dashboard-data.sh). check + boot ok |
| final rebase check | pending | | |
