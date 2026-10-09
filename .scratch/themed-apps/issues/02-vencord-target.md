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

2. The template overrides exactly these variables and leaves the rest to
   system24's own derivations: `--colors: on`, `--bg-1` through `--bg-4`,
   `--text-1` through `--text-5`, and the five hue scales `--red-1..5`,
   `--green-1..5`, `--blue-1..5`, `--yellow-1..5`, `--purple-1..5`. It does not
   set `--text-0`, `--mention`, `--mention-hover`, `--accent-*`, `--border*`,
   `--hover`, `--active`, `--active-2`, `--message-hover`, `--online` and
   friends, `--accent-new`, `--button-border`, or `--online-mobile`: system24
   derives those from the base variables (`--mention` is a gradient over
   `--accent-2`, `--text-0` is `var(--bg-4)`, `--accent-*` is `var(--purple-*)`,
   `--border-hover` is `var(--accent-2)`), and overriding them directly would
   break its derivations.

3. The `--purple-*` scale maps from the palette's `accent`, not `magenta`,
   because system24 drives `--accent-*`, links, and `--border-hover` from it;
   Discord's accent, links, and hover borders must follow the shell accent. Build
   it as a ramp from `{{accent}}` to a brighter step
   (`color-mix(in srgb, {{accent}} 70%, {{bright_foreground}})`) for
   `--purple-1`. `magenta` and `cyan` then have no scale in this template; leave
   them, and say in a comment that they are intentionally unused so a later
   reader does not "fix" it.

4. The template builds the other ramps with `color-mix()` rather than assuming a
   palette role per step, because the palette gives two colors per hue while the
   scale has five steps, and it needs translucency the renderer tokens do not
   carry:
   - `--bg-1..4` is a **monotonic** ramp, lightest to darkest:
     `--bg-1` `lighter_background`, `--bg-2` `background`, `--bg-3`
     `dark_background`, `--bg-4` `darker_background` (the last falls back to
     `dark_background`, ticket 01). system24 uses `--bg-4` as the main background
     and `--bg-1` for clicked buttons, so the ramp must run in that direction.
   - `--text-1..5` is a ramp derived for contrast against the theme background,
     not a fixed role order. On a dark palette it descends
     `bright_foreground`/`light_foreground` to `foreground`/`muted`; on a light
     palette it must invert so text stays readable. Reuse the renderer's existing
     contrast helpers (`ink`, `contrast`, the `on_*`/`readable_*` pattern) or a
     `mode`-conditional in the template; a near-white `--text-1` on a light
     `--bg-4` is a failure.
   - each `--<hue>-1..5` interpolates from the palette hue to its `bright_`
     variant, for example `--red-1: {{red}}; --red-5: {{bright_red}};`.
   The implementer renders a dark palette and the section 17 light palette, then
   checks both in the running client before the ticket closes.

5. The template sets no `!important` and no Discord variable (`--background-*`,
   `--text-normal`, `--brand-*`). It relies on cascade order against the base
   theme's plain `:root` block.

6. The renderer writes it under the target key `vencord` to
   `$XDG_CONFIG_HOME/Vencord/themes/quickshell.theme.css`, defaulting to
   `~/.config/Vencord/themes/quickshell.theme.css`. The renderer never reads or
   writes `settings.json`; enablement and ordering stay manual (assert that no
   `settings.json` path appears in the render case).

7. Disabled, the destination keeps the banner and metadata header but carries no
   `:root` color overrides, so the theme stays listed in Vencord and
   `enabledThemes` never points at a missing file.

8. `scripts/test-panel-logic.sh` section 17 asserts the Vencord destination
   renders palette values, sets `--colors: on`, matches the exact base-variable
   set in criterion 2, contains no derived variable and no `!important`, holds no
   unresolved token, and, for the light fixture, keeps the text ramp contrasting
   against the background.

9. `scripts/check.sh` passes.

## Notes

The user enables the theme once, orders it after `system24.theme.css`, and
restarts Discord once for the newly enabled entry. The how-to wording lands in
ticket 04, as does the base-theme coupling. Open question to confirm live:
whether a `.theme.css` with no metadata header can be enabled, which is why the
template carries one. The live base theme is `system24.theme.css`, which
`@import`s `system24.css` over the network; verify the derived-variable claims
against the built stylesheet, not only the local wrapper.
