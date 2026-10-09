# Ticket 03: Firefox target

**Status:** ready-for-agent
**Blocking:** ticket 04
**Blocked by:** ticket 01, ticket 02

## Objective

Theme Firefox's browser chrome from the palette, through a generated sheet the
user's own `userChrome.css` imports, written safely into a psd-managed profile.

## Acceptance criteria

1. New templates `assets/templates/firefox-palette.css`, holding a `:root` block
   that maps every palette role to a `--shell-*` custom property, and
   `assets/templates/firefox-user.js`, holding
   `user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);`.

2. The renderer resolves the Firefox root as `${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox`
   when that directory exists, otherwise `$HOME/.mozilla/firefox`, reading the
   environment inside Python (`os.environ`), not the `config_home` the wrapper
   already passes. It discovers the default profile by reading `installs.ini`'s
   `Default=` in the `[<hash>]` or `[Install<hash>]` section. `Default` is the
   profile directory name; consult `profiles.ini` only to resolve `IsRelative`
   and an absolute `Path`. It matches the directory by exact name, never by a
   prefix or glob (the profile has `-backup`, `-back-ovfs`, and four
   `-crashrecovery-*` siblings), and it never resolves the profile's symlink, so
   a legitimate psd target under `/run` is not rejected.

3. When no profile resolves (no `installs.ini`, no match, or no directory), the
   target logs `firefox: no profile` to stderr, writes nothing, and counts as
   skipped, so the run exits zero. A template or render error still exits
   non-zero.

4. Under the target key `firefox`, it writes `<profile>/chrome/shell-palette.css`
   and `<profile>/user.js`, creating `chrome/` when absent. It never writes a
   `-backup` directory or `userContent.css`.

5. `user.js` is renderer-owned, but the renderer never destroys a hand-written
   one: if `user.js` exists and carries neither the legacy-sheets pref nor the
   generated marker, it writes nothing to that path and logs a warning naming the
   pref; otherwise it writes the generated file.

6. Disabled, `shell-palette.css` is a `/* */` comment-only file and `user.js` is
   left in place.

7. `scripts/test-panel-logic.sh` section 17 redirects `HOME` to a temp dir for
   every render invocation in the section (not only the new one), so the live
   profile is never written. The new Firefox case uses a fixture home holding a
   fake `mozilla/firefox/installs.ini`, a `profiles.ini` with both a `Default=1`
   stub and an `[Install]` default, and a profile directory. It asserts that
   `shell-palette.css` lands in the install-default profile with palette values
   and no unresolved token, that `user.js` carries the pref, and that the stub
   profile and every `-backup`/`-back-ovfs`/`-crashrecovery-*` path are untouched.

8. `scripts/check.sh` passes.

## Notes

Write through the profile path (the psd symlink), not the overlay or the backup;
psd syncs it back and the path is valid whether psd is running or stopped. The
change applies on the next Firefox start. The one-time `@import` line, the psd
note, and the `user.js` ownership warning land in ticket 04. The
`XDG_CONFIG_HOME`-versus-`$HOME/.config` resolution must be confirmed against the
installed Firefox before closing.
