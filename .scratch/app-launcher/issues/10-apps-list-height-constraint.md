# 10: Apps list never gets a bounded height

**Status:** done

**Blocked by:** 08

**Blocking:** none

Discovered during the second live run (user feedback, 2026-10-09): scrolling
does nothing on the Apps tab, and the shell stutters or freezes.

**Cause:** `windows/DashboardAppsView.qml`'s root `ColumnLayout`
(`idAppsLayout`) is anchored top/left/right only, so its height is its
implicit height, and `windows/DashboardCenter.qml` mounts the view with
`Layout.fillWidth` but no `Layout.fillHeight`. `idAppsListSlot` asks for
`Layout.preferredHeight: idAppsList.contentHeight` and nothing ever
constrains it, so the `ListView` is as tall as all of its rows. `PanelShell`
clamps the card to `panelMaxHeight` and clips the rest. The result:
`contentHeight == height`, so the wheel has nothing to move and the shared
`ScrollBar` stays hidden (`size == 1`). The `ListView` also instantiates
every delegate (about 180 apps, each with an icon lookup and bindings) and
rebuilds them on every query change and every window open or close. That is
the stutter.

**What to build:** The Apps view fills the height `PanelShell` gives it. The
list slot takes the space left after the search field and header, so the list
overflows, scrolls, shows the bar, and only instantiates visible delegates.
The card still grows downward to fit short lists, up to `panelMaxHeight`.

## Acceptance criteria

- [x] `windows/DashboardCenter.qml` mounts `DashboardAppsView` with
  `Layout.fillHeight: true`.
- [x] `windows/DashboardAppsView.qml`'s `idAppsLayout` fills the root
  (`anchors.fill: parent`), so `idAppsListSlot` (`Layout.fillHeight`) shrinks
  to the space that is left. The root's `implicitHeight` stays content-driven,
  so a short list (a narrow query) still shrinks the card.
- [x] The context menu still clamps inside the card. It is mounted in the view,
  so it now sees the bounded height.
- [x] `DevGeometry.register("dashboard.apps.list", idAppsList)` (permanent
  one-liner, per `docs/dev/debugging-quickshell.md`) so the list height can
  be read live.
- [x] `scripts/test-app-launcher.sh` asserts both: the `fillHeight` mount and
  the filled `idAppsLayout` (no top/left/right-only anchor block).
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [ ] Live: the list height (`devprobe geom dashboard.apps.list`) is below its
  full content with an empty query; the bar shows; one wheel notch glides;
  typing has no hitch.

## Amendments

- 2026-10-09: Added `Layout.fillHeight: true` to the `DashboardAppsView` mount
  in `DashboardCenter.qml`, so the view fills the height `PanelShell` gives it
  instead of sitting at its content height. Replaced `idAppsLayout`'s
  top/left/right-only anchor block with `anchors.fill: parent`; the root's
  `implicitHeight` stays bound to `idAppsLayout.implicitHeight`, so a short
  list still shrinks the card while a long list leaves `idAppsListSlot`
  (`Layout.fillHeight`) to take the leftover space and clip into a scroll.
  Registered `dashboard.apps.list` with `DevGeometry.register` in the view's
  existing `Component.onCompleted` (extended to a block; added
  `import qs.dev`). The `ContextMenu` mount is `anchors.fill: parent`, so it
  now sees the bounded height and keeps clamping. `scripts/test-app-launcher.sh`
  gains section 4j, which extracts the mount and the layout and asserts the
  fill height and the filled layout. `scripts/check.sh` prints all gates ok and
  `scripts/boot-check.sh` reports loaded. The Live check stays open.
- 2026-10-09: Review fixes. Gate 4j now matches only `idAppsLayout`'s own
  (8-space) properties: it requires the exact `anchors.fill: parent` line and
  rejects an edge-by-edge anchor in either form, block or inline. The old
  grep matched nested children and so passed even after the fill was
  reverted. A mutation to `anchors.top: parent.top` now fails the gate. A
  stray `shell.qml` newline, left by a timed-out `scripts/reload.sh`, was
  dropped. Live half of the last criterion: with the devprobe on, the running
  shell reports `dashboard.apps.list` at 1054 px on the 1440 px monitor
  (0.8 cap minus chrome), down from the full content height. The wheel,
  scrollbar, and typing smoothness still need a real pointer.
