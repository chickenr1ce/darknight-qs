# Ticket 01: renderer target gating and isolation

**Status:** ready-for-agent
**Blocking:** ticket 02
**Blocked by:** none

## Objective

Give the desktop retint a per-target on/off switch, and stop one target's
failure from aborting the rest. The renderer keeps writing every target it can;
a target the user switched off renders a valid, unthemed layer instead of a
missing file.

This is the largest ticket. It rewrites the renderer's job loop into per-target
functions and adds the state seam; if it feels too big to hold, split the
renderer core (criteria 1-4, 7-8) from the QML state and tests (5-6, 9-11).

## Acceptance criteria

1. `scripts/render-theme.sh` gains an optional second positional argument: a
   comma-separated list of enabled target keys. Preserve the presence of the
   argument, because `${2:-}` collapses absent and empty to the same string and
   cannot express the contract. In the `/bin/sh` wrapper: if `"$#"` is at least
   2, forward `$2` verbatim; otherwise forward the sentinel `__ALL__`. Pass it as
   the fourth Python argument, so `sys.argv[1:5]` is palette, template_dir,
   config_home, enabled_keys. Python checks `argv[4] == "__ALL__"` **before**
   splitting (after a split the sentinel would be dropped as an unknown key and
   mean all-off, the inverse); otherwise it splits on `,`, strips whitespace,
   drops empty entries, and ignores unknown keys. `__ALL__` enables every target;
   an empty string enables none. The one-argument invocations in
   `scripts/test-panel-logic.sh` section 17 keep rendering every target.

2. The renderer dispatches each target through a per-target render function, so a
   target may compute its own destination, write more than one file, or merge
   into an existing file (tickets 03 and 05). Each target renders and writes in
   isolation: a target whose template is missing, or whose rendered bytes still
   hold an unresolved token, logs a line naming the target to stderr and is
   skipped as a failure, and the other targets still write. A target with no
   destination at all (no Firefox profile, no Vencord install, Spicetify not
   installed) is skipped as success. `write_if_changed` returns whether it wrote,
   and the render function propagates that per target so the Spicetify target
   (ticket 05) can refresh only on a real change. Exit status is zero when every
   enabled target wrote or skipped as success and every disabled target wrote its
   disabled layer or skipped as success; non-zero when at least one target
   failed.

3. The unresolved-token check matches the regex `\{\{[A-Za-z0-9_]+\}\}`. A
   literal `{{` or `}}` that does not form that shape renders without failing.

4. A disabled target must leave its app valid and unthemed, so the disabled layer
   depends on the destination:
   - A file the renderer owns whole that is a complete config (`starship.toml`)
     or that defines variables the app requires (hyprlock `colors.conf`) renders
     the renderer's built-in no-theme default palette, not a comment. Move the
     default palette literal into the Python heredoc so the wrapper and the
     disabled path share one source, and keep the existing `sh render-theme.sh ""`
     behavior (it writes the defaults) passing.
   - Every other destination writes a comment-only no-op in its own comment
     syntax (`--` for `hypr-theme.lua`, `#` for kitty, yazi, and btop, `/* */`
     for the CSS targets): kitty, yazi, btop, `hypr-theme.lua`, the Firefox
     palette sheet, and the Vencord theme, except that a disabled Vencord file
     keeps its banner and metadata header (ticket 02) so the theme stays listed.
     Firefox's `user.js` is not touched and not created (ticket 03); Spicetify's
     layer is defined in ticket 05.
   Before closing, verify each comment-only target with a live disable/enable
   cycle (kitty, yazi, btop, `hypr-theme.lua`), or cite the app's parser behavior
   for tolerating an empty file; if any rejects it, extend the default-palette
   rule. The disabled bytes are stable across palettes and `write_if_changed`
   still skips an unchanged write.

5. `services/ThemeService.qml` exposes `readonly property var themeTargets`,
   nine `{ key, title }` entries in render order, titles wrapped in `qsTr()`:
   `hyprland` "Hyprland borders", `kitty` "kitty", `hyprlock` "hyprlock",
   `starship` "starship", `yazi` "yazi", `btop` "btop", `firefox` "Firefox",
   `vencord` "Vencord", `spicetify` "Spicetify".

