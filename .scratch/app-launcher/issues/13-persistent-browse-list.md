# 13: Clearing the query must not rebuild the list

**Status:** done

**Blocked by:** 11

**Blocking:** none

## Evidence

Live `devprobe appsBench` after ticket 11's review fixes (2026-10-09), six
runs:

| Step | Time |
| --- | --- |
| `emptyMs` (build the empty-query list) | 60–70 ms |
| `clearMs` (from "firef" back to empty) | 59–74 ms |
| first keystroke "f" | 21–25 ms |
| later keystrokes | 4–14 ms |

The empty-query list has about 20 visible rows, so every rebuild of it pays
about 3 ms per delegate. Clearing the query (Esc, or backspacing to empty)
blocks the main thread for about 65 ms, over the 50 ms budget from ticket 11,
and shows as a hitch. The JS-array model resets on every change, so nothing
from the results list carries over.

## What to build

Two `ListView`s in `idAppsListSlot` share one delegate `Component` (declared
once; no copied delegate):

- **Browse list:** the empty-query sections (Pinned, Recent, All). Its model
  depends only on records, pinned, recent and hidden, never on `query`.
  While the Apps tab is active it stays alive across queries. A clear then
  only flips visibility and restores the browse list's selection and scroll.
- **Results list:** ranked results and the Run row for a non-empty query.
  It is rebuilt per keystroke, which is fine at the current cost. Its model
  is `[]` while the query is empty.

Requirements:

- Exactly one list is visible. `root.activeList`, the active rows and the
  active selection drive everything that today touches `idAppsList`:
  - keyboard navigation, `ensureVisible`, Enter and Ctrl+N;
  - menu opening, typed-text forwarding and `appCount`;
  - the empty note;
  - the slot's `Layout.preferredHeight` (the active list's `contentHeight`).
- Selection moves to the first result on each query change, as today. On a
  clear, the browse list shows its first row selected, scrolled to the top,
  the way the tab looks when it opens.
- Each list has its own shared `ScrollBar` and its own `SmoothWheel`. The
  per-scrollable gate in `scripts/test-panel-logic.sh` (section 25) must
  still pass.
- The idle gate stays: both models are `[]` while `launcherActive` is false.
- `DevGeometry` keeps `dashboard.apps.list`, now the active list (or
  register both lists plus an alias). `appsBench` still works, and its
  `clearMs` now measures the visibility flip.
- Per-delegate cost: the name `Text` uses `Text.StyledText` only when there
  is markup to show (non-empty query); otherwise `Text.PlainText`. Drop
  per-row work that has no visible effect. Do not change behavior or visuals.
- Every behavior from tickets 01–12 stays intact, including the footer and
  the reuse and hover fixes.

## Acceptance criteria

- [x] One shared delegate `Component` and two `ListView`s, with the browse
  model independent of `query`.
- [x] Every interaction routes through the active list; none references a
  specific list by mistake.
- [x] `scripts/test-app-launcher.sh` asserts:
  - the browse model has no `query` dependency;
  - the results model is `[]` while the query is empty;
  - both models are gated by `launcherActive`;
  - there is exactly one delegate `Component`.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded with no new warnings.
- [x] Live (orchestrator): in `appsBench`, `clearMs` is under 10 ms, every
  keystroke step is under 50 ms, and `emptyMs` (first open) is under
  100 ms.

## Amendments

- 2026-10-09 — **Pure row building.** `AppLogic.js` gains
  `sectionRows(sections, runQuery)`, `browseRows(entries, pinnedIds,
  recentIds)` and `resultRows(entries, pinnedIds, recentIds, query)`; the row
  loop moved out of the view verbatim (headers carry `kind/key/count/rowIndex/
  appIndex: -1`, app rows carry `record`, and the Run row appends only when a
  non-empty trimmed query matched nothing). `AppService` delegates both through
  one-line functions over `visibleEntries(entries, hidden)`. `resultRows`
  returns `[]` for a blank query before calling `sections`, so the empty gate
  is pure and node-testable.
