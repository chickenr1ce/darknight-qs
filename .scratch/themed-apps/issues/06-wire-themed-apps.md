# Ticket 06: automate the one-time themed-app wiring

**Status:** done (2026-10-10)
**Blocked by:** tickets 01–05 (done)

## Objective

`docs/user/theme-desktop-setup.md` → "One-time wiring" lists manual steps per
app. Make them optional and automated: a standalone script that reports or
applies the wiring, run from `install.sh` behind a consent prompt. The renderer
(`scripts/render-theme.sh`) is unchanged and still never edits a user-owned
file; only this explicit, user-run command does.

## Part A — `scripts/wire-themed-apps.sh` (+ test)

Bash (`set -euo pipefail`), shellcheck-clean, follows
`docs/dev/CODING_STANDARDS.md`. Header comment in the style of
`scripts/seed-btop-theme.sh`.

### Interface (fixed; Part B depends on it)

```
wire-themed-apps.sh [--check|--apply] [target...]
```

- Targets: `hyprland kitty hyprlock btop firefox vencord spicetify`. No target
  arguments means all of them. An unknown target exits 2 with usage on stderr.
  (starship and yazi need no wiring; not targets.)
- `--check` (default) changes nothing on disk and runs no app command.
- `--apply` performs the wiring.
- Paths: `C=${XDG_CONFIG_HOME:-$HOME/.config}`.
- One stdout line per target, first word is the status:
  - `ok      <target>` already wired (both modes)
  - `todo    <target>: <what --apply would do, or what the user must do>` (check mode,
    or apply mode when blocked, e.g. app running)
  - `wired   <target>: <what changed>` (apply mode only)
  - `skip    <target>: <reason>` app/config absent or unsupported
  - `note    <target>: <hint>` optional extra line after the status line
- Exit 0 normally, including skip/todo. Exit 1 only on a real I/O/command
  failure (message on stderr), but still process the remaining targets first.

### Shared write rules

- Idempotent: a second `--apply` changes no bytes and makes no new backup.
- Before the first modification of a file, copy it to
  `<file>.bak-quickshell-<YYYYmmddHHMMSS>` next to the real file.
- A symlinked config (stow-style dotfiles) stays a symlink: resolve with
  `readlink -f` and atomically replace the *target* (temp file in the target's
  directory + `mv`), never the link.
- Process checks use `pgrep` (tests shim it through `PATH`).

### Per-target rules

1. **hyprland.** Needs `$C/hypr/hyprland.lua` (the entry file); otherwise
   `skip … no hyprland.lua (theme.lua needs the Lua config)`. Module names and
   layout are user-specific, so do **not** assume `modules/looks.lua`. Wired
   when any `*.lua` under `$C/hypr` (recursive, excluding `theme.lua`) has a
   non-comment line matching `require` of `"theme"`/`'theme'` (with or
   without parentheses, any whitespace). Otherwise append to the end of
   `hyprland.lua`:
   ```
   -- quickshell: rendered border colors; keep this the last line
   require("theme")
   ```
   The entry file's last statement runs after every module it requires, so the
   rendered borders win.
2. **kitty.** Needs `$C/kitty/kitty.conf`, else skip. Wired when a line matches
   `^\s*include\s+theme\.conf\s*$`. Otherwise: if `# BEGIN_KITTY_THEME` /
   `# END_KITTY_THEME` markers exist, replace everything between them with
   `include theme.conf` (keep markers); else append `include theme.conf` at the
   end.
3. **hyprlock.** Needs `$C/hypr/hyprlock.conf`, else skip. Wired when a line
   matches `^\s*source\s*=.*hyprlock/colors\.conf\s*$`. Otherwise prepend
   `source = <path>` as line 1, where `<path>` is
   `~/.config/hypr/hyprlock/colors.conf` when `C` is `$HOME/.config`, else the
   absolute `$C/hypr/hyprlock/colors.conf`. Always add a `note` that widget
   colors must reference `$theme_*` by hand (see the doc).
