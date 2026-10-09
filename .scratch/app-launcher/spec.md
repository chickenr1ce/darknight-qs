# App launcher spec

Status: needs-triage

## Problem Statement

Apps launch from a rofi script bound to Super. It looks foreign next to the
native panels, knows nothing about the shell's theme, and has no mouse story
beyond click-to-launch: no way to pin, hide, focus a running app, close it, or
reach an app's own actions (New Private Window, Compose) without a terminal.
The dashboard's Media tab is a "Coming soon" placeholder; the player already
lives on the Dashboard page.

## Solution

A native launcher that lives in the dashboard as the **Apps** tab, replacing
the Media placeholder. Super opens the dashboard straight onto Apps with the
search field focused. The layout is the "Inline actions" design (variant 3 of
`docs/plans/09-app-launcher-designs.html`): one full-width list, no side pane,
no category pills.

- With no query the list shows **Pinned**, then **Recent** (unpinned only),
  then **All apps** A–Z. Typing replaces the sections with one ranked list;
  no match offers a "Run “…”" row that runs the query as a command.
- Each row: app icon, name, generic name, a running dot with window count, a
  pin star. The selected or hovered row swaps the dot and star for inline
  buttons: **Focus**, **Kill**, **Pin/Unpin**, **⋯** (opens the context menu).
  Focus and Kill stay laid out but dim and inert when the app has no window.
- Open on a workspace is not an inline button: Ctrl+1…N and the right-click
  menu cover it.
- Right-click (or ⋯, Shift+F10, Menu key) opens a context menu: Open, Open on
  workspace ▸, Open and keep dashboard, Focus window, the app's desktop
  actions, Pin/Unpin, Hide from launcher, Copy launch command, Kill.

## User Stories

1. As a keyboard user, I want Super to open the dashboard on Apps with the
   cursor already in search, so that launching is Super, type, Enter.
2. As a keyboard user, I want Super to switch to Apps when the dashboard is
   open on another tab, and close it when Apps is already showing, so that one
   key toggles the launcher.
3. As a dashboard user, I want clicking the bar title to keep opening the
   Dashboard page, so that the existing entry point is unchanged.
4. As a launcher user, I want Pinned and Recent above the full list, so that
   my common apps are one keypress away without typing.
5. As a launcher user, I want results ranked by name prefix, then word start,
   then substring, then fuzzy, then keyword or generic name, with the matched
   letters highlighted, so that "fi" finds Files and Firefox first.
6. As a launcher user, I want a "Run “query”" row when nothing matches, so
   that I can start a one-off command without a terminal.
7. As a mouse user, I want hover to select, click to open, and middle-click to
   open while the dashboard stays up, so that I can start several apps in a
   row.
8. As a mouse user, I want Focus and Kill buttons on the hovered row of a
   running app, so that I can jump to or close it without leaving the
   launcher.
9. As a mouse user, I want right-click on any row to open a menu of every
   action, including the app's own desktop actions, so that nothing needs a
   keybind.
10. As a keyboard user, I want Shift+F10 or the Menu key to open the same menu
    on the selected row and arrow through it, so that the menu is not
    mouse-only.
11. As a multi-monitor user, I want Ctrl+1…N and "Open on workspace" to mean
    this monitor's workspaces, so that workspace 2 opens on the monitor I am
    looking at.
12. As a tidy user, I want to pin, reorder by recency, and hide apps, and have
    that survive a restart, so that the list reflects how I work.
13. As a tidy user, I want to unhide apps from Settings, so that a hidden app
    is never lost.
14. As a themer, I want every color, radius, size, and duration from
    `config/Colors.qml` and `config/Globals.qml`, so that every catalog theme,
    light and monochrome included, renders the launcher correctly.
15. As a monochrome-theme user (ash, vantablack), I want the selected row to
    stay visible even when the accent is grey, so that I can see where I am.
16. As a terminal-app user, I want apps marked `Terminal=true` (btop, yazi,
    nvim) to open inside a terminal, so that they do not start headless.
17. As a reduced-motion user, I want every launcher transition instant, so
    that the tab stays usable.

## Implementation Decisions

- **Placement.** `DashboardService.tabs` swaps `{ key: "media" }` for
  `{ key: "apps", title: qsTr("Apps") }`. `windows/DashboardCenter.qml`
  mounts a new `windows/DashboardAppsView.qml` when
  `DashboardService.activeTab === "apps"`; the "Coming soon" placeholder stays
  for Performance and Workspaces. The Settings section keyed `"media"`
  (`SettingsService`, MPRIS app filter) is unrelated and untouched.
- **Entry point.** `DashboardService` gains `openAppsAt(screen, centerX)` and
  `toggleAppsAt(screen, centerX)` beside `openSettingsAt`, and the `dashboard`
  `IpcHandler` gains `apps()` with the toggle semantics of story 2. The Super
  bind becomes `quickshell ipc call dashboard apps` (user's Hyprland config,
  not this repo).
- **Data.** New `services/AppService.qml` singleton reads
  `DesktopEntries.applications` (already excludes Hidden and NoDisplay) and
  owns pins, hidden ids, recent ids, running-window matching, and the launch,
  focus, and kill actions. Pure logic (ranking, highlight ranges, section
  building, entry↔window matching, state parsing, workspace mapping) lives in
  `services/AppLogic.js` (`.pragma library`), delegated one line per function,
  tested under node through `tests/qmljs.js`.
