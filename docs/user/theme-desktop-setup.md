# Theme desktop setup

The theme switcher renders the active palette into six desktop config files.
The renderer, `scripts/render-theme.sh`, runs on every palette load and change,
so the files stay in step with the selected theme. It writes:

- `~/.config/hypr/theme.lua`
- `~/.config/kitty/theme.conf`
- `~/.config/hypr/hyprlock/colors.conf`
- `~/.config/starship.toml`
- `~/.config/yazi/theme.toml`
- `~/.config/btop/themes/theme.theme`

The renderer substitutes colors into templates this repo owns
(`assets/templates/`) and never reads or evaluates a theme directory. It writes
a file only when the rendered bytes change, so a hand edit is reconciled on the
next palette load.

The shell (`services/ThemeService.qml`) passes the resolved palette to the
renderer through a `Process`, so the UI thread never blocks.

## One-time wiring

Some files outside this repo must be pointed at the rendered output once. The
renderer does not touch them. Starship and yazi have no include directive, so
the renderer owns `~/.config/starship.toml` and `~/.config/yazi/theme.toml`
outright and there is nothing to add. Hyprland, kitty, and hyprlock each need a
line added; btop needs a one-time pick in its own options menu.

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

### btop

Select the rendered theme in btop's own options menu: press `Esc`, move to
`Color theme`, and cycle with the arrow keys until the value reads `theme`.
btop applies it live and remembers it. The file is
`~/.config/btop/themes/theme.theme`, which the renderer owns and reconciles on
every palette load; the selected name does not change. btop re-scans its themes
directory whenever the options menu opens, so a file that appeared after btop
started is still listed, and `Ctrl+R` reloads it.

Pick it from the menu rather than hand-editing `color_theme`. btop lists user
themes by their absolute path, so a hand-written `color_theme = "theme"` loads
but the menu cannot match it: the counter is off by one (`<n>/<n-1>`) and the
arrow keys start from the wrong place. Selecting it in the menu stores the path
and the counter reads correctly.

`scripts/install.sh` seeds a default `theme.theme` when the file is absent, so
btop lists `theme` even before the shell has rendered a palette; the renderer
overwrites it with the active palette. The template is
`assets/templates/btop-theme.theme`; edit the template, not the rendered file.
Text painted on a colored ground (the process banner and the followed-process
row) uses the renderer's black-or-white `on_<role>` ink, matching the yazi
chips.

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

### starship

Starship reads one config file and has no include directive, so the renderer
overwrites `~/.config/starship.toml` whole. The prompt lives in the template
`assets/templates/starship-theme.toml`, which selects a palette named `theme`
whose roles come from the active theme:

```toml
[palettes.theme]
accent = '{{accent}}'
selection = '{{selection}}'
```

Edit the template, not the rendered file, for any prompt change. fish already
loads the file with `starship init fish | source`, so the shell needs no change.

Pill text keeps a module's hue when that hue contrasts with `selection`, and
falls back to a black-or-white ink chosen against `selection` when it does not.
That keeps a light theme whose selection and hues are all mid-tone (where a hue
can equal the pill or sit a shade off it) readable, while leaving a theme whose
hues already contrast unchanged. The renderer computes the choice.

### yazi

yazi reads one `theme.toml` and has no include directive, so the renderer owns
`~/.config/yazi/theme.toml` whole, the same way it owns the starship config.
The theme lives in `assets/templates/yazi-theme.toml`; edit the template, not
the rendered file. The template drops the flavor reference a stock yazi config
uses, so the colors come from the active palette rather than a static flavor.

Two details are worth knowing:

- Chip text. yazi paints chip text (tabs, modes, counts, markers) on a colored
  background. The renderer gives each hue used that way an `on_<role>` ink, the
  higher-contrast of black and white, so a light theme stays readable. Edit the
  mapping, not the `on_*` values, when changing a chip.
- Body text. Text painted on the app background keeps its hue when that hue
  contrasts with the background, and otherwise falls back to a black-or-white
  ink chosen against the background (`readable_<role>`). This mirrors the
  starship pill hardening for the manager, permission, and file-type colors.
- Code highlighting. Without a flavor there is no matching `.tmTheme` file, so
  the preview syntax theme falls back to the yazi preset; the rest of the UI
  follows the palette.

The rendered file takes the slot the flavor reference used to occupy. A yazi
whose `theme.toml` still carries `[flavor]` is repainted on the next palette
load, and `package.toml` can keep a flavor installed even once nothing points
at it. Unlike starship, yazi reads `theme.toml` once at startup, so an already
running yazi keeps its old colors until it is reopened.

## Verify

Switch themes (dashboard Theme block or `qs-theme set <name>`), then confirm the
rendered files match the palette:

```
grep -h . ~/.config/hypr/theme.lua ~/.config/kitty/theme.conf \
    ~/.config/hypr/hyprlock/colors.conf ~/.config/starship.toml \
    ~/.config/yazi/theme.toml ~/.config/btop/themes/theme.theme
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
desktop files match the bar's fallback; the shell normally starts on the bundled
darknight theme, so this default is reached only when no theme is active. A
malformed palette or a template with an unresolved placeholder exits without
writing.

## Backgrounds

Each theme ships images under its `backgrounds/` directory (the bundled
darknight theme ships two). The dashboard Theme block lists the trusted ones as
thumbnails and marks the current choice. Picking one remembers it for that theme
in the selection state and sends it to awww:

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
