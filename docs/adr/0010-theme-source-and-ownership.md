# ADR 0010: themes are omarchy v4 directories read as data, switched by the shell

Date: 2026-09-30. Feature: theme-switch.

## Context

The palette is hardcoded in `config/Colors.qml` and the roadmap planned a
matugen pipeline to derive it from the wallpaper. The user wanted to reuse
omarchy's theme ecosystem instead, since omarchy ships many curated themes.

Omarchy is not installed on this machine and its own shell is now Quickshell. Its
v4 (`quattro`) themes are directories holding a `colors.toml` of named color
roles, a `backgrounds/` directory, and app-specific extras. Its v3 (`dev`) themes
use a different, ANSI-based `colors.toml` schema. Its CLI applies a theme by
staging the directory and rendering app configs from templates.

Three shapes were possible: install omarchy and let its CLI own the switch; read
only the wallpaper and derive a palette; or read omarchy's theme files directly
while this shell owns the switch.

## Decision

This shell reads omarchy's v4 theme directories as data and owns the switch
itself.

- Only the `quattro` (v4) schema is supported. A v3 theme is rejected rather than
  approximated, because the fallback mapping would be guesswork.
- The theme root is quickshell-owned, `~/.local/share/quickshell/themes`. Omarchy
  paths are not read, so the two projects do not share a config directory.
- The shell owns selection and application. `ThemeService` holds the active theme
  and palette; a `qs-theme` CLI is a thin client over shell IPC. There is no
  external tool whose state the shell must follow.
- `services/ThemeService.qml` resolves the palette; `config/Colors.qml` maps it
  onto the existing tokens so no component changes.
- A renderer owned by this repo writes the desktop files it can do safely:
  Hyprland borders, kitty, and hyprlock. GTK, icon themes, rofi, and other apps
  are out of scope. rofi is dropped because a custom quickshell launcher is
  planned.
- There is no wallpaper-derived palette. The palette comes from `colors.toml`.

## Alternatives considered

- **Install omarchy and subscribe to its CLI.** Gives app retinting for free, but
  couples this shell to an omarchy install and makes the bar a guest in another
  project's pipeline. The user chose not to install omarchy.
- **Keep the matugen wallpaper pipeline as the producer.** Real, but matugen is
  not installed and its outputs are stale, and it makes the palette a function of
  the wallpaper rather than a chosen preset. Dropped from this feature.
- **Support both v3 and v4 schemas.** Broader catalog, but v3 has no named surface
  roles, so half the tokens would come from a guessed mapping. Rejected; revisit
  only if v3 themes prove wanted.
- **Read omarchy's `~/.config/omarchy/themes`.** Drops in with the ecosystem, but
  puts user content inside another app's config tree and mixes themes with
  omarchy's own state. Rejected for a quickshell-owned XDG data path.

## Consequences and known limits

- Themes must be installed into the quickshell root. `qs-theme install` does
  that; hand-cloning works too.
- Omarchy's `shell.toml` surface roles do not exist for us, because omarchy
  generates that file at apply time. Surfaces are derived in the mapping instead,
  and the derivation is lossy. The frozen table bounds it.
- Per-theme icon themes (`icons.theme`) are ignored, since icons are desktop-wide
  and belong with the deferred app theming.
- The switch cannot retint apps this feature does not cover. Adding a target means
  adding a template and a render case, not changing the model.

## Amendments

- 2026-10-03 (theme desktop targets): starship joins the retint targets. It has
  no include directive, so the renderer writes `~/.config/starship.toml` whole
  rather than a file the user's own config includes, and this repo owns the
  prompt. The format lives in `assets/templates/starship-theme.toml`. Kitty,
  hyprlock, and starship are terminal-shaped targets the palette already
  covers; GTK, icon themes, rofi, and the KDE widget bundle stay out of scope.
- 2026-10-03 (theme-switch follow-up): pre-semantic themes are supported. This
  decision rejected the ANSI schema "rather than approximated, because the
  fallback mapping would be guesswork." Omarchy publishes that mapping in
  `bin/omarchy-theme-color`, and its v4 shell reads these themes, so the loader
  ports the cascade instead of guessing: `color0`–`color15` map onto the semantic
  roles, the missing roles are derived or mixed, and mode falls back to the
  `light.mode` marker and the background's luminance. A canonical file still
  resolves to itself. No file is rewritten; resolution happens at read time, so a
  theme stays verbatim.
- 2026-10-03 (theme desktop targets): yazi joins the retint targets. Like
  starship it has no include directive, so the renderer writes
  `~/.config/yazi/theme.toml` whole and this repo owns the theme, replacing the
  static `[flavor]` reference a stock config carries. The format lives in
  `assets/templates/yazi-theme.toml`. A chip paints text on a colored ground, so
  the renderer emits an `on_<role>` black-or-white ink per hue; body text keeps
  a hue only when it contrasts with the app background and otherwise falls back
  to a `readable_<role>` background ink. The flavor's `.tmTheme` code
  highlighting is dropped with the flavor; the preview syntax theme falls back
  to the yazi preset.
- 2026-10-04 (bundled darknight theme): the repository ships one theme of its
  own under `assets/themes/darknight` — the palette that was the hardcoded
  `config/Colors.qml` fallback, plus two backgrounds. `scripts/install.sh`
  seeds it into the quickshell theme root and refreshes it on each run, so a
  fresh install has a catalog entry without a `qs-theme install`. The seed
  renews the theme's own files and adds a bundled background the installed theme
  lacks; it never overwrites an existing background, so a user's replacement or
  a higher-resolution original survives, and it skips a symlinked destination.
  `ThemeService`
  selects `darknight` once the catalog is ready when the state file holds no
  saved selection, so the bar and the desktop retint start on the theme rather
  than the no-theme default; a saved selection, including one whose theme left
  the catalog, is unchanged. The theme root and the read rules are untouched
  (ADR 0011): the seed writes the same root the shell already scans, and only
  `colors.toml` and `backgrounds/` are read.
- 2026-10-05 (theme desktop targets): btop joins the retint targets. btop
  selects from its themes directory rather than an include, so the renderer
  writes `~/.config/btop/themes/theme.theme` and the theme is picked once in
  btop's options menu; btop's own config rewrites do not touch the theme file.
  btop lists user themes by absolute path, so the menu does not match a bare
  `color_theme = "theme"` (it still loads, but the counter is off by one);
  picking it in the menu stores the path. `scripts/install.sh` seeds a default
  theme file when it is absent, so btop lists it before the shell has rendered.
  The format lives in `assets/templates/btop-theme.theme`, mapping box outlines
  and graph gradients onto the named hues and painting process-state text with
  the black-or-white `on_<role>` ink, matching the yazi chips.
- 2026-10-09 (per-app targets): Firefox and Vencord join the retint targets, and
  a target can now be switched off on its own. Firefox is themed at the chrome
  through a generated profile sheet the user's `userChrome.css` imports; Vencord
  is recolored by overriding its base theme's namespace. A disabled target writes
  a no-op layer rather than a missing file. This changes the model, not just the
  target list, so it is recorded in ADR 0018.
