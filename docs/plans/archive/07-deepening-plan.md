# Deepening plan: four strong candidates

Date: 2026-09-28. Branch: `feat/arch-deepening`.
Source: architecture review pass 2026-09-28 on `main` at `1fcb906`.

This plan covers the four candidates the review marked Strong. The
Worth-exploring and Speculative candidates, and the Workspaces monitor
residual, stay out of scope.

## Order and dependencies

Candidates 01 and 03 both rewrite `services/NotificationServer.qml`, so one
agent does them together. Candidate 04 owns the two services that candidate 02
also touches, so 02 runs last, after 01, 03, and 04 settle.

| Step | Candidate | Files owned | Depends on |
|---|---|---|---|
| 1 | 01 + 03 | NotificationServer, NotificationRow, NotificationGroup, NotificationCard, NotificationToast, NotificationCenter, NotificationPopups | none |
| 2 | 04 | CalendarService, CavaService, new StateFile module, plain parser files, `services/qmldir`, io-notes | none |
| 3 | 02 | Panels, PanelState, the four services' panel wrappers, panel section of the test gate | 1, 2 |
| 4 | verify | lint, review, smoke, docs | 3 |

Steps 1 and 2 run in parallel. Step 3 waits for both. Step 4 is a separate
verification pass.

## 01 Delete the dead NotificationCard and put reply ordering behind the server

Objective: remove the superseded history card and give the reply ordering one
owner.

Files: `components/NotificationCard.qml` (delete), `services/NotificationServer.qml`,
`components/NotificationRow.qml`, `scripts/test-panel-logic.sh` (section 4),
`scripts/lint-review-baseline.txt`.

Problem: `NotificationCard` has zero instantiations. The center renders
`NotificationGroup` to `NotificationRow`. The one hard rule it shares with the
live row, read `resident` before `sendInlineReply` because send closes
non-resident notifications, lives as prose in both files.

Solution: delete the file. Add `sendReply(notification, text)` to
`NotificationServer` that reads `resident`, sends, and dismisses when resident.
`NotificationRow.sendReply` becomes a one-line call.

Acceptance criteria:

- `grep -rn NotificationCard` returns no source or gate reference.
- `NotificationServer.sendReply` owns the resident read, the empty guard, and
  the dismiss.
- `NotificationRow` holds no ordering comment and no resident logic.
- `scripts/test-panel-logic.sh` section 4 names the live surfaces.
- `scripts/lint.sh` passes.

## 03 Give NotificationServer one notifications collection

Objective: replace the three overlapping stores with one collection and derived
views.

Files: `services/NotificationServer.qml`, `windows/NotificationCenter.qml`,
`windows/NotificationPopups.qml`, `components/NotificationGroup.qml`,
`components/NotificationRow.qml`, `components/NotificationToast.qml`,
`CONTEXT.md` if a new term is needed.

Problem: one concept, the current notifications, is stored three ways
(`trackedNotifications` from the DBus server, `historyModel`, `activeToasts`),
and each consumer re-derives from a different one. Grouping lives in the
center while dismissal lives in the server. `unreadCount` counts
`trackedNotifications` while the empty state reads `historyModel.count`, so two
sources answer whether anything is present.

Solution: expose one notifications collection plus derived `groups`, `toasts`,
and `unreadCount`, keep the raw DBus collection private, and move grouping and
the critical predicate into the server. Consumers render derived views.

Acceptance criteria:

- One public source for the notification list. The raw DBus collection is not
  read outside `NotificationServer`.
- `groups` is computed in the server; the center no longer builds it.
- `unreadCount` and the empty state read the same collection.
- `isCritical(notification)` takes a notification, not a raw urgency, and the
  null guard lives inside it.
- The center and popups render derived views without re-deriving groups.
- `scripts/smoke-toasts.sh` passes. `scripts/lint.sh` passes.

## 04 Collapse the XDG state-file pattern into one module

Objective: one module owns path, watch, echo reload, and the loading guard.

Files: new `services/StateFile.qml` and `services/JsonStateFile.qml` (or one
file), `services/CalendarService.qml`, `services/CavaService.qml`,
`services/qmldir`, new plain parser file(s), `docs/quickshell-io-notes.md`,
`scripts/test-panel-logic.sh` if it asserts the old shape.

Problem: path resolution, `watchChanges` plus echo reload, and the per-site
loading guard are written five times, then patched per call site when the echo
queues an extra poll. `stateBase()` is byte-identical in both services. The trap
knowledge lives in a doc, not a module.

