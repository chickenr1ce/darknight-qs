# Ticket 02 -> ticket 04 handoff

Ticket 04 owns the user docs. Two findings from ticket 02 must land in
`docs/user/theme-desktop-setup.md`.

## 1. Disclosure: upstream debug placeholders survive the override

Any `:root` namespace override leaves the base theme's literal debug values in
place, because they are not derived from the palette variables we set. In the
built `midnight.css`
(`https://refact0r.github.io/midnight-discord/build/midnight.css`, sha256
`928fe2279f44c1c3d44baf7e940a67c28731dbc6088c778a77a935a49036b2e2`), inside the
`@container root style(--colors: on)` block, the button-state examples are:

```
--button-danger-background-disabled: lime;
--button-outline-brand-background-hover: blue;
--button-outline-brand-border-active: magenta;
```

Document these as a known cosmetic limit: a disabled danger button, and the
outline-brand hover/active states, keep the upstream bright debug colors.

Caution for the doc author: these three are the *button* examples, not the
only ones. The same active `lime`/`magenta`/`blue` debug pattern repeats 84
times across midnight's Discord namespace (cards, chips, checkboxes, expressive
gradients, panels, and so on). A live button/UI sweep should expect more
unthemed accents than just these three, and the wording should call the debug
placeholders a known upstream artifact rather than claim none remain.

## 2. Needs a live check: light-mode accent-ladder link contrast

The `--purple-*` ladder is built as `color-mix(in srgb, accent <pct%>,
bright_foreground)`, and system24 drives links and hover borders from it
(`--accent-1: var(--purple-1)`, `--border-hover: var(--accent-2)`). On a light
palette the mix drifts the accent toward white, so links lose contrast against
a light background. Measured against the ticket's own light fixture
(`background #f5f5f5`, `accent #7aa2f7`, `bright_foreground #ffffff`):

```
--purple-1 #b6ccfb   1.48:1   (--accent-1 = link color)
--purple-2 #a2bef9   1.71:1
--purple-3 #92b3f8   1.92:1
--purple-4 #85a9f8   2.13:1
--purple-5 #7aa2f7   2.31:1
```

All five are far below the 4.5:1 body-text threshold, and the ladder only gets
lighter as it goes to `--purple-1`. The test's text-ramp contrast check does not
cover this because it validates `--text-1..5`, not the accent ladder. Flag this
for a live look in Discord on a light theme: links, hover borders, and accent
buttons may be hard to read, and the fix may need to mix toward the mode's
background ink (or a darker step) for light palettes rather than always toward
`bright_foreground`.

# Ticket 03 -> ticket 04 handoff

Ticket 04 owns the user docs. The Firefox findings below land in
`docs/user/theme-desktop-setup.md`.

## 1. Chrome variables verified against Firefox 157.0.1; no stability promise

The generated sheet `chrome/shell-palette.css` maps the palette onto 18
Firefox chrome variables. All 18 resolve on the installed Firefox 157.0.1
(checked 2026-10-10 by extracting `browser/omni.ja` and `omni.ja` and grepping
the chrome skin):

- `--toolbar-background-color`, `--toolbar-text-color`,
  `--toolbar-field-background-color`, `--toolbar-field-background-color-focus`,
  `--sidebar-background-color`, `--sidebar-text-color` — defined on `:root` in
  `chrome/toolkit/skin/classic/global/design-system/tokens-shared.css`.
- `--urlbar-box-background-color`, `--urlbar-box-background-color-focus`,
  `--urlbar-box-text-color`, `--toolbar-field-text-color`,
  `--toolbar-field-text-color-focus` — defined in the browser's
  `urlbar/urlbar.tokens.css` and `urlbar.css`.
- `--panel-background-color`, `--panel-border-color` — defined in
  `chrome/toolkit/skin/classic/global/{popup,menu}.css`.
- `--tab-background-color-selected`, `--tab-text-color-selected` — defined in
  `browser/tabbrowser/tab.tokens.css`.
- `--sidebar-border-color` — defined in `browser/sidebar.css`.
- `--lwt-accent-color`, `--lwt-text-color` — Firefox lightweight-theme (LWT)
  variables set at runtime, not statically in a sheet.

These are Firefox internals and have been renamed across releases. The doc
wording must say the sheet was verified against Firefox 157 and may need
template upkeep after an upgrade — do not promise stability. If Firefox renames
one, the failure is cosmetic (the chrome falls back to its built-in value), not
a render failure.

## 2. User-facing behaviors the docs must state

- One-time step: create the profile's `userChrome.css` with a single
  `@import url("shell-palette.css");` as its **first** line. It must be first:
  an `@import` after any other rule is ignored by CSS. The renderer never edits
  `userChrome.css`.
- Chrome only. Pages and about: pages are untouched; there is no
  `userContent.css` target.
- The legacy-sheets pref
  (`toolkit.legacyUserProfileCustomizations.stylesheets`) goes in a
  marker-delimited block (`// BEGIN quickshell` … `// END quickshell`) in
  `user.js`. Other prefs in a hand-written `user.js` survive, a pref set outside
  the markers is adopted into the block rather than duplicated, and `prefs.js`
  is never rewritten.
- Profile resolution: the default profile comes from `installs.ini` (its
  `Default=` in the `[<hash>]` or `[Install<hash>]` section), not
  `profiles.ini`'s `Default=1` stub; `profiles.ini` is consulted only to resolve
  `IsRelative` / an absolute `Path`. The root is
  `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox`, falling back to
  `$HOME/.mozilla/firefox`. Snap and Flatpak Firefox roots are out of scope.
