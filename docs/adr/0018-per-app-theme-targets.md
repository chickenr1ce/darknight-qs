# ADR 0018: per-app theme targets, with Firefox and Vencord

Date: 2026-10-09. Feature: themed-apps.

## Context

The desktop retint writes six targets and writes all of them on every palette
change: Hyprland borders, kitty, hyprlock, starship, yazi, and btop. Nothing lets
a user keep one app off. The user wants Firefox and Vencord to follow the theme
too, and wants to choose, per app, which ones follow it.

Facts gathered before deciding:

- The Firefox profile is managed by Profile-sync-daemon.
  `~/.config/mozilla/firefox/b5dxo71e.default-release` is a symlink into psd's
  overlay mount, the durable copy is the sibling `-backup` directory, and no
  `chrome/` directory exists. The legacy pref
  `toolkit.legacyUserProfileCustomizations.stylesheets` is unset. A write through
  the profile path lands in the overlay and syncs back; a write to `-backup` can
  be deleted by psd's `--delete-after` resync. The default profile must be read
  from `installs.ini`, because `profiles.ini`'s `Default=1` names an empty stub.
- Discord runs native Vencord at `~/.config/Vencord`, themed by `system24`. That
  theme defines its own namespace (`--bg-*`, `--text-*`, `--accent-*`) and sets
  no Discord color variable itself; upstream `midnight.css` maps the namespace
  onto Discord's variables. `enabledThemes` order sets the cascade, Vencord reads
  it once at launch, and theme files hot-reload through a directory watcher.
- Omarchy core does not theme Firefox, Zen, or Vencord. It themes the
  Chromium family through a root-owned enterprise policy, and its per-app control
  lives in an unaffiliated addon that writes `prefs.js` and imports CSS over the
  network.

## Decision

The renderer writes a fixed set of themed apps. Each app has a template under
`assets/templates/`, a render case, and an on/off flag in a `theme-targets`
state file. A new Themed apps settings section lists every app as a toggle.
Firefox and Vencord join the six existing apps (Spicetify follows in the
amendment below).

A disabled app is not deleted from the pipeline. The renderer writes a valid
unthemed layer for it: a comment-only file where that is safe, or the built-in
no-theme default palette where the file is a whole config or defines variables
the app requires, so a user include line or an `enabledThemes` entry never points
at a missing file.

Content comes from the palette only. The renderer does not read app files from a
theme directory, which keeps ADR 0010 and ADR 0011 intact: only `colors.toml` and
`backgrounds/` are read.

Firefox is themed at the chrome. The renderer discovers the default profile from
`installs.ini`, writes a generated `chrome/shell-palette.css` through the profile path,
holding the palette as `:root` variables and the rules that map them onto
Firefox's own chrome variables, and manages the legacy-sheets pref as a
marker-delimited block in `user.js`, so a hand-written `user.js` keeps its other
lines. The user's own `userChrome.css` imports the generated file.
There is no `userContent.css` target, so pages are untouched, and the change
applies on the next Firefox start.

Vencord is recolored through its base theme. The renderer writes one generated
`.theme.css` that overrides `system24`'s namespace on `:root` and leaves
`--colors: on`. The user enables it once and orders it after
`system24.theme.css`. The shell never writes `settings.json`, and Vencord's
watcher applies a regenerated file without a restart.

Two renderer changes come with this. A target renders in isolation, so one
template's failure skips that app instead of aborting the whole retint. The
unresolved-placeholder check matches `{{token}}` shapes instead of any pair of
braces, so CSS braces in a template do not trip it.

## Alternatives considered

- **Ship per-theme app files, as omarchy does.** A theme directory could carry
  `vencord.theme.css` or `firefox.css` and the renderer could prefer it over the
  template. Broader, but it reintroduces the asymmetry that leaves `ash` and
  `outpost` unthemed while `harbor` is themed, and it makes the shell read app
  files from a theme directory, which ADR 0010 keeps out. Rejected.
- **Override Discord's own color variables, with `!important`.** The `harbor`
  bundle does this. Under `system24` it produces a mixed palette, because
  `system24`'s structural rules keep reading its own namespace while the Discord
  variables change, and the modern names it would need are not the legacy ones.
  Rejected.
- **Have the renderer enable the Vencord theme in `settings.json`, or set the
  Firefox pref in `prefs.js`.** Neither file is watched for reload, and Firefox
  rewrites `prefs.js` on shutdown, so both edits get clobbered. Rejected; the user
  enables the theme once, and the pref goes in `user.js`.
- **Bolt on the third-party `theme-hook-plugin-manager`.** It reads omarchy state
  paths, writes `prefs.js`, and pulls Discord CSS over the network at runtime.
  Rejected; this shell owns its own render path.
- **Write the Firefox profile through `-backup`.** Wrong while psd runs, and
  vulnerable to `--delete-after`. Rejected for the profile path.
- **Inject the `@import` line into `userChrome.css` automatically.** It would
  make Firefox work with no manual step, but it edits a user-owned file.
  Rejected; the user adds one line, as with the hypr, kitty, and hyprlock
  includes.

## Consequences and known limits

- The Vencord target assumes a `system24`/midnight-style base theme, because it
  overrides that theme's namespace. If the base theme changes, the generated file
  defines variables nothing consumes. This coupling is deliberate and documented.
- Firefox userChrome is not supported by Mozilla and has broken across releases.
  The target stays chrome-only so a page is never restyled, and the selectors may
  need upkeep after Firefox updates.
- Themed apps apply on the next app start, except Vencord, whose watcher reloads
  the file.
