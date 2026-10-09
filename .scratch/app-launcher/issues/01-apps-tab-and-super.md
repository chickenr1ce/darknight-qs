# 01: Apps tab opens on Super and launches an app

**Status:** done

**Blocked by:** none

**Blocking:** 02

**What to build:** The thinnest end-to-end path. The Media tab becomes Apps;
`quickshell ipc call dashboard apps` opens the dashboard on Apps with search
focused; a plain A–Z list of installed apps (name only) filters by substring;
Enter or click launches the app and closes the dashboard.

## Acceptance criteria

- [x] `services/DashboardService.qml`: `tabs` carries
  `{ key: "apps", title: qsTr("Apps") }` in place of the `"media"` entry; no
  other `"media"` key changes (the `SettingsService` Media section stays).
- [x] `DashboardService.openAppsAt(screen, centerX: real)` and
  `toggleAppsAt(screen, centerX: real)`: toggle opens on Apps when closed,
  switches to Apps when open on another tab, closes when Apps is showing.
- [x] The `dashboard` `IpcHandler` gains `apps(): string` calling
  `toggleAppsAt` on `MonitorService.focusedScreen()`, returning `"ok"` or
  `"error: no screen"` like `toggle()`.
- [x] New `services/AppService.qml` singleton, registered in
  `services/qmldir`, exposing `entries` from `DesktopEntries.applications`
  sorted by name, and `launch(entry)` calling `entry.execute()` then
  `DashboardService.close()`.
- [x] New `windows/DashboardAppsView.qml`, mounted by
  `windows/DashboardCenter.qml` when `DashboardService.activeTab === "apps"`:
  a search field and a list. The search field takes keyboard focus every time
  the tab becomes visible.
- [ ] Live: from a focused kitty window, the IPC call lets you type into
  search with no click (`PanelShell` is `focusable: true`; if the layer
  surface does not take focus on open, record why and what fixed it).
- [x] The "Coming soon" placeholder still shows for Performance and
  Workspaces; `scripts/test-panel-logic.sh` still passes.
- [x] `scripts/check.sh` passes and `scripts/boot-check.sh <worktree>`
  reports loaded.

## Amendments

- 2026-10-09: The live criterion (type into search with no click) is
  implemented but not verifiable headlessly, so it remains unchecked and
  awaits live verification by the user. `DashboardAppsView` calls
  `forceActiveFocus()` on the search field when the tab becomes visible, when
  the dashboard opens while Apps is the active tab, and on completion.
- 2026-10-09: Added `Globals.appListMaxHeight` (320) to cap the app list the
  way `Globals.settingsBodyMaxHeight` caps the settings body; the panel sizes
  itself from content, so the list needs an explicit height ceiling.
- 2026-10-09: Blessed two deliberate `clip: true` advisories (the search
  input and the list viewport) in `scripts/lint-review-baseline.txt` per
  `docs/dev/CODING_STANDARDS.md`; `scripts/lint-review.sh --update-baseline`
  added only those two lines.
- 2026-10-09: `docs/user/ipc.md` gained the `dashboard apps` row and a
  placement note; `CONTEXT.md`'s Dashboard-tabs glossary entry now names Apps
  in place of Media.

