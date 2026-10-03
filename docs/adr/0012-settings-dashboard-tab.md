# ADR 0012: settings is a dashboard tab

Date: 2026-10-03. Feature: dashboard-tabs (`#01`, `#02`, `#03`). Supersedes
ADR 0007.

## Context

ADR 0007 made settings a Hyprland `FloatingWindow` because a layer-shell surface
always renders above a toplevel, so a settings window could never stack over the
layer-shell dashboard. The two surfaces were made mutually exclusive:
`SettingsService.open` closed the dashboard, and `DashboardService` closed
settings back.

That exclusion is the reported problem: opening settings from the dashboard gear
dismissed the dashboard. The tab row in `windows/DashboardTabs.qml` already drew
Dashboard / Media / Performance / Workspaces, but `activeIndex` was fixed at 0
and no page switched, so it was decoration. The dashboard card already grows to
its content up to `Globals.dashboardMaxHeight` and joins the bar through the
junction, so it can host settings without a window.

## Decision

Settings is the dashboard card's Settings tab. There is no separate surface.

- `services/DashboardService.qml` owns `activeTab` (default `"dashboard"`) and
  the tab list, exposed as `tabs`. `selectTab(key)` switches the page.
  `openSettings(sectionKey)` selects the Settings tab and forwards the deep
  link; `openSettingsAt(screen, centerX, sectionKey)` also opens the card for
  callers outside the dashboard.
- `windows/DashboardTabs.qml` renders `DashboardService.tabs`, marks
  `DashboardService.activeTab`, and switches through `selectTab`. Each tab is an
  `Accessible.Button`.
- `windows/DashboardCenter.qml` gates the existing dashboard body and meters on
  `activeTab === "dashboard"`, hosts `windows/SettingsView.qml` for
  `"settings"`, and shows a "Coming soon" placeholder for the empty tabs. The
  header gear to the right of the tab row selects the Settings page and takes
  the accent color while it is open. `DashboardService.tabs` lists only the
  labeled row tabs, so the row carries no "Settings" word.
- `windows/SettingsView.qml` holds the search field, the section rail, and the
  section body, which renders in a `Card` with one header. `SettingsService`
  keeps only the section registry and `targetSection`.
- `windows/SettingsCenter.qml` is deleted, `shell.qml` no longer instantiates
  it, and the Hyprland `openwindow` placement code is gone. The external
  `windowrules.lua` float rule is dead.

## Alternatives considered

- **Keep the window and stop closing the dashboard.** Not reachable: Hyprland
  draws layer-shell surfaces above every toplevel, so the window would sit
  behind the dashboard. ADR 0007 already recorded this.
- **Make the dashboard a toplevel so both stack.** Discards the junction and
  input mask, and returns placement to Hyprland, which layer-shell placement
  solved (ADR 0008).
- **Settings as a second layer-shell panel beside the dashboard.**
  `services/PanelGrab.qml` now allows coexistence, so it works, but it keeps a
  second floating surface and cannot use the dashboard's card width.

## Consequences

- The dashboard stays open across a tab switch; there is nothing to close and no
  mutual exclusion to maintain.
- Settings inherits the dashboard geometry: `Globals.dashboardWidth`,
  content-driven height up to `dashboardMaxHeight`, the junction radius, and the
  shared focus grab. `Globals.settingsWidth` and `settingsHeight` are removed;
  `settingsSidebarWidth` and `settingsBodyMaxHeight` remain.
- Settings is no longer a compositor-managed window: no move, resize, alt-tab
  entry, or independent dismissal. It dismisses with the dashboard through
  outside click or Escape.
- The tab row is now real. Media, Performance, and Workspaces are placeholder
  pages that later tickets fill.
