# 04: Running apps, inline Focus / Kill / Pin / ⋯

**Status:** done

**Blocked by:** 03

**Blocking:** 07

**What to build:** The launcher knows which apps have windows. Rows show a
running dot and window count. The hovered or selected row shows the inline
actions: Focus, Kill, Pin/Unpin, ⋯. The menu gains Focus window and Kill.

## Acceptance criteria

- [x] `AppLogic.js` gains `entryKeys(entry)` (`startupClass`, `id`, the id's
  last reverse-DNS segment, normalized) and `classMatches(source, key)`;
  `services/HyprlandFocus.qml` delegates its `classMatches` to it so one rule
  set serves both. Its existing behavior and tests are unchanged.
- [x] `AppService.windowsFor(entry)` returns the `Hyprland.toplevels` whose
  class sources (Wayland `appId` included, since `lastIpcObject` is empty
  under Lua IPC) match the entry's keys; `runningCount(entry)` is its length,
  reactive to toplevels opening and closing.
- [x] Row at rest: running dot plus count when `runningCount > 0`, pin star
  when pinned. Hovered or selected row: those swap for Focus, Kill, Pin/Unpin,
  ⋯ buttons composed from `components/IconButton.qml`.
- [x] Focus and Kill stay laid out but dim and inert when the app has no
  window; the row never reflows between rest, hover, and selected (fixed
  trailing width).
- [x] Focus: `HyprlandFocus.focusByTokens(entryKeys(entry))`, then close the
  dashboard. Kill: `wayland.close()` on every window from `windowsFor`,
  graceful, no confirm; the dashboard stays open and the row updates when the
  windows go. Kill hovers in `Colors.danger`; its tooltip names the window
  count.
- [x] ⋯ opens the ticket-03 menu anchored under the button.
- [x] Menu gains "Focus window (N open)" after Open, and "Kill <name>" as the
  last, danger-styled item, both only for running apps.
- [x] `scripts/test-app-launcher.sh`: node tests of `entryKeys` and matching
  (reverse-DNS id, `startupClass` vs `appId`, no false match on a generic
  prefix like `org`).
- [ ] Live: Focus from another workspace lands on the app's window with the
  cursor restored; Kill on a throwaway app (e.g. two `mpv` windows) closes
  both.

## Amendments

- 2026-10-09: The Focus box is ticked for the implemented behavior, but the
  call order is `DashboardService.close()` then
  `HyprlandFocus.focusByTokens(keys)` — the order `DashboardPlayerBlock.qml`
  already uses. `HyprlandFocus` waits on `PanelGrab.closing`; focusing first
  dispatches while the dashboard's grab is still active, and the compositor's
  restore on release would override it. The ticket's wording is read as the
  outcome (focus the app, close the dashboard).
- 2026-10-09: The Live bullet stays unchecked. It needs a real Hyprland
  session and throwaway windows; no window was closed during this change.
  `scripts/boot-check.sh` confirms the config loads and no binding loop fires.
- 2026-10-09: `tests/qmljs.js` gained a minimal `String.prototype.arg` so the
  node gate can exercise the new `qsTr("…%1").arg(x)` menu labels; the loader
  comment had already flagged the single-argument `qsTr` stub as insufficient.
- 2026-10-09: The launcher now matches windows with a strict rule, not
  `HyprlandFocus.classMatches`. `AppLogic.entryKeys` adds the id's last
  dot-separated segment only for a reverse-DNS id (`org.mozilla.firefox` →
  `firefox`), and only when the segment is ≥ 3 chars, non-numeric, and not in
  `ENTRY_KEY_STOPLIST` (`app`, `desktop`, `client`, `gui`, `handler`,
  `launcher`, `bin`, `main`); `AppLogic.windowMatches(entryKeys, classSources)`
  matches only on normalized exact equality, and
  `AppLogic.windowIndexesFor(entryKeys, classLists)` returns the matched
  indexes that `AppService.runningMap` / `windowsFor` consume for the running
  count, Focus and Kill. This supersedes the criteria's "same rules as
  `HyprlandFocus`" wording for the launcher, without editing the criteria text:
  `classMatches` and `HyprlandFocus.focusByTokens` keep their loose behavior
  for notifications, tray and the player. The loose rule let a no-
  `StartupWMClass` entry such as `Baldur's Gate 3` (key `3`) claim Unity editor
  windows, so Kill could close unrelated apps.
- 2026-10-09: Focus no longer calls `HyprlandFocus.focusByTokens(entryKeys)`.
  `AppService.focusWindows` takes the windows from its own `windowsFor`, picks
  a currently `activated` one (else the first), then
  `DashboardService.close()` and `HyprlandFocus.focusAddress(address)`, so
  Focus and Kill agree on a window set. `focusAddress` enqueues the
  `0x`-prefixed address through the existing `requestQueue` / `pumpQueue`
  path, keeping the `PanelGrab.closing` wait and cursor restore;
  `focusByTokens` is unchanged.
- 2026-10-09: With the workspace submenu present the menu order now follows
  the spec (`spec.md` line 31): Open, Open on workspace ▸, Open, keep
  dashboard, Focus window (N open), then actions, Pin/Unpin, Hide, Copy, Kill.
  Focus window follows "Open, keep dashboard" rather than sitting directly
  after Open; the criteria text above is unchanged. The
  `menu/focus-after-open` node test now asserts the full item order both with
  and without workspace items.