Solution: a StateFile module owning XDG path resolution, watch, reload, a parse
hook, `save(value)` with an equality guard, and a loading flag. Pure parsers
move to a plain file a harness can call without singletons.

Acceptance criteria:

- One `stateBase` implementation.
- Calendar and cava settings both load and save through the module.
- Saving a value that equals the current value queues no extra poll.
- Pure parsers are callable without booting a singleton.
- Existing behaviour holds: cava settings survive restart, calendar zones and
  hidden calendars survive restart.
- `scripts/lint.sh` and `scripts/test-panel-logic.sh` pass.

## 02 Collapse the panel registry from a mesh to a list of PanelState adapters

Objective: the registry owns the one-panel rule as data, not as four toggles
that each name the other three panels.

Files: `services/Panels.qml`, `services/PanelState.qml`, the four services'
panel wrappers, `scripts/test-panel-logic.sh` (panel section), ADR 0001
amendment if the placement decision changes.

Problem: the prior fix moved the mesh into one file but did not collapse it.
Each of four `toggle*At` functions lists the other three panels plus
`PowerService.cancel()`. `anyOpen` hardcodes four services. Four services copy
four aliases and three wrapper methods apiece, and the plain `toggleX` wrappers
and the `*LastOutsideCloseAt` aliases have no readers outside their file.

Solution: the registry holds a list of the services' PanelState instances,
closes every non-target entry, and derives `anyOpen` from the list. Delete the
unused aliases and wrapper methods. Keep each service's own arming logic.

Acceptance criteria:

- `Panels.qml` iterates a list instead of naming panels pairwise.
- `anyOpen` derives from the list.
- The unused aliases and `toggleX` wrappers are gone.
- Opening one panel closes the others, and the cava case still hides toasts.
- `scripts/test-panel-logic.sh` is updated to the new shape and passes.
- `scripts/lint.sh` passes.

## Verification

After step 3:

- `git add -A` then `scripts/lint.sh` for types.
- `scripts/lint-review.sh` for style against the baseline.
- `scripts/test-panel-logic.sh`.
- `scripts/test-calendar-fetch.sh` and `scripts/test-calendar-clock.sh`.
- `scripts/smoke-toasts.sh` for the toast layer.
- Update `CONTEXT.md` with any new term. Amend ADR 0001 if the panel rule
  changes shape.
- Remove the plan's completed items or note their status.

## Out of scope

Candidates 05 to 09 from the review: panel body height in PanelShell, the power
action registry, the audio sink policy, the notification clock and expansion,
and the headless gate rework. The Workspaces monitor residual stays as noted.

## Status

All four candidates are implemented on `feat/arch-deepening`, uncommitted as of
2026-09-28.

- 01: `components/NotificationCard.qml` deleted; `NotificationServer.sendReply`
  owns the guard, the resident read, and the dismiss. The gate section names
  `NotificationToast.qml` and `NotificationRow.qml`.
- 03: one `notifications` list; `groups`, `toasts`, and `unreadCount` derived;
  the raw DBus collection private; `isCritical(notification)` with the null
  guard inside.
- 04: `services/StateFile.qml` plus `services/StateParsers.js`; Calendar and
  Cava compose the module. `CalendarService.isValidZoneName` kept as a
  delegate so `CalendarCenter` still resolves it.
- 02: `Panels.panels` list with `closeOtherPanels` and a derived `anyOpen`;
  the dead aliases and plain `toggleX` wrappers removed; ADR 0001 amended.

Rebased onto main `9c46a17` (the dashboard feature) on 2026-09-28:

- The dashboard's four `open*At` entry points now route through the registry
  list instead of writing visibility aliases, and all four services expose
  their dashboard `open*At` beside `panelState`.
- `services/BarVisibilityService.qml`, new in that merge, was ported onto
  `StateFile`, so the state pattern has one home again. `StateFile` gained a
  `loaded` flag: a `property var` map fires `onChanged` at construction, before
  the async load, so a save guard of `loading` alone wrote all-visible defaults
  over the saved file on every restart. The guard is now
  `loading || !loaded`.

Gate results after the rebase: `scripts/check.sh` all gates ok (type lint,
review lint, panel logic, dashboard data, calendar clock, calendar fetch, live
log). Not yet run: a live `quickshell -p` boot, which is the only check for
module resolution of `StateFile` and `StateParsers.js` and for the typed
`panelState` property, plus `scripts/smoke-toasts.sh`.

