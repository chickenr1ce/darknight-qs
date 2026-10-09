# 11: Launcher performance: no freezes, no lag

**Status:** done

**Blocked by:** 10

**Blocking:** 12

Discovered during the third live run (user feedback, 2026-10-09): the shell
still freezes from time to time. The bar is only acceptable with no freezing or
lagging.

## Evidence (gdb stall sampler, 2026-10-09)

The shell ran under `gdb`, with an IPC ping every 250 ms. Whenever a ping
hung for more than 150 ms, the sampler took the main-thread stack, plus the
QML stack via `qt_v4StackTraceForEngine`.

- First open of the Apps tab: 515–550 ms stall. Samples:
  - `AppService.iconForName` → `Quickshell.iconPath(name, true)` →
    `QIconLoader::findIconHelper` → `QFileInfo::exists` (theme lookups on
    disk, one per delegate and binding evaluation);
  - text shaping inside row `RowLayout`s;
  - `QQuickItemView::destroyingItem`: `resetSearch` replaces the JS-array
    model, which destroys and rebuilds every delegate.
- Idle stalls of 500–650 ms, plus one 3.37 s IPC hang on the earlier
  instance. Samples: `QQmlPropertyCapture::captureBindableProperty`,
  `QObjectWrapper::getProperty`, `ArrayData::sort`, string conversion, and GC
  marking. That is JS bindings reading `DesktopEntry` QObject properties
  thousands of times and sorting.

## Causes in the code

1. `AppService.entries` holds the raw `DesktopEntry` QObjects. Every binding
   downstream reads QObject properties per entry, and each read is captured as a
   binding dependency:
   - `compareNames` reads `.name` twice per comparison;
   - `score` reads name, genericName, keywords and id;
   - `entryKeys` reads startupClass and id;
   - `visibleEntries`, `sections`, `rank`, `runningMap` and `hiddenEntries`
     do the same.

   `sections()` re-sorts all entries by name on every evaluation, even though
   `entries` is already sorted.
2. `runningMap` loops entries × toplevels and recomputes `entryKeys` and
   `normalizeKey` for every pair on every toplevel change.
3. Icon lookups run `QIconLoader` against the disk on every delegate
   creation. Nothing caches them.
4. `DashboardAppsView.listRows` is evaluated even while the dashboard is
   closed or on another tab, and the hidden `ListView` keeps live delegates
   that re-evaluate on every running-window or pin change.
5. Each delegate builds the header layout *and* the full app row, including
   four inline `IconButton`s, a separator, the kill tooltip and the running
   dot, even though only one row at a time shows the inline actions. Every
   keystroke resets the model, so all visible delegates are rebuilt.

## What to build

- **Plain records.** `AppService` snapshots `DesktopEntries.applications.values`
  into plain JS records once per change of that list, in a pure
  `AppLogic.makeRecords(rawList)`-style helper fed plain values.
  - Fields: `id`, `name`, `nameLower`, `genericName`, `meta` (lowercased
    genericName + keywords + id haystack), `icon`, `keys` (the `entryKeys`
    result, precomputed), `runInTerminal`, `command`, and `entry` (the
    QObject, used only for `execute()` and actions).
  - The snapshot is sorted once. Every pure function (`rank`, `score`,
    `sections`, `visibleEntries`, `resolveHidden`, `menuItems`, …) takes
    records and never touches a QObject.
  - `sections()` reuses the presorted order instead of sorting again.
  - All existing node tests keep passing; update their fixtures to records
    where the signature changes.
- **Running windows.** `runningMap` builds a `normalizedClass → windowCount`
  map once per toplevel change. Each record then sums its precomputed `keys`
  by hash lookup. Keep the exact-match semantics of `windowMatches`: a window
  counts once per entry even if several keys match. Keep that function for
  `windowsFor`.
- **Icon cache.** `iconForName` caches resolved paths in a plain JS object
  (not a reactive property), keyed by icon name, so each icon name hits
  `QIconLoader` once per session. Clear the cache when the snapshot changes,
  or when the theme changes if there is a cheap signal for that. Records
  carry the icon *name*; delegates resolve it through the cache.
  `AppIcon`'s `Image` gets `asynchronous: true` and `cache: true`.
