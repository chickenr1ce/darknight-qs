# Theme desktop setup

The theme switcher renders the active palette into the desktop config files for
nine targets and twelve files, because Firefox contributes three and Spicetify
two. The renderer, `scripts/render-theme.sh`, runs on every palette load and
change, so the files stay in step with the selected theme. It writes:

- `~/.config/hypr/theme.lua`
- `~/.config/kitty/theme.conf`
- `~/.config/hypr/hyprlock/colors.conf`
- `~/.config/starship.toml`
- `~/.config/yazi/theme.toml`
- `~/.config/btop/themes/theme.theme`
- the active Firefox profile's `chrome/shell-palette.css`,
  `chrome/shell-content.css`, and `user.js`
- `~/.config/Vencord/themes/quickshell.theme.css`
- `~/.config/spicetify/Themes/quickshell/color.ini` and `user.css`

The renderer substitutes colors into templates this repo owns
(`assets/templates/`) and never reads or evaluates a theme directory. It writes
a file only when the rendered bytes change, so a hand edit is reconciled on the
next palette load.

Settings → Themed apps turns each target on or off. A target renders in
isolation, so a broken template skips that app and the rest still write (the run
exits non-zero), and a switched-off target writes a valid unthemed layer instead
of a missing file.

The shell (`services/ThemeService.qml`) passes the resolved palette to the
renderer through a `Process`, so the UI thread never blocks.

## One-time wiring

Some files outside this repo must be pointed at the rendered output once. The
renderer does not touch them. Starship and yazi have no include directive, so
the renderer owns `~/.config/starship.toml` and `~/.config/yazi/theme.toml`
outright and there is nothing to add. Hyprland, kitty, hyprlock, and Firefox
each need a line added (Firefox needs two, one per sheet); btop needs a
one-time pick in its own options menu; and Vencord and Spicetify each need a
one-time selection in the app.

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

### Firefox

Firefox follows the palette through three generated files in the active
profile: two sheets and a pref block. The browser chrome reads
`chrome/shell-palette.css`. The `about:newtab`, `about:home`, and
`about:privatebrowsing` pages read `chrome/shell-content.css`, because they are
content documents the chrome sheet cannot reach. `user.js` enables custom
stylesheets. The renderer writes all three and never edits either of your own
user sheets (`userChrome.css`, `userContent.css`).

Point your own `userChrome.css` and `userContent.css` at the generated sheets
once. Each `@import` must be the file's **first** line: CSS ignores an
`@import` that follows any other rule.

```css
@import url("shell-palette.css");
```

```css
@import url("shell-content.css");
```

This one-liner finds the default profile from `installs.ini` and prepends the
chrome import, creating `userChrome.css` if it is absent and doing nothing if
the line is already there. It is safe to paste into fish:

```bash
bash -c 'r=~/.config/mozilla/firefox; [ -d "$r" ] || r=~/.mozilla/firefox; d=$(sed -n "s/^Default=//p" "$r/installs.ini" 2>/dev/null | head -1); [ -n "$d" ] || { echo "no firefox profile found" >&2; exit 1; }; f=$r/$d/chrome/userChrome.css; l="@import url(\"shell-palette.css\");"; grep -qxF "$l" "$f" 2>/dev/null || { mkdir -p "$(dirname "$f")"; printf "%s\n" "$l" | cat - "$f" 2>/dev/null > "$f.tmp"; mv "$f.tmp" "$f"; }'
```

The matching one for `userContent.css`:

```bash
bash -c 'r=~/.config/mozilla/firefox; [ -d "$r" ] || r=~/.mozilla/firefox; d=$(sed -n "s/^Default=//p" "$r/installs.ini" 2>/dev/null | head -1); [ -n "$d" ] || { echo "no firefox profile found" >&2; exit 1; }; f=$r/$d/chrome/userContent.css; l="@import url(\"shell-content.css\");"; grep -qxF "$l" "$f" 2>/dev/null || { mkdir -p "$(dirname "$f")"; printf "%s\n" "$l" | cat - "$f" 2>/dev/null > "$f.tmp"; mv "$f.tmp" "$f"; }'
```

