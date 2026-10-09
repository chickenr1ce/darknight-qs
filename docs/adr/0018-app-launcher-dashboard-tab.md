# ADR 0018: the app launcher is a dashboard Apps tab

Date: 2026-10-09. Feature: app-launcher (plan 09).

## Context

Apps launched from a rofi script bound to Super. It looks foreign next to the
native panels, knows nothing about the active theme, and has no mouse story
beyond click-to-launch: no pin, hide, focus, close, or desktop actions without a
terminal.

The dashboard's Media tab was a "Coming soon" placeholder. The player already
lives on the Dashboard page, so the tab held nothing. The dashboard is an
attached card with a concave junction (ADR 0005) and an established focus and
cursor path (`services/HyprlandFocus.qml`), and it lives outside
`services/Panels.qml`, so a quick panel can open beside it.

## Decision

The launcher is the dashboard's Apps tab, built from
`windows/DashboardAppsView.qml`, `services/AppService.qml`, and the pure
`services/AppLogic.js`. It replaces the Media row tab. It is not a standalone
window.

- **Why a tab.** One surface. The launcher reuses the card's junction, its
  search and list machinery, the context menu that fits inside the card, reduced
  motion, and the `HyprlandFocus` path that already waits for the dashboard's
  grab to release. The Media tab was already free, so the launcher costs no new
  surface. As a trade-off, there is no launcher beside the dashboard, and the
  Super bind has to deep-link (`quickshell ipc call dashboard apps`) rather than
  toggle a window of its own.
- **Interface, variant 3.** The design plan's "Inline actions" variant: one
  full-width list, no side pane, no category pills. An empty query shows
  Pinned, then Recent (unpinned, at most 4), then All apps A-Z. A query shows
  one ranked list with the matched letters highlighted; no match offers a
  `Run "query"` row. The selected or hovered running row swaps its dot, count,
  and star for inline Focus, Kill, Pin/Unpin, and `⋯` buttons; Focus and Kill
  stay laid out but dim and inert without a window, so the row never reflows.
  Workspaces are not an inline button: Ctrl+1…N and the menu's "Open on
  workspace" submenu cover them.
- **Entry points.** The dashboard `IpcHandler` gains `apps()`, which opens on
  Apps when closed, switches to Apps when open on another tab, and closes when
  Apps is showing. The Super bind is `quickshell ipc call dashboard apps` in the
  user's Hyprland config. Clicking the bar title still opens the Dashboard page.
- **Data and persistence.** `AppService` reads `DesktopEntries.applications`
  (which already excludes Hidden and NoDisplay). One `StateFile` named
  `app-launcher` holds `{ pinned, hidden, recent }` behind the load guard;
  recent keeps the last 8 launches. A hidden id keeps its place in the file,
  leaves every launcher section, and is listed in Settings → Apps for unhiding.
  An id that no longer resolves shows its raw id there and can still be
  unhidden.
- **Strict window matching.** An entry matches a `Hyprland.toplevel` when
  `AppLogic.entryKeys` (the `startupClass`, the id, and the id's last
  reverse-DNS segment when it is at least 3 characters, non-numeric, and not in
  `ENTRY_KEY_STOPLIST`) equals a normalized class source exactly
  (`AppLogic.windowMatches`). This is stricter than
  `HyprlandFocus.classMatches`, which matches segments and reverse-DNS suffixes.
  The loose rule let a `Baldur's Gate 3` entry with no `StartupWMClass` match
  Unity editor windows through a shared numeric token, so Kill could close
  unrelated apps. `HyprlandFocus` keeps the loose rule for notifications, tray,
  and the player.
- **Graceful Kill.** Kill calls `wayland.close()` on every exactly matched
  window, a graceful close. There is no confirm step because nothing is
  force-killed, and no SIGKILL path. Apps may still prompt to save. The
  dashboard stays open and the row updates when the windows go.
- **Focus.** `AppService.focusWindows` takes its windows from the same strict
  matcher, picks an `activated` one else the first, closes the dashboard, then
  calls `HyprlandFocus.focusAddress(address)`. Closing first lets
  `HyprlandFocus` wait for `PanelGrab.closing` and restore the cursor, the order
  `DashboardPlayerBlock` already uses.
- **Workspace dispatch and quoting.** "Workspace N" is the dashboard monitor's
  Nth slot: `MonitorService.firstWorkspaceFor(monitor) + N - 1`, bounded by
  `MonitorService.workspacesPerMonitor`. The dispatch is a Hyprland Lua call,
  `hl.dsp.exec_cmd(cmd, { workspace = N })` through `Hyprland.dispatch`, not a
  legacy `dispatch` string. `AppLogic.shellCommand` quotes each argv element
  with POSIX single quotes and `MonitorLogic.escapeLua` escapes the result, so
  Hyprland's `/bin/sh -c` sees one quoted argument per element and a file name
  with spaces, `$(...)`, backticks, or redirection cannot split or inject.
  Terminal entries keep the `kitty -e` prefix.
- **Menu inside the card.** `components/ContextMenu.qml` is a shared, generic
  menu. It fits inside the dashboard window without growing it: it opens at the
  anchor, shifts up on bottom overflow, caps its height at the view and scrolls
  its item column, and flips the one-level submenu left when there is no room on
  the right. The item order is Open (↵), Open on workspace ▸, Open keep
  dashboard (middle), Focus window (N open), the entry's desktop actions under
  an "Actions" label, Pin/Unpin (Ctrl+P), Hide from launcher, Copy launch
  command, and Kill `<name>` last in danger. The `Run` row's menu is only Run
  and Copy command.

## Alternatives considered

- **A standalone launcher window.** A second surface duplicates the dashboard's
  junction, theme, focus path, and panel-grab handling, and the Media tab was
  already free. Rejected.
- **A detail pane (design variants 1 "Split preview" and 5 "Detail drawer").**
  More surface for no gain over one list; variant 3 was chosen.
- **Category pills or filter chips.** Filtering by category duplicates the
  ranked search and adds a second navigation model beside it. Rejected.
- **Inline workspace buttons (variant 3's original row).** They crowd the row
  and cover only a few slots; Ctrl+N plus the "Open on workspace" submenu reach
  the whole block. Rejected.
- **A legacy `dispatch` string for workspace launch.** Rejected in favour of the
  Lua `hl.dsp.*` API, the path the rest of the shell uses under the quattro
  config.
- **Reusing `HyprlandFocus.classMatches` for the launcher.** Rejected; its loose
  matching caused the Baldur's Gate 3 false positive above.

## Consequences

- Super must deep-link `dashboard apps`, so the bind lives in the user's
  Hyprland config outside this repo. The rofi script stays until the native path
  has a week of daily use.
- No launcher beside the dashboard. A quick panel still opens beside the
  dashboard, but there is no second launcher surface.
- An app whose window class differs from its desktop id and declares no
  `StartupWMClass` shows no running dot, for example T3 Code Nightly. There is
  no force-kill of a hung app, and the terminal is fixed to `kitty`.
- The launcher is a dashboard tab, so its behavior depends on the dashboard's
  placement and grab rules (ADR 0008). The user page is
  `docs/user/app-launcher.md`; the `dashboard apps` target is in
  `docs/user/ipc.md`.