- **Idle cost.** While the Apps tab is not visible (dashboard closed or
  another tab), `listRows` returns `[]` without calling `AppService.sections`,
  so nothing in the launcher re-evaluates per window event. Opening the tab
  computes the rows once. `resetSearch` must not cause a second rebuild when
  the query is already empty.
- **Lighter delegates.**
  - The header and the app row are separate subtrees. Only the one in use is
    created: a `Loader` per kind, or `DelegateChooser` if it works with this
    JS-array model on Qt 6.12. Verify it before choosing.
  - The inline action cluster (Focus, Kill, separator, Pin, ⋯, kill tooltip)
    is created only while the row is `actionsActive`, through a `Loader`. The
    fixed trailing width stays reserved, so nothing reflows. The running dot
    and count, and the pinned star, stay as light always-on items.
  - Set `reuseItems: true` on the `ListView` if it measurably helps. Reset
    per-row state such as `killTipShown` on `ListView.onReused`.
  - Every behavior from tickets 01–10 stays intact: keyboard selection,
    Ctrl+N, the context menu, hover wash, inline actions, the Run row, the
    empty note, the scrollbar and SmoothWheel.
- **Measurement.** `dev/DevProbe.qml` gains an `appsBench` function that
  returns JSON timings in ms. It covers:
  - the cold `AppService` snapshot rebuild;
  - `listRows` with an empty query;
  - five successive one-character query extensions ("f", "fi", "fir",
    "fire", "firef"), each followed by `idAppsList.forceLayout()` so delegate
    creation is included;
  - clearing the query;
  - a forced `runningMap` recompute.

  Use whatever access path DevProbe already uses for surfaces. If the Apps
  view is not reachable from DevProbe, add a minimal registration, as
  `DevGeometry` does. The bench must leave the query empty when it returns.
  Document the function in `docs/dev/debugging-quickshell.md`'s Dev probe
  list.

## Acceptance criteria

- [x] Records snapshot, single sort, no QObject property reads in any pure
  function, and node tests updated and passing.
