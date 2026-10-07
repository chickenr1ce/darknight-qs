# Documentation

Docs are organized by audience, and a new doc goes in the folder matching its
reader. `user/` holds end-user setup and how-to pages (linked from the README's
Optional integrations); `dev/` holds agent and contributor reference.
Cross-cutting records — ADRs, the glossary, plans — stay at the root.

## User docs — [`user/`](user/)

Setup and how-to pages for someone running the shell. The README links these from
its Optional integrations section.

- [`user/calendar.md`](user/calendar.md) — Google Calendar secret iCal URLs, and the `gcalcli` path for birthdays and per-calendar toggles.
- [`user/weather.md`](user/weather.md) — weather block, cache, and city search.
- [`user/spotify-connect.md`](user/spotify-connect.md) — one-time Spotify app authorization for the dashboard player.
- [`user/theme-desktop-setup.md`](user/theme-desktop-setup.md) — retint Hyprland, kitty, hyprlock, starship, yazi, and btop from the active theme.
- [`user/qs-theme.md`](user/qs-theme.md) — the `qs-theme` CLI: install, switch, and manage themes and backgrounds.
- [`user/polkit.md`](user/polkit.md): keep the shell the only polkit authentication agent, and troubleshoot prompts, lockouts, and stuck helpers.

## Dev docs — [`dev/`](dev/)

Reference for contributors and agents.

- [`dev/CODING_STANDARDS.md`](dev/CODING_STANDARDS.md) — QML + shell rules; read before writing or reviewing code.
- [`dev/debugging-quickshell.md`](dev/debugging-quickshell.md) — live debugging: instance pid/log, geometry, IPC probing.
- [`dev/quickshell-io-notes.md`](dev/quickshell-io-notes.md) — IO polling and file-cache behavior.
- [`dev/settings-sections.md`](dev/settings-sections.md) — adding a settings section.
- [`dev/theme-catalog.md`](dev/theme-catalog.md) — theme scan, parser, and preview invariant.
- [`dev/roadmap.md`](dev/roadmap.md) — planned and candidate work.

## Cross-cutting records

- [`adr/`](adr/) — architecture decision records.
- [`agents/`](agents/) — issue tracker and triage labels.
- [`incidents/`](incidents/) — one-off incident write-ups.
- [`plans/`](plans/) — frozen migration and design plan artifacts ([index](plans/README.md)).
- [`../CONTEXT.md`](../CONTEXT.md) — domain glossary.
