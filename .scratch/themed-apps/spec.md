# Spec: themed apps

Firefox, Vencord, and Spicetify (Spotify) should follow the active shell theme,
and the user should be able to choose, per app, which applications the desktop
retint writes.

## Decisions

The decision record is `docs/adr/0018-per-app-theme-targets.md` (and its
amendment). In short:

- The renderer writes a fixed set of nine targets: Hyprland borders, kitty,
  hyprlock, starship, yazi, btop, Firefox, Vencord, and Spicetify. Each has a
  template under `assets/templates/`, a render case, and an on/off flag.
- Output comes from the palette only. Theme directories stay read-as-data
  (ADR 0010, ADR 0011).
- Firefox is themed at the chrome through a generated sheet that carries both
  `--shell-*` variables and the rules mapping them onto Firefox's chrome
  variables; the user imports it once from their own `userChrome.css`, and the
  legacy-sheets pref goes in a generated `user.js`.
- Vencord is recolored by overriding system24's base namespace on `:root` and
  leaving its derived variables alone. The user enables it once, orders it after
  `system24.theme.css`, and restarts Discord once.
- Spicetify follows the shell through a bundled copy of the community `text`
  theme. The renderer owns `~/.config/spicetify/Themes/quickshell/`, keeps the
  theme's default color options, and appends a `Quickshell` color option built
  from the palette; the user selects the theme once, and the shell refreshes the
  client.
- Disabling an app writes a valid unthemed layer instead of deleting its file: a
  comment-only file where that is safe, or the built-in default palette where the
  file defines required variables or is a whole config (starship, hyprlock).
- A retint applies on the next app start; Vencord hot-reloads through its
  watcher and Spicetify refreshes on demand. Targets render in isolation, and the
  unresolved-placeholder guard matches a `{{name}}` shape rather than any brace
  pair (ticket 01).

## Tickets

| # | Title | Blocked by |
| --- | --- | --- |
| 01 | Renderer target gating and isolation | none |
| 02 | Vencord target | ticket 01 |
| 03 | Firefox target | ticket 02 |
| 05 | Spicetify theme | ticket 03 |
| 04 | Themed apps settings section and docs | tickets 01, 02, 03, 05 |

The tickets run in a line (01, 02, 03, 05, 04) because 02, 03, and 05 all edit
the renderer's job table and section 17 of `scripts/test-panel-logic.sh`, and
serializing them avoids a conflicting diff. Ticket 04 is the capstone and owns
every write to `docs/user/theme-desktop-setup.md` and the `CONTEXT.md` retint
line, so the target tickets never collide on prose.

## Out of scope

Vesktop, Zen, Chromium, Steam, GTK, and icon themes. Per-theme app files, where a
theme directory supplies its own `vencord.theme.css` or `firefox.css`. Any
automatic edit of a user-owned file (`userChrome.css`, `settings.json`, an
existing `user.js`, `config-xpui.ini`).
