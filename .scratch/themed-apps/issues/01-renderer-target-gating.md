# Ticket 01: renderer target gating and isolation

**Status:** ready-for-agent
**Blocking:** ticket 02, ticket 03, ticket 04
**Blocked by:** none

## Objective

Give the desktop retint a per-target on/off switch, and stop one target's
failure from aborting the rest. The renderer keeps writing every target it can;
a target the user switched off renders a no-op layer instead of a missing file.

## Acceptance criteria

1. `scripts/render-theme.sh` gains an optional second positional argument: a
   comma-separated list of enabled target keys. The `/bin/sh` wrapper reads it as
   `${2:-}` and forwards it to the Python heredoc, so `sys.argv[1:5]` is palette,
   template_dir, config_home, enabled_keys. Python splits on `,`, strips
   whitespace, drops empty entries, and ignores a key it does not know. An absent
   or empty argument enables every target, so the existing one-argument
   invocation in `scripts/test-panel-logic.sh` section 17 keeps its behavior.

2. The renderer writes each target independently. A target whose template is
   missing, or whose rendered bytes still hold an unresolved token, logs a line
   naming the target to stderr and is skipped; the other targets still write.
   Exit status is zero when every enabled target wrote its palette bytes and
   every disabled target wrote its no-op bytes, and non-zero when at least one
   target failed.

3. The unresolved-token check matches the regex `\{\{[A-Za-z0-9_]+\}\}`. A
   literal `{{` or `}}` that does not form that shape (for example CSS-adjacent
   braces, or a typo'd `{accent}`) renders without failing.

4. A disabled target writes a no-op file at each of its destinations, in that
   destination's own comment syntax: `--` for `hypr-theme.lua`, `#` for the
   kitty, hyprlock, starship, yazi, and btop templates, `/* */` for the CSS
   targets, and `//` for `user.js`. A disabled `theme.lua` must still parse, so
   `require("theme")` does not throw. The no-op bytes are stable across palettes,
   and `write_if_changed` still skips an unchanged write. A target may own more
   than one destination; the no-op applies per destination, and Firefox's
   `user.js` is the named exception (left in place when `firefox` is disabled,
   per ticket 03).

5. `services/ThemeService.qml` exposes `readonly property var themeTargets`,
   eight `{ key, title }` entries in render order, titles wrapped in `qsTr()`:
   `hyprland` "Hyprland borders", `kitty` "kitty", `hyprlock` "hyprlock",
   `starship` "starship", `yazi` "yazi", `btop` "btop", `firefox` "Firefox",
   `vencord` "Vencord".

6. `ThemeService` exposes `themeTargetEnabled: ({})` and
   `isThemeTargetEnabled(key)` / `setThemeTargetEnabled(key, enabled)`, persisted
   through `StateFile { name: "theme-targets" }` behind the load guard. The
   setter ignores an unknown key and replaces the whole map with a fresh object
   (the `BarVisibilityService.setVisible` precedent at
   `services/BarVisibilityService.qml:78-87`), so the change signal fires. Model
   the parse, apply, save, and equality helpers on `BarVisibilityService`
   (`hasModule`, `sameVisibility`, `applyVisibility`, `saveVisibility`); the
   apply guard prevents a load, assign, save, change loop.

7. The map parses and serializes through `services/ThemeParsers.js`:
   `parseTargets(jsonText, keys)` (an absent key reads as enabled, only an
   explicit `false` disables, an unknown key is dropped, mirroring
   `services/StateParsers.js` `parseVisibility`) and `serializeTargets(map, keys)`
   (every key, boolean values). `ThemeService` keeps one-line delegating call
   sites, and the assertions extend the `ThemeParsers` node run under
   `tests/qmljs.js` (the `parseColors` / selection run).

8. `ThemeService` exposes `readonly property string enabledThemeTargetKeys`, the
   comma-joined enabled keys in `themeTargets` order. `idRenderProcess.command`
   is `["sh", root.renderScriptPath, root.renderPaletteJson, root.enabledThemeTargetKeys]`,
   and `onThemeTargetEnabledChanged` re-renders through the same deferred
   `renderDesktop` path the palette change uses (`services/ThemeService.qml:101`).

9. `scripts/test-panel-logic.sh` section 17 gains three cases that never edit the
   shipped templates: they run a temporary copy of `scripts/render-theme.sh`
   beside a temporary copy of `assets/templates/` (the script resolves
   `template_dir` from its own directory, so a copied tree works). A gating case
   disables one target and asserts its destination holds the no-op bytes while
   the others keep their palette bytes; an isolation case injects a broken
   template and asserts the other targets still write and the script exits
   non-zero; a brace case puts a literal `{{` that is not a token in a template
   and asserts it renders.

10. `scripts/check.sh` and `scripts/boot-check.sh` pass.

## Notes

`render-theme.sh` is POSIX `/bin/sh` (no `[[ ]]`, arrays, or `mapfile`); the CSV
split happens in Python. A disabled no-op is what keeps an include line or an
`enabledThemes` entry valid.
