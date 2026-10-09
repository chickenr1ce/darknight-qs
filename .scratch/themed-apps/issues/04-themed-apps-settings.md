# Ticket 04: Themed apps settings section and docs

**Status:** ready-for-agent
**Blocking:** none
**Blocked by:** ticket 01, ticket 02, ticket 03, ticket 05

## Objective

Give the user a per-app picker in Settings, and document the two new targets and
their one-time wiring. This is the capstone: it is the only ticket that edits
`docs/user/theme-desktop-setup.md` and the `CONTEXT.md` retint line, so the
target tickets never collide on prose.

## Acceptance criteria

1. New `windows/ThemedAppsSettingsView.qml`, following
   `windows/LayoutSettingsView.qml` as the shape: `pragma ComponentBehavior: Bound`,
   root at `ColumnLayout`, `property string filter`, and a `Repeater` over
   `ThemeService.themeTargets` whose delegate declares
   `required property var modelData`. Each delegate composes
   `components/SettingsToggleRow.qml` with `label: modelData.title`,
   `value: ThemeService.isThemeTargetEnabled(modelData.key)`,
   `visible: SettingsFilter.matches(root.filter, modelData.title)`, and
   `onToggled: ThemeService.setThemeTargetEnabled(modelData.key, !value)`. Import
   `QtQuick`, `QtQuick.Layouts`, and the `qs.components` / `qs.services` modules.
   Follow the id rules and attribute ordering in `docs/dev/CODING_STANDARDS.md`.

2. `services/SettingsService.qml` gains a `sectionRegistry` entry
   `{ key: "themed-apps", title: qsTr("Themed apps"), options: ThemeService.themeTargets.map(target => target.title), comingSoon: false }`.
   Do not re-spell the labels; they derive from `ThemeService.themeTargets`.

3. `windows/SettingsView.qml` composes the view where the other sections are
   gated, with `Layout.fillWidth: true`,
   `visible: root.hasSection && root.currentSection.key === "themed-apps"`, and
   `filter: root.bodyFilter`, per `docs/dev/settings-sections.md`.

4. Toggling a row flips the target's enabled state and triggers the render path,
   which rewrites that app's file (an unchanged target is skipped by
   `write_if_changed`).

5. `scripts/test-panel-logic.sh` section 10 asserts the `themed-apps` section
   key, that its `options` derive from `ThemeService.themeTargets`, and that the
   view composes `SettingsToggleRow` and filters through `SettingsFilter`. Add
   the new view to the `SettingsFilter` loop that currently enumerates the other
   section views.

6. `docs/user/theme-desktop-setup.md` is updated:
   - the intro moves from six files to nine targets (eleven files) and lists
     every destination: the six existing paths, the profile's
     `chrome/shell-palette.css` and `user.js`,
     `~/.config/Vencord/themes/quickshell.theme.css`, and
     `~/.config/spicetify/Themes/quickshell/{color.ini,user.css}`;
   - a Spicetify subsection: select the `quickshell` theme and its `Quickshell`
     color option once, note that the theme ships the community `text` theme's
     default options (MIT), that the client is refreshed with `spicetify refresh`
     (never `spicetify apply`, which is version-gated here and restarts Spotify),
     and that a Spotify update needs a re-apply;
   - a Vencord subsection under One-time wiring: enable the generated theme once,
     order it after `system24.theme.css`, restart Discord once, note the
     base-theme coupling and the hot reload;
   - a Firefox subsection: add `@import url("shell-palette.css");` as the first
     line of the profile's `userChrome.css`, note the generated `user.js` pref
     (and that the renderer will not overwrite a hand-written one), the psd write
     path, the `XDG_CONFIG_HOME`/`$HOME/.config` resolution, and that a restart
     applies it;
   - the "Running the renderer by hand" paragraph states the optional second
     argument and the per-target isolation exit semantics (a broken target is
     skipped, the rest still write, the script exits non-zero), and notes that
     the Firefox path follows `HOME` rather than `XDG_CONFIG_HOME`;
   - the "Verify" `grep` list gains the three new files, with the two Firefox
     paths expressed profile-relative (a glob or an explicit profile dir), since
     they are not fixed XDG paths.

7. `CONTEXT.md`'s desktop-retint line is corrected to "one file per target
   (Firefox contributes two)".

8. `scripts/check.sh` and `scripts/boot-check.sh` pass.

## Notes

The picker governs only apps the renderer already writes; do not add a row for an
app with no target. Keep the view's density and row shared with the other
sections rather than a bespoke layout.