6. `ThemeService` exposes `themeTargetEnabled: ({})` and
   `isThemeTargetEnabled(key)` / `setThemeTargetEnabled(key, enabled)`, persisted
   through `StateFile { name: "theme-targets" }`. The setter ignores an unknown
   key and replaces the whole map with a fresh object (the
   `BarVisibilityService.setVisible` precedent at
   `services/BarVisibilityService.qml:78-87`) so the change signal fires. Model
   the parse, apply, save, and equality helpers on `BarVisibilityService`
   (`hasModule`, `sameVisibility`, `applyVisibility`, `saveVisibility`). The
   guard against a load, assign, save, change loop is the `sameTargets`
   early-return in apply combined with `StateFile`'s own `loading || !loaded`
   refusal.

7. Extend the renderer's `tokens` beyond `REQUIRED` (the current dict lacks
   `darker_background`, `dark_foreground`, `light_foreground`, `orange`, and
   `brown`, so a Vencord `--bg-4` or Spicetify `header` would fail the
   unresolved-token check). Add those optional palette roles when the palette
   carries them, with fallbacks when it does not (`darker_background` to
   `dark_background`, `dark_foreground` to `muted`, `light_foreground` to
   `foreground`, `orange` to `yellow`, `brown` to `red`). Do not add them to
   `REQUIRED`; a missing required role currently exits zero and writes nothing,
   and the light fixture in section 17 carries no `orange`/`brown`. Add a
   bare-hex form `<role>_hex` (six hex digits, no `#`) for the INI target in
   ticket 05; `{{role}}` stays `#rrggbb`. Add `orange`/`brown` to the wrapper's
   hardcoded default palette. Add the mode-aware text ramp the Vencord template
   needs, pre-computed with the existing contrast helpers because the template
   cannot branch on `mode`: `background_ink` and `text_1` through `text_5`
   (five steps ordered by contrast against `background` for the palette's mode),
   plus any accent-ink token the template needs.

8. The map parses and serializes through `services/ThemeParsers.js`:
   `parseTargets(jsonText, keys)` (an absent key reads as enabled, only an
   explicit `false` disables, an unknown key is dropped, mirroring
   `services/StateParsers.js` `parseVisibility`) and
   `serializeTargets(map, keys)` (every key, boolean values). `ThemeService`
   keeps one-line delegating call sites, and the assertions extend the
   `ThemeParsers` node run under `tests/qmljs.js`.

9. `ThemeService` exposes `readonly property string enabledThemeTargetKeys`, the
   comma-joined enabled keys in `themeTargets` order.
   `idRenderProcess.command` is
   `["sh", root.renderScriptPath, root.renderPaletteJson, root.enabledThemeTargetKeys]`,
   so the second argument is always present (all-off sends `""`), and
   `onThemeTargetEnabledChanged` re-renders through the same deferred
   `renderDesktop` path the palette change uses (`services/ThemeService.qml:101`).
   Gate the first render until both the palette and `theme-targets` have resolved
   once (a `targetsLoaded` flag). An absent `theme-targets` file (a fresh
   install) counts as resolved, all targets enabled; otherwise the first render
   never runs. Without the gate, startup renders all-enabled from the
   palette path before the state file parses, then re-renders the disabled
   layers: Vencord's watcher would flash the themed file, and Spicetify would run
   `refresh` twice per startup.

10. `scripts/test-panel-logic.sh` section 17 gains cases that never edit the
    shipped templates. A temp copy must mirror the repo layout
    (`$TMP/scripts/render-theme.sh` beside `$TMP/assets/templates/`), because the
    script resolves `template_dir` as `$script_dir/../assets/templates`. Cover: a
    one-argument invocation renders every target (backward compatibility), a
    two-argument empty string renders every disabled layer, a single-target-off
    case, an isolation case (a broken template skips only its target while the
    script exits non-zero), and a brace case (a literal `{{` that is not a token
    renders). Assert that disabled starship and hyprlock still carry the default
    `{{role}}` values, not comments. Prepend the stub directory to `PATH` and
    assert via `command -v` that the stub, not the real binary, resolves, so the
    gate can never drive the live Spotify session. Redirect `HOME` as well as
    `XDG_CONFIG_HOME` for **every** invocation in the section, not only the new
    cases, because the Vencord, Spicetify, and Firefox destinations all resolve
    under a home.

11. `scripts/check.sh` and `scripts/boot-check.sh` pass.

## Notes

`render-theme.sh` is POSIX `/bin/sh` (no `[[ ]]`, arrays, or `mapfile`); the CSV
split happens in Python. A disabled layer keeps an include line or an
`enabledThemes` entry valid.