If the `@import` line is already in the file but not on line 1, these one-liners
leave it alone and it is ignored; move it to line 1 yourself. Use the one-liner
only on a file whose first line is the import or nothing.

The pref block is managed between markers, so a hand-written `user.js` keeps
its other lines:

```
// BEGIN quickshell
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// END quickshell
```

Only that block is managed: the other prefs in a hand-written `user.js` survive,
a pref set outside the markers is adopted into the block rather than duplicated,
and `prefs.js` is never rewritten. The one pref covers `userContent.css` as well
as `userChrome.css`.

The sheets were verified against Firefox 157.0.1. Their chrome and newtab
variables are Firefox internals and have been renamed across releases, so the
templates may need upkeep after a Firefox upgrade; a renamed variable fails
cosmetically (the surface falls back to its built-in value), not as a render
error.

The renderer resolves the default profile from `installs.ini` (its `Default=`)
and writes through the profile path, which Profile-sync-daemon syncs back; the
path is valid whether psd is running or stopped, and its symlink is followed,
never resolved. The root is
`${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox`, falling back to
`$HOME/.mozilla/firefox`; Snap and Flatpak Firefox roots are not supported. With
no profile, the target logs `firefox: no profile` and skips as success (the run
still exits zero), unlike a broken template, which fails the run. A restart
applies the change. Switching Firefox off in Themed apps writes a comment-only
`shell-palette.css` and `shell-content.css` (stock Firefox and stock newtab
through the same imports) and leaves `user.js` untouched.

### Vencord

Discord is recolored through the installed `system24` theme. The renderer writes
`~/.config/Vencord/themes/quickshell.theme.css`, which overrides `system24`'s
own namespace variables and leaves its layout and its derived colors
alone. `--text-0` is the one deliberate override: it carries the on-accent ink,
so icons and badges are not painted with the background. Enable the theme once
in Vencord.

The override block uses the `:root:root` selector, which outranks `system24`'s
plain `:root` on specificity, so the shell palette wins whatever order Vencord
loads the themes in. The `enabledThemes` order does not matter, which is what
makes the theme work despite Vencord's UI not offering a way to reorder enabled
themes. Vencord reads the list once at launch, so restart Discord once after
enabling it. The shell never edits `settings.json`; enablement stays manual.

The generated theme depends on a `system24`/midnight-style base theme by design:
if the base theme changes or is removed, the variables the file sets are
consumed by nothing. Once enabled, the file hot-reloads through Vencord's theme
watcher, so later retints show without a restart.

Two known limits:

- `midnight.css` ships upstream debug placeholders (for example a disabled
  danger button stays `lime`, and the outline-brand hover and active states stay
  blue and magenta). They are literal values in the base theme, not derived from
  the variables this shell sets, so any namespace override leaves them in place.
  Expect a few unthemed accents rather than none.
- On a light palette, links, hover borders, and accent buttons can be hard to
  read: system24 builds its accent ladder by mixing the accent toward white,
  which loses contrast on a light background.

### Spicetify

The renderer ships the community `text` theme as a shell-owned theme under
`${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/Themes/quickshell/`, as two files:
`color.ini` and `user.css`. The theme keeps the default color options it ships
(MIT, copyright 2019 morpheusthewhite), and the renderer appends one `Quickshell`
color option built from the palette. This repo maintains the vendored `user.css`,
pinned to upstream commit `33a08ea009687f5a42ff678015c28797fe142a7c`; upstream
changes do not reach you until that template is updated. The renderer owns only
those two files: it never edits a theme you installed (for example
`Themes/text/`) or `config-xpui.ini`, and it does not delete unknown files in the
directory.

