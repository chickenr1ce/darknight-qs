# Documentation

Docs are organized by audience, and a new doc goes in the folder matching its
reader. `user/` holds end-user setup and how-to pages (linked from the README);
`dev/` holds agent and contributor reference. Cross-cutting records — ADRs, the
glossary, plans — stay at the root.

## User docs — [`user/`](user/)

Setup and how-to pages for someone running the shell. The README links these
from its Documentation section.

- [`user/monitors.md`](user/monitors.md) — the two-monitor layout, picking the primary, and the fixed workspace split.
- [`user/notifications.md`](user/notifications.md) — owning the notification bus, and Do Not Disturb.
- [`user/fonts.md`](user/fonts.md) — the three font families and their fallbacks.
- [`user/calendar.md`](user/calendar.md) — Google Calendar secret iCal URLs, and the `gcalcli` path for birthdays and per-calendar toggles.
- [`user/weather.md`](user/weather.md) — weather block, cache, and city search.
- [`user/spotify-connect.md`](user/spotify-connect.md) — one-time Spotify app authorization for the dashboard player.
- [`user/theme-desktop-setup.md`](user/theme-desktop-setup.md) — retint the desktop apps (Hyprland, kitty, hyprlock, starship, yazi, btop, Firefox, Vencord, Spicetify) from the active theme.
- [`user/qs-theme.md`](user/qs-theme.md) — the `qs-theme` CLI: install, switch, and manage themes and backgrounds.
- [`user/polkit.md`](user/polkit.md): keep the shell the only polkit authentication agent, and troubleshoot prompts, lockouts, and stuck helpers.
- [`user/ipc.md`](user/ipc.md) — the shell's IPC targets (`power`, `calendar`, `notifications`, `cava`, `audio`, `dashboard`, `dnd`, `volume`, `bar`, `lock`): functions, placement, and Lua keybind examples.
- [`user/app-launcher.md`](user/app-launcher.md) — the dashboard Apps tab: keys, mouse, context menu, pin/hide/unhide, and the Super keybind.
- [`user/audio.md`](user/audio.md) — the audio card: output, input with a level meter, per-app volume, and the mouse map.
- [`user/workspaces-tab.md`](user/workspaces-tab.md) — the dashboard Workspaces tab: the workspace maps, the mouse actions, and the window menu.
- [`user/lock.md`](user/lock.md) — the native lock screen: how to lock, the PAM password check, the power card, and the crash recovery steps.

## Dev docs — [`dev/`](dev/)

Reference for contributors and agents.

- [`dev/CODING_STANDARDS.md`](dev/CODING_STANDARDS.md) — QML + shell rules; read before writing or reviewing code.
- [`dev/debugging-quickshell.md`](dev/debugging-quickshell.md) — live debugging: instance pid/log, geometry, IPC probing.
- [`dev/quickshell-io-notes.md`](dev/quickshell-io-notes.md) — `Io` behavior: `Process` lifecycle, polling, file cache.
- [`dev/settings-sections.md`](dev/settings-sections.md) — adding a settings section.
- [`dev/theme-catalog.md`](dev/theme-catalog.md) — theme scan, parser, and preview invariant.
- [`dev/roadmap.md`](dev/roadmap.md) — planned and candidate work.

## Cross-cutting records

- [`adr/`](adr/) — architecture decision records. Number a new one with
  `scripts/next-adr.sh`, which reads every branch and worktree.
- [`agents/`](agents/) — issue tracker, triage labels, and delegated-work rules.
- [`incidents/`](incidents/) — one-off incident write-ups.
- [`plans/`](plans/) — frozen migration and design plan artifacts ([index](plans/README.md)).
- [`../CONTEXT.md`](../CONTEXT.md) — domain glossary.
