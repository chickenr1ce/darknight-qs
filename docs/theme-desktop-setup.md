# Theme desktop setup

The theme switcher renders the active palette into three desktop config files.
The renderer, `scripts/render-theme.sh`, runs on every palette load and change,
so the files stay in step with the selected theme. It writes:

- `~/.config/hypr/theme.lua`
- `~/.config/kitty/theme.conf`
- `~/.config/hypr/hyprlock/colors.conf`

The renderer substitutes colors into templates this repo owns
(`assets/templates/`) and never reads or evaluates a theme directory. It writes
a file only when the rendered bytes change, so a hand edit is reconciled on the
next palette load.

The shell (`services/ThemeService.qml`) passes the resolved palette to the
renderer through a `Process`, so the UI thread never blocks.

## One-time wiring

Three files outside this repo need a line added. The renderer does not touch
them; add the lines yourself once.

### Hyprland borders

Add `require("theme")` at the **end** of `~/.config/hypr/modules/looks.lua`. It
must come after the file's own `hl.config({ general = ... })` so the rendered
border colors win:

```lua
require("theme")
```

`require("theme")` resolves to `~/.config/hypr/theme.lua`, next to
`hyprland.lua`. The borders honor a theme's `hyprland_active_border` and
`hyprland_inactive_border` keys when it has them, and otherwise derive from
`accent` (inactive at reduced alpha).

### kitty

In `~/.config/kitty/kitty.conf`, replace the theme include with:

```
include theme.conf
```

The `# BEGIN_KITTY_THEME` / `# END_KITTY_THEME` markers can stay; only the
included file changes.

### hyprlock

Add this line at the **top** of `~/.config/hypr/hyprlock.conf`, before any
widget block:

```
source = ~/.config/hypr/hyprlock/colors.conf
```

The sourced file defines `$theme_background`, `$theme_foreground`,
`$theme_accent`, `$theme_muted`, and `$theme_danger`. Point the widget color
fields at them, for example:

```
background {
    color = $theme_background
}

input-field {
    outer_color = $theme_accent
    check_color = $theme_accent
    fail_color = $theme_danger
    font_color = $theme_foreground
}
```

## Verify

Switch themes (dashboard Theme block or `qs-theme set <name>`), then confirm the
rendered files match the palette:

```
grep -h . ~/.config/hypr/theme.lua ~/.config/kitty/theme.conf \
    ~/.config/hypr/hyprlock/colors.conf
```

For a visual check, capture a bordered window and a kitty window with
`grim -g "x,y WxH"` and compare the border and background to the active
`colors.toml`.

## Running the renderer by hand

The renderer takes the palette as JSON, the same object `ThemeParsers.parseColors`
returns:

```
sh scripts/render-theme.sh '{"mode":"dark","accent":"#7aa2f7", ...}'
```

Output paths follow `XDG_CONFIG_HOME`, falling back to `HOME/.config`, so a test
can redirect them. An empty palette renders the built-in no-theme default, so the
desktop files match the bar's fallback. A malformed palette or a template with an
unresolved placeholder exits without writing.

## Backgrounds

Each theme ships images under its `backgrounds/` directory. The dashboard Theme
block lists the trusted ones as thumbnails and marks the current choice. Picking
one remembers it for that theme in the selection state and sends it to awww:

```
awww img <theme root>/<theme>/backgrounds/<file>
```

The `awww-daemon` already runs from autostart. Switching themes reapplies the
remembered image, or the first image in order when the theme has no remembered
choice, through the same `ThemeService` render path that runs the palette
renderer, so the shell is the only writer.

Images are listed only when they are regular files directly inside
`backgrounds/`, are not symlinks, have extension jpg, jpeg, png, webp, or bmp,
and are at most 32 MB. A theme with no such image applies nothing.
