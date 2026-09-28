# Debugging the live shell

How to observe the running daily instance without disrupting it.

## Logs

- Text log: `tail -f /run/user/1000/quickshell/by-id/*/log.log`. Config
  reloads land here as `Configuration Loaded`, failures as
  `Failed to load configuration` with a `caused by` chain naming the file
  and line. The config auto-reloads on save, so watch this file after edits.
- Every instance logs here, including `quickshell -p` test shells: match
  the instance by its `Launching config:` line. Stale `by-id/` dirs pile
  up across launches, so when in doubt pick the dir whose `log.log` was
  written most recently. Redirecting stderr to a
  file as well keeps one grepable stream per test run.
- Binary log: the sibling `log.qslog` is not grepable directly; pipe it
  through strings first: `strings <log.qslog> | grep <pattern>`.
- `console.log` lines appear in the text log prefixed with `DEBUG qml:`.
  Tag temporary probes with a unique prefix (e.g. `[DEBUG-xxxx]`) so one
  grep finds them and cleanup is one deletion. Remove all probes before
  finishing.
- Every save auto-reloads, so a multi-file change with ordering dependencies
  (an import alias landing before its usage renames) fails live between saves
  and self-heals on the next one. Order edits so each prefix loads, keep the
  sequence tight, and confirm the final `Configuration Loaded` has no
  `Failed` after it.

## Geometry and layers

- `hyprctl layers` lists layer surfaces with namespace, pid, and `xywh`
  geometry; use it to confirm a window exists and sits where expected.
- `hyprctl cursorpos` reports the pointer in global layout coordinates,
  for checking whether a click lands inside or outside a panel.

## IPC probing

- A temporary `IpcHandler` (needs `import Quickshell.Io`) plus
  `quickshell ipc show` and `quickshell ipc call <target> <fn>` drives
  the live instance in an agent-runnable way: open/close a panel,
  read back state. Delete the handler before finishing.
- For exact widget geometry, register the item once with
  `DevGeometry.register("<area>.<name>", <id>)` (import `qs.dev`) and read it
  with `quickshell ipc --pid <pid> call devprobe geom <name>` — plain numbers
  (`x`, `y`, `width`, `height`, implicit sizes, `visible`), never QML objects.
  `devprobe geomNames` lists every registered target. Registrations are
  permanent one-liners in the component, so geometry reads never need a
  temporary handler. Open the surface through IPC first so layout has run.
  Handler args need concrete types (`QVariant` is rejected at registration)
  and untyped returns come back void. Every save reloads and closes popups,
  so batch probe edits together.
- A `PanelShell` opened through IPC needs an anchor screen before it maps:
  setting `visible` alone reads back as open in QML while `hyprctl layers`
  shows no surface. Set `anchorScreen` and `anchorCenterX` the way the bar
  trigger does.

## Dev probe

`dev/DevProbe.qml` is the opt-in IPC surface for live work; prefer it over a
one-off handler. Enable it with `QUICKSHELL_DEV_PROBE=1` at launch, or by
creating `$XDG_RUNTIME_DIR/quickshell-dev-probe` and reloading the shell (a
save does it). It registers target `devprobe`:

- `state` — JSON of every surface's visibility plus DND, reduced motion, world
  zones, and hidden feeds.
- `toggle <name>` — `dashboard`, `settings`, `calendar`, `cava`, `center`,
  `power` on the first screen.
- `closeAll`, `toggleDnd`, `setReducedMotion <bool>`, `addZone <id>`,
  `removeZone <id>`, `setFeedHidden <feed> <bool>`.
- `geom <name>` — the `DevGeometry` snapshot for one registered target;
  `geomNames` lists the registry. Prefer these over a one-off handler for
  any widget geometry question.

```
quickshell ipc --pid <pid> call devprobe toggle calendar
quickshell ipc --pid <pid> call devprobe state
```

It reaches service state and surfaces only. Widget geometry inside a
window comes from the `DevGeometry` registry (see `geom` above), never a
one-off handler.

## Reloads

- The shell watches file content, so `touch` never reloads. Run
  `scripts/reload.sh` instead: it appends a newline to `shell.qml`,
  waits for that generation, truncates the file back (preserving uncommitted
  edits), waits again, and fails if either generation logged an error
  signature. Never `git checkout -- shell.qml` to force a reload — the
  revert races the reload reader and fails intermittently on module
  resolution.

## Visual iteration loop

Taste questions converge only side by side: render variants as A/B captures
before asking, never sequential single passes. Drive the loop without the
pointer: open surfaces through `quickshell ipc --pid <pid> call`
(devprobe `toggle` plus `geom` for numbers), capture with `grim -g` to
`/tmp/opencode/`, and compare captures with pixel reads. Read the surface's
`at:` and `size:` from `hyprctl clients` immediately before `grim`; a
`FloatingWindow` can land on a different monitor across opens, so a remembered
position captures whatever sits underneath. Confirm a clean reload afterward
with `scripts/reload.sh`. No packaged Wayland input injector is installed:
`wtype`, `ydotool`, `dotool`, and `wlrctl` are absent, and `xdotool` is
X11-only. The probe is the reliable hands-free trigger. `/dev/uinput` is
writable by this user, so a small helper can inject a real pointer or key
event when one is needed. Every save closes popups, so batch probe edits
together and reopen through IPC after each reload.

## Second instance rule

Never run a second instance while the daily shell holds the bus: test
instances claim `org.freedesktop.Notifications` at startup, pass
vacuously, and spam the live screen. Stop/mask the current holder first.

## Live Hyprland config

The active config is the Lua tree at `~/.config/hypr/` (`hyprland.lua`
plus `modules/`, autostart in `modules/autostart.lua`).
`hyprland-old.conf` is retired legacy: grepping `*.conf` for exec or bind
entries looks authoritative while being wrong.

The settings window depends on a rule in `modules/windowrules.lua`:

```lua
hl.window_rule({
    name = "quickshell-settings",
    match = { class = "^org[.]quickshell$", title = "^Settings$" },
    float = true,
    center = true
})
```

That rule is the only thing making the settings toplevel float. It is not in
this repository, so a fresh checkout or another machine shows a tiled settings
window until someone adds it. `title` must equal the `settingsWindowTitle`
constant in `windows/SettingsCenter.qml`; that constant is deliberately not
translated because Hyprland matches the title literally.

## Lint entry points

- `scripts/lint.sh` runs the Qt6 qmllint over tracked QML files. Never
  use the bare `qmllint` on PATH; that binary is Qt5 and dies with a
  silent exit 255 on Quickshell imports.
- `scripts/lint-review.sh` runs the style linter and reports only
  findings not in the checked-in baseline
  (`scripts/lint-review-baseline.txt`). Regenerate the baseline with
  `scripts/lint-review.sh --update-baseline` after intentional style
  changes.
