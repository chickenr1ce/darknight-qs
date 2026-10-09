# Ticket 02: Vencord target

**Status:** ready-for-agent
**Blocking:** ticket 03
**Blocked by:** ticket 01

## Objective

Recolor Discord through Vencord by overriding the base theme's own color
namespace, so the generated theme sets the palette while the base theme keeps its
layout and its derived colors.

## Acceptance criteria

1. New template `assets/templates/vencord-theme.css`. It carries the repo banner
   comment and a BetterDiscord-style metadata header
   (`/** @name quickshell @description Shell palette */`), then one `:root` block
   that sets only the base system24 variables from the palette.

2. The template sets `--colors: on`, `--bg-1` through `--bg-4`, `--text-1`
   through `--text-5`, `--text-0: {{on_accent}}`, and the five hue scales
   `--red-1..5`, `--green-1..5`, `--blue-1..5`, `--yellow-1..5`,
   `--purple-1..5`. It does not set `--mention`, `--mention-hover`,
   `--accent-*`, `--border*`, `--hover`, `--active`, `--active-2`,
   `--message-hover`, `--online` and friends, `--accent-new`, `--button-border`,
   or `--online-mobile`: system24 derives those from the base variables
   (`--mention` is a gradient over `--accent-2`, `--accent-*` is
   `var(--purple-*)`, `--border-hover` is `var(--accent-2)`). Setting `--text-0`
   is required, not optional: leaving it derived makes it `var(--bg-4)`, which
   system24 chains into `--white` and `--white-500`, so `--white` becomes a
   near-black on dark accents and breaks DMS hover text, badges, and expressive
   text. `{{on_accent}}` already exists in the renderer.

3. The `--purple-*` scale maps from the palette's `accent`, not `magenta`,
   because system24 drives `--accent-*`, links, and `--border-hover` from it;
   Discord's accent, links, and hover borders must follow the shell accent.
   `magenta` and `cyan` then have no scale here; leave them, with a comment that
   they are intentionally unused.

4. Build the ramps with `color-mix()` (Chromium 111+, present in the running
   Electron) and the token ramp from ticket 01; do not branch on `mode` in the
   template, which is pure substitution:
   - `--bg-1..4` must be four **distinct** surfaces with `--bg-4` the main
     background and `--bg-1` the clicked-button state. Do not map them straight
     onto the four palette background roles: on real palettes those are not
     ordered (haven's `background` equals its `darker_background`, so clicked
     states vanish). Derive the ramp with `color-mix()` from `background` toward
     the mode's background ink so `--bg-1` always differs from `--bg-4`, and
     assert distinctness for both fixtures.
   - `--text-1..5` uses the mode-aware `text_1..5` tokens from ticket 01
     (pre-computed for contrast against `background`); `--text-1` is the
     highest-contrast step and `--text-5` the lowest.
   - each `--<hue>-1..5` interpolates from the brighter step to the darker:
     `--<hue>-1` lightest (`color-mix` toward `bright_`) down to `--<hue>-5` the
     base hue, for example `--red-1: {{bright_red}}; --red-5: {{red}};`. Define
     all five stops for every scale, including `--purple-1..5`, because
     `--accent-3..5` drive button default, hover, and clicked states and must not
     collapse to one value.
   Render a dark palette and the section 17 light palette and check both in the
   running client before the ticket closes. Include a button-state sweep: the
   upstream `midnight.css` ships debug placeholders (`--button-danger-background-disabled: lime`,
   and blue/magenta outline vars) that any namespace override leaves in place;
   confirm they are the only unexpected colors, and note them for ticket 04.

5. The template sets no `!important` and no Discord variable (`--background-*`,
   `--text-normal`, `--brand-*`). It relies on cascade order against the base
   theme's plain `:root` block.

6. The renderer writes it under the target key `vencord` to
   `$XDG_CONFIG_HOME/Vencord/themes/quickshell.theme.css`, defaulting to
   `~/.config/Vencord/themes/quickshell.theme.css`. The renderer never reads or
   writes `settings.json`; enablement and ordering stay manual (assert that no
   `settings.json` path appears in the render case). When `~/.config/Vencord` is
   absent, log `vencord: not installed`, write nothing, and skip as success, so
   the retint does not create a directory for a Discord that is not installed.

7. Disabled, the destination keeps the banner and metadata header but carries no
   `:root` color overrides, so the theme stays listed in Vencord and
   `enabledThemes` never points at a missing file.

8. `scripts/test-panel-logic.sh` section 17 asserts the Vencord destination
   renders palette values, sets `--colors: on`, matches the base-variable set in
   criterion 2 (including `--text-0`), contains no derived variable and no
   `!important`, holds no unresolved token, keeps `--bg-1` distinct from `--bg-4`
   for both fixtures, and keeps the text ramp contrasting against the background
   for the light fixture.

9. `scripts/check.sh` passes.

## Notes

The user enables the theme once, lists it **last** in `enabledThemes` (the live
list already carries a dangling `system24-old.theme.css` ahead of
`system24.theme.css`, so "after system24" is not enough), and restarts Discord
once for the newly enabled entry. The how-to wording lands in ticket 04, as does
the base-theme coupling and the placeholder disclosure. Open question to confirm
live: whether a `.theme.css` with no metadata header can be enabled, which is why
the template carries one. Verify the derived-variable claims against the built
`system24.css` (imported over the network), not only the local wrapper.
