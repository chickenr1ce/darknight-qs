# Ticket 05: Spicetify theme (bundled text theme plus a palette option)

**Status:** ready-for-agent
**Blocking:** ticket 04
**Blocked by:** ticket 01, ticket 02, ticket 03

## Objective

Ship the community `text` Spicetify theme as a shell-owned theme whose colors
follow the palette, keeping the theme's own default color options and adding one
palette-built option.

## Acceptance criteria

1. Vendor the upstream theme (MIT, `spicetify/spicetify-themes`, `text/`,
   copyright 2019 morpheusthewhite), pinned to upstream commit
   `33a08ea009687f5a42ff678015c28797fe142a7c` (re-check at vendor time and record
   the hash actually vendored, in the ticket and in a comment atop each template),
   as two render templates:
   - `assets/templates/spicetify-user.css`, the upstream `text/user.css`
     verbatim plus a `/* */` banner comment;
   - `assets/templates/spicetify-color.ini`, the upstream `text/color.ini`
     verbatim (all default color options, unchanged) plus a `;`/`#` banner
     comment (a CSS banner is a parse error in INI), and an appended `[Quickshell]`
     section. Do not enumerate the default options; "verbatim upstream, pinned"
     is the requirement.
   Reproduce the full MIT license text in `NOTICE`, matching the Omarchy entry.

2. The `[Quickshell]` section sets every key the default options use, and no
   others; the test asserts its key set equals the union of the default sections'
   key sets, so drift in the vendored file fails the gate. It uses
   `{{<role>_hex}}` placeholders such as `{{accent_hex}}` (bare hex, no leading
   `#`; `{{accent}}_hex` would render `#rrggbb_hex`). Map to mode-safe roles
   so a light shell theme does not produce white-on-light or dark slabs: `text`
   foreground, `subtext` muted, `main` background, `highlight` selection,
   `header` muted, `banner` accent, `accent` accent, `accent-active` accent,
   `accent-inactive` selection, `border-active` accent, `border-inactive` muted,
   `notification` accent, `notification-error` red. `thirteen` keys collapse onto
   a few roles; confirm with one live screenshot per mode that unfocused borders,
   selected rows, and the disabled progress track still read as distinct, and if
   not, move `border-inactive` or `highlight` to another role.

3. Under the target key `spicetify`, title "Spicetify", the renderer writes
   `${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/Themes/quickshell/color.ini` and
   `.../user.css`, creating the directory when absent. It owns that directory's
   two files and never edits a theme the user installed or `config-xpui.ini`; it
   does not delete unknown files there. When Spicetify is not installed or the
   config directory is absent, it logs `spicetify: not installed` to stderr,
   writes nothing, and counts as skipped-success (exit 0).

4. Disabled, the `[Quickshell]` section renders the theme's own `[Spicetify]`
   default values instead of the palette. Take those values from the vendored
   `spicetify-color.ini` template itself (its `[Spicetify]` section), parsed once
   by the renderer, so there is one source of truth and the disabled layer cannot
   drift from the shipped theme. `user.css` is written (it is the theme's layout,
   not a color layer).

5. `write_if_changed` returns whether it wrote (ticket 01). After a render **and
   only when a Spicetify destination's bytes actually changed**, the renderer
   runs `spicetify refresh` best-effort: only when `spicetify` is on PATH,
   failures ignored and never allowed to fail the run, and only for Spicetify
   changes. It never runs `spicetify apply`, which is version-gated here
   (`[Backup] with=2.42.8` versus CLI `2.45.3`) and force-restarts Spotify.

6. The renderer never sets `current_theme` or `color_scheme`. Selecting the theme
   is a one-time user step, verified on this machine before the ticket closes:
   whether plain `spicetify refresh` picks up a theme/color-scheme selection, or
   the user must run
   `spicetify config current_theme quickshell color_scheme Quickshell` and, given
   the version gate, `spicetify restore backup apply` (restarts Spotify and must
   be re-run after every Spotify update). Record a dated note with the
   `spicetify` and Spotify versions. This is not a footnote: if option (b) is
   reality, the ticket states the exact command sequence and its restart/update
   consequences, ticket 04 documents that step (not "select once"), and the
   feature's cost is re-scoped. Ticket 04 must not be written until this resolves.

7. `scripts/test-panel-logic.sh` section 17 stubs `spicetify` on PATH (prepended,
   with a `command -v` assertion) and uses a fixture `XDG_CONFIG_HOME` with a
   `spicetify` directory, never the live one. It asserts the theme directory
   gains `color.ini` (all default options present, the `[Quickshell]` key set
   matching, palette values with no `#`, no unresolved token) and `user.css`
   (verbatim, no `{{`), that the refresh stub was invoked once and not again on an
   identical second render, that the disabled case renders the `[Spicetify]`
   defaults, and that a missing `spicetify` directory skips with exit 0.

8. `scripts/check.sh` passes.

## Notes

`text` is not installed on this machine, which is why the shell bundles it; the
renderer owns `Themes/quickshell/` rather than `Themes/text/` so a future
Marketplace install of `text` cannot collide. Bundling means the repo maintains
the upstream `user.css`; note that obligation in ticket 04.

Vendored 2026-10-10. The pinned commit
`33a08ea009687f5a42ff678015c28797fe142a7c` (2026-09-22, "feat(text): add
BloodMoon color scheme") was re-checked at vendor time and is the latest commit
touching `text/`. Hashes of the vendored upstream files:
`text/user.css` sha256 `ac0fc97d0475e85c204d26c677892fdd80509869fbe538fd92572a29d8dbf344`,
`text/color.ini` sha256 `2d020d9dc922608781af03c0424011ef6c132c5ddb164b19a4ac2ba5adeea9b5`.
Both hashes and the commit are recorded in a comment atop their template
(`assets/templates/spicetify-user.css`, `assets/templates/spicetify-color.ini`)
and the license in `NOTICE`.

Criterion 6 resolved live 2026-10-10: path (b). `config` plus `refresh` does not
take a selection (Marketplace keeps `current_theme` in `index.html`); the step
is `spicetify config current_theme quickshell color_scheme Quickshell` then
`spicetify restore backup apply` (restarts Spotify; re-run after Spotify
updates). Later retints stage through `refresh` and show on the next Spotify
start. Details in `.scratch/themed-apps/notes/04-handoff.md` section 2.
