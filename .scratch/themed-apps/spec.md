# Spec: themed apps

Firefox and Vencord should follow the active shell theme, and the user should be
able to choose, per app, which applications the desktop retint writes.

## Decisions

The decision record is `docs/adr/0018-per-app-theme-targets.md`. In short:

- The renderer writes a fixed set of eight targets: Hyprland borders, kitty,
  hyprlock, starship, yazi, btop, Firefox, and Vencord. Each has a template under
  `assets/templates/`, a render case, and an on/off flag.
- Output comes from the palette only. Theme directories stay read-as-data
  (ADR 0010, ADR 0011).
- Firefox is themed at the chrome through a generated `chrome/shell-palette.css`
  that the user's `userChrome.css` imports, with the pref in a generated
  `user.js`.
- Vencord is recolored by overriding system24's namespace variables on `:root`.
  The user enables it once, orders it after `system24.theme.css`, and restarts
  Discord once.
- Disabling an app writes a no-op layer instead of deleting its file, so no
  include or `enabledThemes` entry dangles.
- A retint applies on the next app start; Vencord hot-reloads through its
  watcher. Targets render in isolation, and the unresolved-placeholder guard
  matches a `{{name}}` shape rather than any brace pair (ticket 01).

## Tickets

| # | Title | Blocked by |
| --- | --- | --- |
| 01 | Renderer target gating and isolation | none |
| 02 | Vencord target | ticket 01 |
| 03 | Firefox target | tickets 01, 02 |
| 04 | Themed apps settings section and docs | tickets 01, 02, 03 |

Ticket 03 is sequenced after ticket 02 because both edit the renderer's job table
and section 17 of `scripts/test-panel-logic.sh`; serializing them avoids a
conflicting diff. Ticket 04 is the capstone and owns every write to
`docs/user/theme-desktop-setup.md` and the `CONTEXT.md` retint line, so the
target tickets never collide on prose.

## Out of scope

Vesktop, Zen, Chromium, Steam, GTK, and icon themes. Per-theme app files, where a
theme directory supplies its own `vencord.theme.css` or `firefox.css`. Any
automatic edit of a user-owned file (`userChrome.css`, `settings.json`, an
existing `user.js`).
