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
Firefox and Vencord join the six existing apps.

A disabled app is not deleted from the pipeline. The renderer writes a no-op
layer for it, a comment-only file or an empty override block, so a user include
line or an `enabledThemes` entry never points at a missing file.

Content comes from the palette only. The renderer does not read app files from a
theme directory, which keeps ADR 0010 and ADR 0011 intact: only `colors.toml` and
`backgrounds/` are read.

Firefox is themed at the chrome. The renderer discovers the default profile from
`installs.ini`, writes a generated `chrome/shell-palette.css` holding `:root`
variables through the profile path, and writes a `user.js` carrying the
legacy-sheets pref, unless a hand-written `user.js` already sits there, in which
case the renderer leaves it alone and warns. The user's own `userChrome.css`
imports the generated file.
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
- A disabled target writes a comment-only file in that destination's own
  language (`--` for Lua, `#` for the shell-shaped files, `/* */` for CSS, `//`
  for `user.js`), so a disabled Lua target still parses when the user's config
  `require`s it.
- `docs/user/theme-desktop-setup.md` and `CONTEXT.md` say the retint writes six
  files. Both move to eight and gain a one-time Firefox wiring section.
- Tests that redirect `XDG_CONFIG_HOME` must also redirect `HOME`, because the
  Firefox profile lives under `~/.config/mozilla`, not under `XDG_CONFIG_HOME`.

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