- 2026-10-09 — **Two lists, one delegate.** `DashboardAppsView` declares
  `browseRows` (gated only by `launcherActive`; calls `AppService.browseRows()`)
  and `resultRows` (gated by `launcherActive` and `root.query.trim() !== ""`;
  calls `AppService.resultRows(root.query)`). `idAppsListSlot` holds
  `idAppsBrowseSlot` and `idAppsResultSlot`, each an `anchors.fill` Item with
  its own `ListView` (`idAppsBrowseList` / `idAppsResultList`), its own attached
  `ScrollBar`, and its own `SmoothWheel` sibling; exactly one slot is visible
  (`!root.querying` / `root.querying`), so the hidden wheel cannot intercept the
  visible list's wheel. The delegate body is now a single `Component { id:
  idAppRowDelegate }` used by both lists; inside it the view is reached through
  the attached `ListView.view` (`readonly property var listView`), so
  `selected`, `width`, hover selection, and click selection follow whichever
  list instantiated the row. `idAppsList` is gone (the `grep -qnE
  '\bidAppsList\b'` gate proves it).
- 2026-10-09 — **Active-list abstraction.** `root.querying`, `root.activeRows`,
  `root.activeList`, and `root.activeSmoothWheel` drive `appCount`,
  `clampSelection`, `selectedRow`, `moveSelection`, `ensureVisible`,
  `openMenuForSelection`, and the empty note, so keyboard navigation, Enter,
  Ctrl+N, typed-text forwarding, and menu opening all follow the active list.
  `onQueryChanged` selects the first result when querying, and on a clear
  selects browse row 0 and `positionViewAtBeginning()`; `resetSearch` does the
  same on open. The slot's `Layout.preferredHeight` is
  `root.activeList.contentHeight`.
- 2026-10-09 — **Per-delegate cost.** The row name is
  `Text.PlainText` in browse mode and `Text.StyledText` only when it has
  markup (`idAppRow.useMarkup`, i.e. the Run row or a non-empty query), reading
  the raw `record.name` in plain mode so no escaped entity is shown; the
  `AppService.markup` path is unchanged for results.
- 2026-10-09 — **Probe and bench.** `registerLists()` registers
  `dashboard.apps.browseList`, `dashboard.apps.resultList`, and
  `dashboard.apps.list` (the active list, refreshed on `onQueryingChanged`),
  with `dashboard.apps` unchanged. `bench()` forces the browse layout on the
  empty/clear steps and the result layout on each keystroke, so `clearMs` now
  measures the visibility flip back to the persistent browse list.
  `docs/dev/debugging-quickshell.md` describes the new shape.
- 2026-10-09 — **Verification.** `scripts/check.sh` prints all gates ok;
  `scripts/boot-check.sh <worktree>` reports loaded, and a throwaway boot's
  qslog has no TypeError, ReferenceError, assignment, or binding-loop
  signatures. The new gates were mutation-verified (mutate → `app-launcher
  FAIL` → restore): a `query` reference in `browseRows`, a dropped
  `root.query.trim() === ""` gate, a dropped browse `launcherActive` gate, a
  result list with a copied delegate, a stray `idAppsList`, a clear branch
  without `positionViewAtBeginning`, an always-`StyledText` name, an
  empty-query `resultRows` that returns rows, and a `browseRows` that loses the
  Pinned/Recent sections each fail. The `ListView.view` attached-property
  semantics (read `selectedIndex`/`width`, write `selectedIndex` through a `var`
  holding the view, shared `Component` delegate, `ListView.onReused`) were
  verified on Qt 6.12 with an offscreen `qmltestrunner` case. The Live
  criterion stays open for the orchestrator's `appsBench`.

- 2026-10-09 (orchestrator, live): four `appsBench` runs gave `clearMs`
  0–2 ms (it was 59–74 ms), keystroke steps 2–25 ms, and `emptyMs` 0–2 ms.
  Opening the tab, timed as IPC open plus ping minus two ~21 ms IPC round
  trips, cost about 30 ms warm and about 95 ms on the first open after a
  reload. The one `ReferenceError: idAppsList` in the live log, at
  18:58:09, came from the agent's stray-`idAppsList` mutation; the file has
  no `idAppsList` left.
- 2026-10-09 — **Review fixes.** `onQueryChanged` and `registerLists` derive the
  mode from `root.query.trim() !== ""` locally instead of the stale
  `root.querying`/`root.activeList` (Qt 6.12 runs the handler before the derived
  binding refreshes), so the first keystroke selects the results list and a clear
  selects and scrolls the browse list; the clamp is deferred through
  `Qt.callLater` so it lands on the refreshed active list. Section 4m now pins
  the `querying` definition, the three `active*` ternaries, the two visibility
  gates, the local derivation (and rejects `root.querying`/`root.activeList` in
  the handler), and the local `registerLists` derivation; each was
  mutation-verified (hard-wire `activeList`, swap a ternary, swap a visibility
  gate, read `root.querying` in the handler, register `root.activeList`) →
  `app-launcher FAIL` → restored. `onQueryingChanged` stops both `SmoothWheel`s
  on a mode flip, and entering a query calls
  `idAppsResultList.positionViewAtBeginning()`. `tests/app-launcher-mode.qml`
  runs under `/usr/lib/qt6/bin/qmltestrunner` (offscreen, skipping when the Qt 6
  runner is absent) inside `test-app-launcher.sh`, mirroring the handler pattern;
  a handler that reads `root.querying` fails it.