- Write path: through the profile path (the psd symlink), not the overlay or a
  `-backup` sibling; psd syncs it back and the path is valid whether psd runs or
  is stopped. The symlink is followed, never resolved.
- No profile resolves → the target logs `firefox: no profile` on stderr and
  skips as success (the run still exits zero); a template error still exits
  non-zero.
- Disabled → `chrome/shell-palette.css` becomes a `/* */` comment-only file (the
  import then yields stock Firefox) and `user.js` is not touched or created.
- The change applies on the next Firefox start.

## 3. Manual verification to run before closing ticket 04 docs

Headless tests cover the renderer and the file bytes; the visual result needs a
real Firefox start. Steps: run the renderer with the `firefox` target enabled,
confirm the profile's `chrome/shell-palette.css` and `user.js` exist, add the
one `@import` line to the profile's `userChrome.css`, restart Firefox, and
check the toolbar, a selected tab, the address bar, a panel (hamburger menu),
and the sidebar all follow the palette. Toggle Firefox off in Settings, restart
the renderer, restart Firefox, and confirm the chrome returns to stock.

# Ticket 05 -> ticket 04 handoff

Ticket 04 owns the user docs. The Spicetify findings below land in
`docs/user/theme-desktop-setup.md`.

## 1. User-facing behaviors the docs must state

- The renderer ships the community `text` theme into the shell-owned
  `${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/Themes/quickshell/` directory as
  two files: `color.ini` and `user.css`. The shell owns that directory; it never
  edits a theme the user installed (e.g. `Themes/text/`) or `config-xpui.ini`,
  and it never deletes unknown files there.
- `color.ini` keeps every color option the theme ships and appends one
  `[Quickshell]` option whose 13 keys follow the shell palette
  (`text`, `subtext`, `main`, `highlight`, `header`, `banner`, `accent`,
  `accent-active`, `accent-inactive`, `border-active`, `border-inactive`,
  `notification`, `notification-error`).
- **Bundling obligation the docs must record**: the repo maintains a vendored
  copy of the upstream `text/user.css` (MIT, copyright 2019 morpheusthewhite,
  pinned at commit `33a08ea009687f5a42ff678015c28797fe142a7c`). Upstream changes
  do not reach the user until the vendored template is updated; the hashes and
  commit live in a banner atop each template and the license in `NOTICE`.
- Disabled (the Spicetify toggle off): `color.ini`'s `[Quickshell]` section
  renders the theme's own `[Spicetify]` default values instead of the palette
  (read from the vendored template, so it cannot drift), and `user.css` is still
  written because it is the theme's layout, not a color layer.
- A real palette change runs `spicetify refresh` best-effort after writing, and
  only when a Spicetify file's bytes actually changed. The renderer never runs
  `spicetify apply` (version-gated here and force-restarts Spotify).
- When `${XDG_CONFIG_HOME:-$HOME/.config}/spicetify` does not exist, the target
  logs `spicetify: not installed` on stderr, writes nothing, and skips as
  success (the run still exits zero).
- The change applies on the next refresh; the theme and color option must be
  selected once (see below), and the shell's `refresh` then repaints the client.

## 2. Selection step and the version gate (needs live resolution)

The dated machine facts (2026-10-10, read-only; the real `spicetify` binary was
never run by this ticket):

- `spicetify-cli` 2.45.3-1 (`/usr/bin/spicetify`).
- Spotify 1.2.79.427.g80eb4a07.
- `~/.config/spicetify/config-xpui.ini` `[Backup]` holds
  `version = 1.2.79.427.g80eb4a07` and `with = 2.42.8` — the CLI (2.45.3)
  outpaces the backup (2.42.8), which is why `spicetify apply` is version-gated
  and must not be automated.
- Only `Themes/marketplace` is installed; there is no `text` and no other user
  theme, so the shell's `Themes/quickshell/` collides with nothing.

Criterion 6 (whether plain `spicetify refresh` picks up a theme/color-scheme
selection, or a version-gated `spicetify restore backup apply` is required) is
**not resolved live in ticket 05** — it needs the real binary against the live
Spotify session, which this ticket must not drive. Ticket 04 must not describe
the selection as "select once" until one of these is confirmed by hand:

- (a) Run the renderer with Spicetify enabled (the shell does this, or
  `scripts/render-theme.sh '<palette-json>' spicetify`), then
  `spicetify config current_theme quickshell color_scheme Quickshell` and
  `spicetify refresh`; if Spotify repaints without a restart, the one-time step
  is just that config write plus a refresh.
- (b) If (a) does not take effect, the user must run
  `spicetify restore backup apply`, which force-restarts Spotify and must be
  re-run after every Spotify update because the backup version gate moves.

Record which path worked, with the versions above, before writing the docs. If
(b) is reality, ticket 04 must state the exact command sequence and its
restart/update consequences, and the feature's documented cost is re-scoped
from "select once".

## 3. Manual verification to run before closing ticket 04 docs

Headless tests cover the renderer bytes, the `[Quickshell]` key set, the disabled
defaults, the refresh count, and the skip path. The visual result needs the live
client: run the renderer with Spicetify enabled against the real config root,
confirm `~/.config/spicetify/Themes/quickshell/{color.ini,user.css}` exist,
select the theme and `Quickshell` color option, refresh, and check a light and a
dark shell theme: unfocused borders, selected rows, and the disabled progress
track must read as distinct (the ticket's mapping collapses 13 keys onto a few
roles; move `border-inactive` or `highlight` if they do not).