- [x] `runningMap` is keyed by hash; the matching semantics are unchanged
  (the node tests prove it, including the Baldur's Gate 3 / Unity case).
- [x] Icon path cache; `AppIcon` loads asynchronously.
- [x] Hidden-tab idle: `listRows` is `[]` while the tab is not visible; a
  structural test asserts the gate.
- [x] Delegates: header and app row are created exclusively; inline actions
  are created only for the active row; no reflow on hover or selection.
- [x] `devprobe appsBench` exists and is documented.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [x] Live (orchestrator, gdb stall sampler): under 50 ms for each keystroke
  step and the query clear in `appsBench`; first open of the Apps tab under
  100 ms; no stall over 100 ms while idle with windows opening and closing.

## Amendments

- 2026-10-09 — **Records.** `AppService.entries` is now `root.buildRecords()`,
  which reads `DesktopEntries.applications.values` once per list change, maps
  each entry to plain values (scalar fields, a plain action descriptor list,
  and the `entry` QObject), and feeds `AppLogic.makeRecords(list)`. A record
  is `{ id, name, nameLower, genericName, meta, icon, keys, runInTerminal,
  command, actions, entry }`; `meta` is the lowercased
  `genericName + keywords + id` haystack and `keys` is the precomputed
  `entryKeys` result. `makeRecords` sorts once; `sections` for an empty query
  reuses that order instead of sorting again (`rank('')` still sorts for
  standalone callers, but `sections` never calls it for an empty query).
  `score`/`compareNames` read `nameLower`/`meta` with raw-object fallbacks, so
  the node fixtures were converted to records where the signature changed and
  the existing intent of every test is kept. The view's row object now carries
  `record` (the plain record) instead of `entry`; every consumer —
  `DashboardAppsView`, the `ContextMenu` header, `AppsSettingsView`,
  `focusWindows`/`killWindows`/`windowsFor`, `launchOnWorkspace`,
  `copyCommand`, `menuItems`, `launchAction` — was adapted. `AppService`
  keeps the record's `entry` QObject for `execute()` and desktop actions only.
- 2026-10-09 — **Running windows.** `AppLogic.runningCounts(records,
  toplevelClassLists)` builds a `normalizedKey → record indexes` hash once and
  walks the toplevel class lists, incrementing each matching record once per
  window. That keeps the exact `windowIndexesFor` semantics: a window counts
  once per entry even when several of its sources equal several of the entry's
  keys (a plain `class → count` map then summing keys would double-count that
  case). The Baldur's Gate 3 / Unity case is a node check
  (`run/bg3-no-unity`). `AppService.runningMap` delegates to it and is
  invalidated through `runningMapRevision`, which `rebuildRunningMap()` bumps
  for the bench.
- 2026-10-09 — **Icons.** `AppService.iconCache` is a plain JS object property;
  `iconForName` returns a cached path on hit and stores the
  `Quickshell.iconPath` result on miss. Member writes do not notify, so the
  cache is not reactive; `onEntriesChanged` reassigns the whole object to
  clear it when the snapshot changes. Verified with a throwaway headless shell
  that a binding reading a `property var` cache and writing a member evaluates
  once with no binding loop. `AppIcon`'s `Image` gained `asynchronous: true`
  and `cache: true`.
- 2026-10-09 — **Idle cost.** `DashboardAppsView.listRows` returns `[]` before
  it reads `AppService.sections` while `root.launcherActive` is false
  (`root.visible && DashboardService.dashboardVisible`), so the launcher does
  no work while the dashboard is closed or on another tab. The existing
  `resetSearch` non-empty guard already avoids a second rebuild when the query
  is empty.
- 2026-10-09 — **Delegates: Loader, not DelegateChooser.** `DelegateChooser`
  is available on this Qt (`import QtQml.Models`, since 6.9) but it dispatches
  on a named model role; a JS-array model only exposes `modelData`/`index`, so
  it cannot select on the row `kind`. Each delegate therefore keeps a `Loader`
  per kind (`active: idAppRow.isHeader` / `active: !idAppRow.isHeader`) with
  the components declared inline inside the delegate, which is what the Loader
  docs require for the delegate's `index`/`modelData` context (a file-scope
  component would lose them). Verified on this Qt with a throwaway headless
  shell that a nested inline component resolves the delegate id, `index`, and
  `modelData`, and that the `Loader.item?.implicitHeight` height pattern does
  not loop. The inline action cluster (Focus, Kill, separator, Pin, ⋯, kill
  tooltip and its timer) moved into a third `Loader` gated on
  `idAppRow.actionsActive`, inside the row `MouseArea` so its geometry and the
  row click routing are unchanged.
- 2026-10-09 — **Reserved width.** The trailing slot reserves
  `root.actionsWidth`, computed from tokens
  (`4 * (uiCaptionSize + 2 * iconButtonPadding) + hairlineHeight + 4 *
  listSpacing`) rather than `idAppRowActions.implicitWidth`, so the width is
  fixed while the actions `Loader` is unloaded and hover/selection never
  reflows. The click-on-actions test uses `idAppRow.actionsX` for the same
  reason.
- 2026-10-09 — **`reuseItems`.** Set `reuseItems: true` on the list; it is the
  main win when every keystroke replaces the model. It was not measured live
  (the bench is for the orchestrator), so this is a reasoned default, not a
  measured one. Per-row state is reset on reuse (`ListView.onReused` clears
  `killTipShown`, as does `onActionsActiveChanged` when the row deactivates).
  The view's `Component.onCompleted` was removed — with `reuseItems` the style
  linter (correctly) distrusts it, and it only registered the probe and
  focused search; `DashboardCenter` now calls the new
  `DashboardAppsView.registerProbe()` from its own completion, and the
  visible/dashboard-visible handlers cover the focus.
- 2026-10-09 — **Bench.** `DashboardAppsView.bench()` times the cold
  `AppService.buildRecords()` snapshot, `listRows` with an empty query, the
  five query extensions `f`…`firef` (each followed by
  `idAppsList.forceLayout()`), the query clear, and a forced
  `runningMap` recompute via `rebuildRunningMap()`; it ends with an empty
  query. `DevProbe.appsBench` opens the Apps tab if needed and reaches the
  view through the new `dashboard.apps` `DevGeometry` registration. Documented
  in `docs/dev/debugging-quickshell.md`.
