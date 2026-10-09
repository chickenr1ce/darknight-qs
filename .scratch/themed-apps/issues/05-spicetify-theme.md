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
   copyright 2019 morpheusthewhite), pinned to a specific upstream commit hash
   recorded in the ticket and in a comment at the top of each vendored template,
   as two render templates:
   - `assets/templates/spicetify-user.css`, the upstream `text/user.css`
     verbatim plus a `/* */` banner comment;
   - `assets/templates/spicetify-color.ini`, the upstream `text/color.ini`
     verbatim (all of its default color options, unchanged) plus a `;`/`#` banner
     comment (a CSS banner is a parse error in INI), and an appended `[Quickshell]`
     section. Do not enumerate the default options in this ticket; "verbatim
     upstream, pinned" is the requirement, so the list cannot drift.
   Reproduce the full MIT license text (copyright and permission notice) in
   `NOTICE`, matching the existing Omarchy entry's precedent.

2. The `[Quickshell]` section sets every key the default options use, and no
   others; the test asserts its key set equals the union of the default sections'
   key sets, so a drift in the vendored file fails the gate. It uses
   `{{role}}_hex` placeholders (bare hex, no leading `#`; the renderer gains that
   token form in ticket 01). Map to mode-safe roles so a light shell theme does
   not produce white-on-light or dark slabs: `text` foreground, `subtext` muted,
   `main` background, `highlight` selection, `header` muted, `banner` accent,
   `accent` accent, `accent-active` accent, `accent-inactive` selection,
   `border-active` accent, `border-inactive` selection, `notification` accent,
   `notification-error` red.

3. Under the target key `spicetify`, title "Spicetify", the renderer writes
   `${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/Themes/quickshell/color.ini` and
   `.../user.css`, creating the directory when absent. It owns that directory
   whole and never edits a theme the user installed or `config-xpui.ini`. When
   Spicetify is not installed or the config directory is absent, it logs
   `spicetify: not installed` to stderr, writes nothing, and counts as
   skipped-success (exit 0).

4. Disabled, the `[Quickshell]` section renders the theme's own `[Spicetify]`
   default values instead of the palette, so a user who selected it sees the
   stock text look; the other default options are untouched, and `user.css` is
   written (it is the theme's layout, not a color layer).

5. `write_if_changed` returns whether it wrote. After a render **and only when a
   Spicetify destination's bytes actually changed**, the renderer runs
   `spicetify refresh` best-effort: only when `spicetify` is on PATH, failures
   ignored and never allowed to fail the run, and only for Spicetify changes. It
   never runs `spicetify apply`, which is version-gated here
   (`[Backup] with=2.42.8` versus CLI `2.45.3`) and force-restarts Spotify.

6. The renderer never sets `current_theme` or `color_scheme`. Selecting the theme
   is a one-time user step, and it is verified on this machine before the ticket
   closes: whether plain `spicetify refresh` picks up a theme/color-scheme
   selection, or the user must first
   `spicetify config current_theme quickshell color_scheme Quickshell` and, given
   the version gate, `spicetify restore backup apply` (which restarts Spotify and
   must be re-run after a Spotify update). Record the outcome with the
   `spicetify` and Spotify versions as a dated note in this ticket, and pass it
   to ticket 04, whose Spicetify subsection is written from that evidence and not
   from this plan.

7. `scripts/test-panel-logic.sh` section 17 stubs `spicetify` on PATH and uses a
   fixture `XDG_CONFIG_HOME` with a `spicetify` directory. It asserts the theme
   directory gains `color.ini` (all default options present, the `[Quickshell]`
   key set matching, palette values with no `#`, no unresolved token) and
   `user.css` (whose verbatim content contains no `{{`, so it is safe under the
   guard), that the refresh stub was invoked once and not again on an identical
   second render, that the disabled case renders the default values, and that a
   missing `spicetify` directory skips with exit 0.

8. `scripts/check.sh` passes.

## Notes

`text` is not installed on this machine, which is why the shell bundles it; the
renderer owns `Themes/quickshell/` rather than `Themes/text/` so a future
Marketplace install of `text` cannot collide. Bundling the theme means the repo
carries and maintains the upstream `user.css`; note that obligation in ticket 04.
