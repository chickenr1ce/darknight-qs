# 06: Settings → Apps lists hidden apps

**Status:** done

**Blocked by:** 03

**Blocking:** 07

**What to build:** A Settings section where hidden apps come back. Without it
"Hide from launcher" is a one-way door.

## Acceptance criteria

- [x] New section `{ key: "apps", title: qsTr("Apps"), options: [qsTr("Hidden"),
  qsTr("Launcher")] }` in `services/SettingsService.qml`, rendered by a new
  `windows/AppsSettingsView.qml` per `docs/dev/settings-sections.md`
  (`ColumnLayout` root, `filter: string`, rows bound to `matches(label)`).
- [x] One row per hidden id (icon, name, Unhide), built from a shared row
  component rather than a copy; an id with no installed entry shows its raw id
  and can still be unhidden. An empty list shows a one-line hint.
- [x] Unhide calls `AppService.unhide(id)`, which rewrites the `app-launcher`
  state file; the app reappears in the Apps tab at once (quick panel mirror).
- [x] `DashboardService.openSettings("apps")` deep-links the section; the
  Settings search finds it under "Apps", "Hidden", and "Launcher".
- [x] `scripts/test-panel-logic.sh` (or `test-app-launcher.sh`) asserts the
  section key and the view's visibility gate, mirroring the `"media"` checks.

## Amendments (2026-10-09)

- Shared component: the app artwork (icon, else a tinted letter tile, else a
  caller glyph tile) is extracted from `windows/DashboardAppsView.qml` into
  `components/AppIcon.qml`; the launcher row and the new Settings row both
  compose it, so the fallback tile lives once. The settings row itself is a
  view-specific composition of shared primitives (`AppIcon`, `Text`,
  `PillButton`); it duplicates no existing row shape (Media uses
  `SettingsToggleRow`, the Audio per-app row has no icon).
- Stale ids: the ticket overrides the spec's "an id that no longer resolves
  simply does not render" — `AppsSettingsView` shows the raw id and an Unhide
  pill for it, so a removed entry can be cleared from the list.
- `AppLogic.unhide(hiddenIds, id)` drops the id in place, no-op when absent or
  empty; `AppService.unhide(id)` delegates and calls `setState`, so the shared
  `app-launcher` state (and the Apps tab that reads it) updates in one write.
  Covered by node checks in `scripts/test-app-launcher.sh` (`typeof`-safe list
  handling) plus structural greps.
- Live-only, pending `scripts/restart.sh --probe`: right-click Hide in the Apps
  tab, then Unhide in Settings → Apps and see the row vanish and the app
  reappear in the Apps tab; the empty-state hint; the "Apps"/"Hidden"/
  "Launcher" search hit and the `dashboard settings apps` deep link under a
  running shell.
- 2026-10-09: Ticket-06 review fixes. (1) `components/AppIcon.qml` and the
  `components/ContextMenu.qml` header tile paint the letter with the new
  theme-independent `Colors.tileInk` (`Qt.rgba(0, 0, 0, 0.6)`) instead of
  `Colors.background`, so a pastel tile keeps a readable letter under a light
  theme such as haven; the fixed value is the token's definition, the one place
  a hardcoded color is correct. (2) `scripts/test-app-launcher.sh` asserts
  `windows/DashboardAppsView.qml` composes `AppIcon`, feeds it the resolved
  source, and paints no inline letter tile. (3) The same gate runs the awk
  function-body check on `AppService.unhide` and requires its body to call
  `setState`. (4) Hidden-app resolution moves to `AppService.hiddenEntries`;
  `AppsSettingsView` reads it and `SettingsService` concatenates its names into
  the `apps` section `options`, so the per-row `SettingsFilter.matches` is live
  and searching a hidden app's name in Settings finds it.
  `scripts/test-panel-logic.sh` asserts the concat and the view's delegation.