- 2026-10-09 — The style baseline gained one `services/AppService.qml BND-1`
  line for the deliberate `property var iconCache` (the same accepted pattern
  as the existing `state` property). `scripts/check.sh` prints all gates ok;
  `scripts/boot-check.sh <worktree>` reports loaded with no TypeError,
  ReferenceError, binding-loop, or assignment warnings. The Live criterion
  stays open for the orchestrator's gdb stall sampler.
- 2026-10-09 — Verification beyond the gate: a throwaway copy of the worktree
  (in `/tmp`, separate from the live shell) instantiated the real
  `DashboardAppsView` with the tab gate forced open, so the actual delegate
  subtrees ran. 150 app rows loaded with no `ReferenceError`/`TypeError`
  (this caught a real bug: the delegate root binding referenced
  `idAppRowMouse`, an id inside the content component, which is out of scope;
  it now reads a delegate-scoped `rowHovered` flag set by the row MouseArea).
  The copy's `bench()` reported `snapshotMs=2`, `emptyMs=5`,
  `stepsMs=[16,8,6,3,2]`, `clearMs=5`, `runningMapMs=0` — each step under
  50 ms. Those numbers are from a throwaway instance, not the live panel, so
  the Live criterion stays with the orchestrator.
- 2026-10-09 (orchestrator, live): Measured on the running shell under the
  gdb stall sampler (IPC ping every 250 ms; stall = a ping slower than
  250 ms). `devprobe appsBench` gave
  `{"snapshotMs":1,"emptyMs":10,"stepsMs":[24,34,7,4,2],"clearMs":10,"runningMapMs":1}`;
  every keystroke step and the clear are under 50 ms. Opening the Apps tab
  three times answered IPC in 26–30 ms, with no stall logged. Four
  self-closing kitty windows opened and closed on workspace 9, with the tab
  both closed and open; no stall was logged. Before this ticket the same
  sampler logged 5.7–6.7 s stalls whose QML frames were `compareNames`,
  `AppLogic.sections`, and the `AppService.entries` sort.
- 2026-10-09 — **Review fixes.** Six findings from the ticket 11 review:
  1. the idle gate no longer greps the file for `DashboardService.dashboardVisible`
     (an unrelated `Connections` handler satisfied it); it extracts the
     `launcherActive` declaration line and requires both `root.visible` and
     `DashboardService.dashboardVisible`, and requires `listRows` to return an
     empty list on `!root.launcherActive` before `AppService.sections`;
  2. the delegate check requires `info.record` and forbids `info.entry`, and a
     structural check requires `listRows` app rows to carry `record:
     section.items[i]`;
  3. the pure-logic hash maps indexed by user-derived ids
     (`runningCounts` `byKey`/`hit`/`out`, `sections` and `resolveHidden`
     `byId`) are `Object.create(null)`, so an id like `org.example.constructor`
     (whose last key segment is `constructor`) no longer hits `Object.prototype`
     and throws `byKey[key].push is not a function`; node tests cover
     `org.example.constructor` and `__proto__`;
  4. a desktop action descriptor carries its original index
     (`buildRecords` sets `index: j`, `makeActions` preserves it, `menuItems`
     emits `actionIndex` from it) so a menu index maps back to the uncompacted
     `entry.actions[index]` even when a null action was dropped; a node test
     covers a sparse actions list;
  5. `rowHovered` is now a `Binding` on the row `MouseArea`'s `containsMouse`
     inside the content component, so a reused row under a stationary pointer
     keeps its hover; `ListView.onReused` resets only `killTipShown`, and the
     gate asserts the reset is inside that handler and that the binding exists;
  6. `bench()` returns `{"found": false, "reason": ...}` when the launcher is
     inactive, and `DevProbe.appsBench` does the same when `probeScreen` is
     null or the view is unregistered, restoring the dashboard's prior
     open/closed state and tab when it opened the Apps tab. Documented in
     `docs/dev/debugging-quickshell.md`.
  Each gate fix was verified by mutation (mutate → `app-launcher FAIL` → revert):
  the declaration check, the `return rows` check, `info.entry`, the
  prototype-less `byKey`, the dropped `index: j`, the `onReused` hover reset,
  the missing hover binding, and the missing bench reason each fail the gate.
  `scripts/check.sh` prints all gates ok; `scripts/boot-check.sh <worktree>`
  reports loaded.