4. **btop.** Needs `$C/btop/btop.conf`, else `skip … no btop.conf (run btop once)`.
   Wanted value: `color_theme = "<abs $C>/btop/themes/theme.theme"` (absolute
   path, which is what btop's own menu stores). Wired when the existing
   `color_theme` line equals that. Otherwise, if `pgrep -x btop` matches, `todo
   … close btop first (it rewrites btop.conf on exit)`; else replace the
   `color_theme` line (append one if absent).
5. **firefox.** Resolve the default profile exactly like `firefox_profile()` in
   `scripts/render-theme.sh` (root `$C/mozilla/firefox`, falling back to
   `$HOME/.mozilla/firefox`; `installs.ini` `Default=`; `profiles.ini`
   `IsRelative`; profile dir must exist). Reuse rather than diverge: either
   call a small shared helper or mirror the logic faithfully (state which in
   the header). No profile → `skip … no profile`. Two sheets:
   `chrome/userChrome.css` ← `@import url("shell-palette.css");` and
   `chrome/userContent.css` ← `@import url("shell-content.css");`. A sheet is
   wired when its **line 1** is exactly the import. Otherwise remove any other
   exact occurrence of that import line, then prepend it (create `chrome/` and
   the file if absent). One status line for the target covering both sheets.
   Add a `note … restart Firefox` when anything changed. `user.js` is the
   renderer's job; do not touch it.
6. **vencord.** Needs `$C/Vencord/settings/settings.json`, else skip. Needs
   `jq`, else `skip … jq not installed`. Wired when `.enabledThemes` contains
   `"quickshell.theme.css"`. Otherwise, if `pgrep -x -i discord` (also
   `discordcanary`, `discordptb`) matches, `todo … close Discord first (it
   rewrites settings.json on exit)`; else append the name to `enabledThemes`
   (create the array if missing) with `jq --indent 4`, atomic replace. If no
   entry matching `system24` is enabled, add a `note` that the theme needs the
   system24 base theme. Add a `note … restart Discord` when changed.
7. **spicetify.** Needs `spicetify` on PATH and
   `$C/spicetify/config-xpui.ini`, else skip. Wired when the ini's `[Setting]`
   `current_theme` is `quickshell` and `color_scheme` is `Quickshell` (read the
   ini; whitespace around `=` varies). Otherwise if
   `$C/spicetify/Themes/quickshell/color.ini` is absent, `todo … start the shell
   once so it renders the theme`. Else run
   `spicetify config current_theme quickshell color_scheme Quickshell` then
   `spicetify restore backup apply`; `wired` line says Spotify restarted. A
   failing spicetify command → stderr + exit 1 at the end.

### Test: `scripts/test-wire-themed-apps.sh`

Offline, temp `HOME`/`XDG_CONFIG_HOME`, shims for `pgrep` and `spicetify` on
`PATH` (spicetify shim records its argv). Register it in `scripts/check.sh`
next to `seed-btop-theme`. Cover at least: each target's fresh wire; rerun is a
byte-identical no-op with no new backup; `--check` changes nothing and reports
`todo`; skip when absent; hyprland require already in a nested module → `ok`
and `hyprland.lua` untouched; hyprland with only `hyprland.conf` → skip; a
commented-out `-- require("theme")` does not count; kitty marker block
replaced; kitty without markers appended; Firefox import on line 3 moved to line
1 with no duplicate; vencord/btop refused while running; symlinked kitty.conf
stays a symlink and its target is edited; unknown target exits 2.

## Part B — `install.sh`, docs, ADR

1. `scripts/install.sh`: add `--wire-apps` / `--no-wire-apps` (default `ask`,
   same pattern as `LINK_MODE`). After seeding, print
   `install: themed app wiring` and the output of
   `wire-themed-apps.sh --check` (prefix each line like the other sections).
   If any line starts with `todo`: `yes` → run `--apply`; `ask` on a terminal →
   prompt `Wire these apps now? Backs up each edited file; Spicetify restarts
   Spotify. [y/N]`; `ask` without a terminal → note to rerun with
   `--wire-apps`; `no` → nothing. Update the header comment and `usage()`
   (it still never adds the Hyprland `exec-once` line), and replace the
   "optional app retint (add it yourself…)" block so it points at the script.
   A failing `--apply` is a `warn`, not an install failure.
2. `docs/user/theme-desktop-setup.md`: at the top of "One-time wiring" add an
   "Automatic" subsection (the script, `--check`/`--apply`, targets, backups,
   the install.sh flag, what stays manual: hyprlock widget colors, restarting
   Firefox/Discord). Keep the manual per-app sections as the reference; fix the
   Hyprland section to say `require("theme")` goes at the end of whatever file
   runs last (the entry `hyprland.lua` works for any layout), not specifically
   `modules/looks.lua`. Update the btop section: the script writes the absolute
   path, which matches the menu.
3. `docs/adr/0018-per-app-theme-targets.md`: dated 2026-10-10 amendment. The
   rejections of "inject the `@import`" and "enable the theme in
   `settings.json`" stand for the renderer; an explicit, user-run wiring
   command is a different trade-off (consent per run, backups, refuses while
   Discord/btop run, so nothing clobbers it). Match the existing amendment style.
4. `README.md`: if it documents install.sh flags, add the new one.