- **Launch.** `DesktopEntry.execute()` / `DesktopAction.execute()` for normal
  entries. `execute()` ignores `runInTerminal`, so terminal entries run
  `Quickshell.execDetached` with the terminal prefix (`kitty -e`, an
  `AppService` constant) plus `entry.command`. Every launch closes the dashboard
  unless it came from middle-click or "Open and keep dashboard".
- **Running windows.** An entry matches a `Hyprland.toplevels` item when the
  entry's keys (`startupClass`, `id`, the id's last reverse-DNS segment)
  match the toplevel's class sources by the same rules as
  `HyprlandFocus.classSources` / `classMatches`. The matcher moves into
  `AppLogic.js` so both use one rule set.
- **Focus** calls `HyprlandFocus.focusByTokens(keys)`, which already waits for
  `PanelGrab.closing` so the dashboard's grab release cannot steal focus back.
- **Kill** closes every matched window through its Wayland handle
  (`HyprlandToplevel.wayland.close()`), a graceful close: apps may still
  prompt to save. No confirm step, since nothing is force-killed.
- **Workspaces.** "Workspace N" is the Nth workspace of the dashboard's
  monitor: `MonitorService.firstWorkspaceFor(monitorName) + N - 1`, with N
  bounded by `MonitorService.workspacesPerMonitor`. Ctrl+1…9 cover that range.
  The dispatch is a Hyprland Lua call (`hl.dsp.*`), not a legacy `dispatch`
  string, verified against the installed Hyprland before it ships.
- **Context menu** is a new shared component, `components/ContextMenu.qml`,
  built from existing tokens, because no current primitive covers it
  ("No new primitive" asks that it live in `components/`). It opens inside the
  dashboard window and clamps to the card, since the panel clips anything
  outside its layout.
- **Persistence.** One `StateFile` named `app-launcher` holds
  `{ pinned: [ids], hidden: [ids], recent: [ids] }` behind the load guard.
  Recent keeps the last 8 launches. An id that no longer resolves stays in the
  file and simply does not render.
- **Hidden apps** are listed in a new Settings section ("Apps") with an Unhide
  per row, per `docs/dev/settings-sections.md`.
- **Icons.** `Quickshell.iconPath(entry.icon, true)`; an empty result falls
  back to a letter tile tinted with `Colors.appColor(entry.name)`.
- **Selection fill.** The selected row uses `Colors.accentDim` plus a 3px
  accent rail (the notification rail). When the accent's contrast against the
  background is under 3:1, the fill falls back to a foreground wash (a new
  `Colors.selection` role using `Colors.contrastRatio` and `mixInto`), so ash
  and vantablack keep a visible selection.
- **Keyboard.** ↑/↓, PageUp/PageDown, Tab/Shift+Tab move; Enter opens;
  Alt+Enter opens and keeps the dashboard; Ctrl+P toggles pin; Ctrl+1…N opens
  on workspace; Shift+F10 / Menu opens the menu; Esc clears the query, then
  closes. Typing anywhere in the tab refocuses search.
- **Design source.** `docs/plans/09-app-launcher-designs.html`, variant 3,
  with this spec's change: Focus and Kill replace the inline workspace buttons.

## Testing Decisions

- Good tests assert behavior through the public seams: the ranked order for a
  query, the sections for an empty query, which entries a set of toplevels
  marks running, the workspace number Ctrl+N resolves to on each monitor, and
  that a corrupt or missing state file loads as empty lists.
- Seams, highest first: `services/AppLogic.js` under node via
  `tests/qmljs.js`; structural greps in a new `scripts/test-app-launcher.sh`
  registered in `scripts/check.sh` (the delegations, the tab key, the IPC
  function, the StateFile name); `scripts/lint.sh` as the type gate;
  `scripts/boot-check.sh <worktree>` for load.
- Live verify (`scripts/restart.sh --probe <worktree>`): Super from a focused
  app types straight into search with no click; launch, middle-click, Focus,
  Kill on a throwaway app, every menu item, Ctrl+N on both monitors, pin and
  hide surviving a restart, and the tab under ash, haven, and darknight.
- Prior art: `scripts/test-dashboard-data.sh` (logic via `tests/qmljs.js`
  plus structural greps), `scripts/test-panel-logic.sh` (dashboard tabs).

## Out of Scope

- Force-kill (SIGKILL) of a hung app.
- Category filters, pills, or rails.
- A detail pane or drawer (variants 1 and 5).
- Drag to pin or reorder; pins order by when they were pinned.
- Calculator, file, web, or command-history search.
- A configurable terminal; `kitty -e` is a constant for now.
- Editing desktop entries (Quickshell exposes no entry path).
- Removing the rofi script, before the native path verifies live.

## Further Notes

- The dashboard sits outside the `Panels` registry, so a quick panel can
  still open beside the launcher.
- `HyprlandToplevel.lastIpcObject` is empty under Hyprland's Lua IPC, so the
  matcher must lean on the Wayland `appId`, as `HyprlandFocus` already does.
