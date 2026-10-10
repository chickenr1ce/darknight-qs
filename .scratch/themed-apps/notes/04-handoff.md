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

