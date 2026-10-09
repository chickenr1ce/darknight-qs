# Ticket 03: Firefox target

**Status:** ready-for-agent
**Blocking:** ticket 05
**Blocked by:** ticket 01, ticket 02

## Objective

Theme Firefox's browser chrome from the palette, through a generated sheet the
user's own `userChrome.css` imports, written safely into a psd-managed profile.

## Acceptance criteria

1. New template `assets/templates/firefox-palette.css`, holding a `:root` block
   of the palette as `--shell-*` custom properties **and** the rules that map
   those properties onto Firefox's own chrome variables. A bare
   `@import url("shell-palette.css");` must be enough to theme the chrome;
   generating only `--shell-*` variables themes nothing, because no Firefox rule
   reads them. The earlier draft named retired pre-Proton variables
   (`--toolbar-bgcolor`, `--tab-selected-bgcolor`, `--urlbar-box-bgcolor`,
   `--arrowpanel-*`); those do not exist in Firefox 157. Use the variables that
   do, verified against the installed Firefox 157.0.1:
   `--toolbar-background-color`, `--toolbar-text-color`,
   `--tab-background-color-selected`, `--tab-text-color-selected`,
   `--urlbar-box-background-color`, `--urlbar-box-background-color-focus`,
   `--urlbar-box-text-color`, `--toolbar-field-background-color`,
   `--toolbar-field-background-color-focus`, `--toolbar-field-text-color`,
   `--toolbar-field-text-color-focus`, `--panel-background-color`,
   `--panel-border-color`, `--sidebar-background-color`, `--sidebar-text-color`,
   `--sidebar-border-color`, `--lwt-accent-color`, `--lwt-text-color`. These are
   Firefox internals and have been renamed across releases; verify each resolves
   on the installed build before closing, and note in ticket 04 that upgrades may
   need template upkeep (do not promise stability).

2. New template `assets/templates/firefox-user.js`, holding the legacy-sheets
   pref inside a marker-delimited managed block:
   `// BEGIN quickshell` / `user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);` /
   `// END quickshell`.

3. The renderer resolves the Firefox root as
   `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox` when it exists, otherwise
   `$HOME/.mozilla/firefox`, reading the environment inside Python
   (`os.environ`), not the `config_home` the wrapper passes. It discovers the
   default profile from `installs.ini`'s `Default=` in the `[<hash>]` or
   `[Install<hash>]` section; with more than one section, take the first and note
   it. `Default` is the profile directory name; consult `profiles.ini` only to
   resolve `IsRelative` and an absolute `Path`. It matches the directory by exact
   name, never a prefix or glob (the profile has `-backup`, `-back-ovfs`, and
   four `-crashrecovery-*` siblings), and never resolves the profile's symlink, so
   a legitimate psd target under `/run` is not rejected. Snap and Flatpak Firefox
   roots are out of scope; document that.

4. When no profile resolves (no `installs.ini`, no match, or no directory), the
   target logs `firefox: no profile` to stderr, writes nothing, and counts as
   skipped-success, so the run exits zero. A template or render error still exits
   non-zero.

5. Under the target key `firefox`, it writes `<profile>/chrome/shell-palette.css`
   and `<profile>/user.js`, creating `chrome/` when absent. It never writes a
   `-backup` directory or `userContent.css`.

6. `user.js` is renderer-owned through its managed block, and the renderer never
   destroys a hand-written file: it replaces or inserts only the block in
   criterion 2 and preserves every other line, so a user's own prefs survive and
   an appended edit is not lost on the next render. When `user.js` is absent it
   creates it with the block alone. It never rewrites `prefs.js`.

7. Disabled, `shell-palette.css` is a `/* */` comment-only file (so the import
   yields stock Firefox). `user.js` is not touched, and is not created when it
   was absent.

8. `scripts/test-panel-logic.sh` section 17 redirects `HOME` to a temp dir for
   every render invocation that can resolve a `$HOME` path, so the live profile
   is never written. The new Firefox case uses a fixture home holding a fake
   `mozilla/firefox/installs.ini`, a `profiles.ini` with both a `Default=1` stub
   and an `[Install]` default, a profile directory, and a `-backup` sibling. It
   asserts that `shell-palette.css` lands in the install-default profile with
   palette values and no unresolved token; that `user.js` carries the managed
   block; that a pre-existing `user.js` with other prefs keeps them and gains the
   block; that the stub profile and every `-backup`/`-back-ovfs`/`-crashrecovery-*`
   path are untouched; that an `IsRelative=0` absolute `Path` resolves; that the
   profile symlink is followed, not resolved; and that a fixture with no
   `installs.ini` skips with exit 0 and a disabled case leaves `user.js` absent.

9. `scripts/check.sh` passes.

## Notes

Write through the profile path (the psd symlink), not the overlay or the backup;
psd syncs it back and the path is valid whether psd is running or stopped. The
change applies on the next Firefox start. The one-time step, documented in ticket
04, is to create the profile's `userChrome.css` with only the `@import` line as
its first line (an `@import` after other rules is ignored by CSS); the generated
sheet does the rest.
