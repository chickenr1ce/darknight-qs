# Ticket 02: Vencord target

**Status:** ready-for-agent
**Blocking:** ticket 03, ticket 04
**Blocked by:** ticket 01

## Objective

Recolor Discord through Vencord by overriding the base theme's own color
namespace, so the generated theme sets the palette while the base theme keeps its
layout.

## Acceptance criteria

1. New template `assets/templates/vencord-theme.css`. It carries the repo banner
   comment and a BetterDiscord-style metadata header
   (`/** @name quickshell @description Shell palette */`) so Vencord lists it,
   then one `:root` block that sets system24's namespace variables from the
   palette with `{{role}}` placeholders.

2. The template sets exactly this variable set: `--bg-1` through `--bg-4`,
   `--text-0` through `--text-5`, `--accent-1` through `--accent-5`, `--hover`,
   `--active`, `--active-2`, `--message-hover`, `--mention`, `--mention-hover`,
   `--reply`, `--reply-hover`, `--online`, `--dnd`, `--idle`, `--streaming`,
   `--offline`, `--border-light`, `--border`, `--border-hover`, the `--red-1..5`,
   `--green-1..5`, `--blue-1..5`, `--yellow-1..5`, and `--purple-1..5` ramps, and
   `--colors: on`. It leaves `--accent-new`, `--button-border`, and
   `--online-mobile` to derive from those ramps, as system24 does.

3. Every placeholder names a token the renderer defines. The template includes an
   explicit role-to-variable mapping in its header comment, mirroring system24's
   semantics rather than assigning names by eye: `--text-0` is the on-color ink
   for text painted on an accent surface (use the existing `{{on_accent}}`
   token), `--text-1..5` is a lightness ramp from `bright_foreground` down to
   `muted`, `--bg-1..4` is a surface ramp over `background`, `dark_background`,
   `lighter_background`, and `darker_background`, `--accent-*` is the accent
   family, and each hue ramp is that hue plus its `bright_` variant. The
   implementer verifies contrast in a running Discord before the ticket closes.

4. The template sets no `!important` and no Discord variable (`--background-*`,
   `--text-normal`, `--brand-*`). It relies on cascade order against the base
   theme's plain `:root` block.

5. The renderer writes it under the target key `vencord` to
   `$XDG_CONFIG_HOME/Vencord/themes/quickshell.theme.css`, defaulting to
   `~/.config/Vencord/themes/quickshell.theme.css`. The renderer never reads or
   writes `settings.json`; enablement and ordering stay manual (assert that no
   `settings.json` path appears in the render case).

6. Disabled, the destination holds a `/* */` comment-only file, so
   `enabledThemes` never points at a missing file.

7. `scripts/test-panel-logic.sh` section 17 asserts the Vencord destination
   renders palette values, sets `--colors: on`, matches the exact variable set in
   criterion 2, and holds no unresolved token.

8. `scripts/check.sh` passes.

## Notes

The user enables the theme once, orders it after `system24.theme.css`, and
restarts Discord once for the newly enabled entry (file edits hot-reload, but a
new `enabledThemes` entry is read at launch). The how-to wording lands in ticket
04. The base-theme coupling (our file defines variables nothing consumes if
system24 is off) is documented there too.