Select the theme and its color option with these two commands:

```
spicetify config current_theme quickshell color_scheme Quickshell
spicetify restore backup apply
```

`restore backup apply` restarts Spotify. A theme selection only reaches the
generated `xpui/index.html` through `apply`, so `config` plus `refresh` alone
does not take effect. Plain `spicetify apply` refuses with "Preprocessed Spotify
data is outdated" when the installed CLI outpaces the recorded backup, which is
why the `restore` form is the one that works; it replaces whatever theme was
selected before (for example a Marketplace-managed theme — the Marketplace app
itself stays). Re-run the apply step after every Spotify update, as with any
Spicetify setup.

After selection, the renderer refreshes the client with `spicetify refresh`
best-effort whenever a Spicetify file's bytes change; it never runs
`spicetify apply`. A refresh stages the new colors in `xpui/colors.css`, and they
appear on the **next Spotify start**, not live. When Spicetify's config directory
is absent, the target logs `spicetify: not installed` and skips as success (the
run still exits zero), unlike a broken template, which fails the run. Switching
Spicetify off in Themed apps renders the theme's own `[Spicetify]` default colors
into `color.ini` and still writes `user.css`, which is the theme's layout, not a
color layer.

## Verify

Switch themes (dashboard Theme block or `qs-theme set <name>`), then confirm the
rendered files match the palette:

```
grep -h . ~/.config/hypr/theme.lua ~/.config/kitty/theme.conf \
    ~/.config/hypr/hyprlock/colors.conf ~/.config/starship.toml \
    ~/.config/yazi/theme.toml ~/.config/btop/themes/theme.theme \
    ~/.config/Vencord/themes/quickshell.theme.css \
    ~/.config/spicetify/Themes/quickshell/color.ini \
    ~/.config/spicetify/Themes/quickshell/user.css
grep -h . ~/.config/mozilla/firefox/*/chrome/shell-palette.css \
    ~/.config/mozilla/firefox/*/chrome/shell-content.css \
    ~/.config/mozilla/firefox/*/user.js
# under the fallback root:
grep -h . ~/.mozilla/firefox/*/chrome/shell-palette.css \
    ~/.mozilla/firefox/*/chrome/shell-content.css \
    ~/.mozilla/firefox/*/user.js
```

The two Firefox paths are profile-relative because the profile name varies; the
root follows `XDG_CONFIG_HOME` and falls back to `~/.mozilla/firefox` when that
root is absent. Neither Firefox file exists until a profile resolves.

For a visual check, capture a bordered window and a kitty window with
`grim -g "x,y WxH"` and compare the border and background to the active
`colors.toml`.

## Running the renderer by hand

The renderer takes the palette as JSON, the same object `ThemeParsers.parseColors`
returns, and an optional second argument: a comma-separated list of the target
keys to write (`hyprland`, `kitty`, `hyprlock`, `starship`, `yazi`, `btop`,
`firefox`, `vencord`, `spicetify`). With no second argument every target is
enabled; an empty string disables all of them. The shell passes the list from
Settings → Themed apps.

```
sh scripts/render-theme.sh '{"mode":"dark","accent":"#7aa2f7", ...}'
sh scripts/render-theme.sh '{"mode":"dark","accent":"#7aa2f7", ...}' kitty,firefox
```

Each target renders in isolation: a broken template is skipped with a line on
stderr naming it, the other targets still write, and the script exits non-zero.
A disabled target writes a valid unthemed layer instead of a missing file.

Output paths follow `XDG_CONFIG_HOME`, falling back to `HOME/.config`, so a test
can redirect them — except Firefox, whose root the script resolves from the
environment as `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox`, falling back
to `$HOME/.mozilla/firefox`. An empty palette renders the built-in no-theme
default, so the desktop files match the bar's fallback; the shell normally starts
on the bundled darknight theme, so this default is reached only when no theme is
active. A malformed palette is a no-op.

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
