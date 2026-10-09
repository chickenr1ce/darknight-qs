# 02: Ranked search, Pinned/Recent sections, styled rows

**Status:** done

**Blocked by:** 01

**Blocking:** 03

**What to build:** The list becomes the variant-3 list. An empty query shows
Pinned, Recent, All apps; a query shows one ranked list with highlighted
matches and a "Run “…”" fallback. Rows get icons, generic names, and the
selected rail. Recent and pins persist. Keyboard and mouse selection work.

## Acceptance criteria

- [x] New `services/AppLogic.js` (`.pragma library`) with pure functions
  `rank(entries, query)`, `matchRanges(name, query)`,
  `sections(entries, pinnedIds, recentIds, query)`, and
  `parseState(jsonText)`; `AppService` keeps one-line delegates of the same
  names. Rank order: name prefix, word start, substring, subsequence, then
  `keywords` / `genericName` / `id`; ties by name.
- [x] Empty query: sections Pinned (pin order), Recent (last launched first,
  pinned ids skipped, at most 4), All apps (A–Z, with count). Non-empty: one
  unsectioned ranked list; no match yields one "Run “query”" row that runs
  the query through the terminal prefix.
- [x] Terminal entries (`runInTerminal`) launch as
  `Quickshell.execDetached` of the `AppService` terminal prefix (`kitty -e`)
  plus `entry.command`; others keep `entry.execute()`.
- [x] `StateFile` named `app-launcher` stores
  `{ pinned, hidden, recent }`; a launch moves the id to the front of recent
  (max 8). Missing or corrupt file loads as empty lists.
- [x] Row: icon via `Quickshell.iconPath(entry.icon, true)`, falling back to a
  letter tile in `Colors.appColor(entry.name)`; name with matched ranges in
  `Colors.accent`; generic name in `Colors.textSubtle`; pin star when pinned.
- [x] New `Colors.selection` role: `accentDim`, or a `mixInto(background,
  text, …)` wash when `contrastRatio(accent, background) < 3`. The selected
  row uses it plus a 3px `Colors.accent` rail.
- [x] Keys: ↑/↓, PageUp/PageDown, Tab/Shift+Tab, Enter, Alt+Enter (keep
  open), Ctrl+P (pin toggle), Esc (clear query, then close). Mouse: hover
  selects, click opens, middle-click opens and keeps the dashboard.
- [x] Reduced motion: no row or section animation when
  `Globals.reducedMotion`.
- [x] New `scripts/test-app-launcher.sh`, registered in `scripts/check.sh`:
  node tests of `AppLogic.js` through `tests/qmljs.js` (rank order for
  `"fi"`, `"code"`, `"zzzz"`; sections with pins, recents, and a hidden id;
  corrupt state) plus greps for the delegates and the StateFile name.
- [x] No raw colors, sizes, or durations (`scripts/lint-review.sh` clean).

## Amendments (2026-10-09)

- `sections(entries, pinnedIds, recentIds, query)` keeps exactly the ticket's
  four parameters. Hidden filtering stays in `AppService` (`visibleEntries`),
  so a hidden id is simply absent from `entries` and `sections` skips every
  pinned/recent id that has no entry. The node gate covers both a hidden id
  (`sections/hidden-*`) and a stale pin (`sections/stale-pin`).
- The "Run “query”" row is built in the view when the ranked result is empty,
  not in `AppLogic`: `sections` is pure and has no terminal prefix to run with.
  `AppService.runQuery` owns the `kitty -e sh -c` dispatch.
- Section titles are translated in the view (`qsTr` keyed off the section
  `key`); `AppLogic` returns keys only so it stays pure under node.
- New tokens: `Globals.appIconSize` (28), `Colors.selection` (accentDim, or a
  foreground wash when `contrastRatio(accent, background) < 3`), and the
  `star` / `terminal` glyphs in `config/Icons.qml`.
- `AppService` carries one writable `property var state` (the `{pinned, hidden,
  recent}` object replaced wholesale on each change), which adds one accepted
  `BND-1` line to `scripts/lint-review-baseline.txt`; every other launcher file
  is clean. The other baseline lines are unchanged.
- Live-only, pending `scripts/restart.sh --probe`: actual hover/click/middle-
  click selection, Enter / Alt+Enter / Esc / Tab / PageUp+PageDown / Ctrl+P,
  the terminal launch, and pin/recent persistence across a restart.
- 2026-10-09: Review fixes. The search input's `Keys.onShortcutOverride`
  accepts Escape only while the query is non-empty, so the panel `Shortcut`
  no longer swallows the "clear, then close" path; the view resets query and
  selection via `resetSearch()` whenever Apps becomes visible or the dashboard
  reopens. Section header rows hide `idAppRowContent` (`visible:
  !idAppRow.isHeader`), so no letter tile paints over the caption.
  `visibleEntries`, `recordLaunch`, and `togglePin` moved from AppService into
  `AppLogic.js` as pure functions behind state-passing delegates, with
  `scripts/test-app-launcher.sh` covering hidden filtering and recent/pin
  mutation under node plus greps for the Escape override and header gate.