- A Firefox profile that cannot be resolved is skipped with a `firefox: no
  profile` warning on stderr and does not count as a render failure.
- A disabled target writes a valid unthemed layer. Where a comment-only file is
  safe (`--` for Lua, `#` for the shell-shaped files, `/* */` for CSS) it
  writes one, so a disabled Lua target still parses when the user's config
  `require`s it. Where the file is a whole config or defines variables the
  app requires (starship, hyprlock) it renders the built-in no-theme default
  palette instead, because a comment-only file would wipe the prompt or leave
  hyprlock's `$theme_*` undefined.
- `docs/user/theme-desktop-setup.md` and `CONTEXT.md` say the retint writes six
  files. Both move to nine targets (twelve files) and gain Firefox, Vencord, and
  Spicetify wiring sections.
- The Firefox root resolves to `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox`
  (falling back to `$HOME/.mozilla/firefox`), so tests redirect both
  `XDG_CONFIG_HOME` and `HOME`.

## Amendments

- 2026-10-09 (Spicetify target): Spotify joins through Spicetify, as a ninth
  target. The renderer ships the community `text` theme (MIT, vendored as
  templates under `assets/templates/`) into a shell-owned
  `~/.config/spicetify/Themes/quickshell/` directory, keeping the theme's own
  default color options and appending one `Quickshell` color option built from
  the palette. It owns the whole theme directory, so it never edits a theme the
  user installed. The user selects the theme and the color option once, like the
  Vencord enable and the Firefox import. A render finishes with a best-effort
  `spicetify refresh`, never `spicetify apply`, which is version-gated on this
  machine and force-restarts the client. Disabled, the color option is rendered
  from the theme's own default values rather than removed.
- 2026-10-10 (Spicetify selection): "selects once" above is unconfirmed. Whether
  a plain `spicetify refresh` picks up the theme and color-option selection, or
  the user must run a version-gated `spicetify restore backup apply` (repeated
  after every Spotify update), is settled live by the Spicetify ticket before
  the user docs describe the step.
- 2026-10-10 (Spicetify selection resolved): the selection is path (b). The live
  run used spicetify-cli 2.45.3 against Spotify 1.2.79.427.g80eb4a07, with
  `[Backup] with = 2.42.8` before it. Plain `refresh` rewrote `xpui/colors.css`
  but the client kept the old colors, because only `apply` rewrites
  `xpui/index.html`; `apply` refused as outdated, and
  `spicetify restore backup apply` succeeded, moving `with` to 2.45.3. The
  one-time step is `spicetify config current_theme quickshell color_scheme
  Quickshell` then `spicetify restore backup apply`. It restarts Spotify,
  replaces a Marketplace-managed theme, and must be re-run after every Spotify
  update. Later retints stage through `refresh`, never `apply`, and appear on
  the next Spotify start, not live.
- 2026-10-10 (Vencord cascade order): the Decision above has the user order the
  generated theme after `system24.theme.css`, but Vencord's Themes UI cannot
  reorder enabled themes, and the live `enabledThemes` array puts
  `system24.theme.css` last, so its own `:root` base variables tied the
  generated `:root` at specificity (0,1,0) and won on source order. The
  generated block now selects `:root:root` (0,2,0), which outranks system24's
  plain `:root` whatever order the two load in, so ordering no longer matters
  and the UI needs no reorder. The user still enables the theme once and
  restarts Discord once. `!important` remains rejected (see the alternatives
  above); the fix raises specificity instead.
- 2026-10-10 (Firefox accent and content sheets): live testing on a light
  palette (background `#eee8da`, accent `#795334`) found the chrome accent
  unmapped. The original template defined `--shell-accent` but no Firefox
  token read it, so focus rings, attention icons, primary buttons, the urlbar
  focus border, checkboxes, and panel links kept Firefox's default accent. The
  `about:newtab`/`about:home` pages followed the system dark scheme, because
  they are content documents `userChrome.css` cannot reach. The chrome
  sheet now maps the palette accent onto Firefox 157's tokens
  (`--color-accent-primary` and its hover/active/selected variants,
  `--focus-outline-color`, `--link-color`, the primary-button background and
  text, `--toolbarbutton-icon-fill-attention`, `--tab-loading-fill`,
  `--toolbar-field-border-color-focus`) with the on-accent ink
  (`--shell-on-accent`, the black-or-white ink chosen against the accent) for
  primary-button text and `color-mix` ladders toward the foreground for
  hover/active. The guessed `--toolbar-field-focus-border-color` does not exist
  in 157; the real token is `--toolbar-field-border-color-focus`. The
  search-engine switcher pill has no token of its own, so a scoped
  `.searchmode-switcher` rule themes its muted-button variables. Firefox now
  contributes three files: the chrome sheet, a second generated
  `chrome/shell-content.css` scoped with
  `@-moz-document url("about:newtab"), url("about:home"),
  url("about:privatebrowsing")` that sets the newtab page's own `--newtab-*`
  variables, the search box element's `--content-search-handoff-ui-*` values,
  the `html.private` canvas/text/link/banner/info/promo colors
  `about:privatebrowsing` paints from its own sheet, and a `color-scheme`
  matching the palette mode, from the palette, and `user.js`. The user imports
  `shell-content.css` from
  their own `userContent.css` as its first line, exactly as they import
  `shell-palette.css` from `userChrome.css`; the renderer still never creates or
  edits a user sheet, so the earlier "never names `userContent.css`" rule
  relaxes to "never writes `userContent.css`". Disabled, both sheets are
  comment-only.
