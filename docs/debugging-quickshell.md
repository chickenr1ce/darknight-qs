# Debugging the live shell

How to observe the running daily instance without disrupting it.

## Logs

- Every instance logs under `$XDG_RUNTIME_DIR/quickshell/by-id/<id>/`, and
  stale dirs pile up across launches, so the newest dir is not always the
  one for your config. Resolve it with `scripts/instance.sh` (passive: it
  never boots an instance):
  - `scripts/instance.sh log [--config DIR]` prints the `log.log` for the
    config, newest even after the process exits.
  - `scripts/instance.sh dir [--config DIR]` prints that instance's by-id dir.
  - `scripts/instance.sh pid [--config DIR]` prints the pid for
    `quickshell ipc --pid <pid>`.
  - `scripts/instance.sh list` maps every by-id dir to its config and pid.
- Config reloads land in the log as `Configuration Loaded`, failures as
  `Failed to load configuration` with a `caused by` chain naming the file
  and line. The config auto-reloads on save, so watch this file after edits.
  A test shell booted with `quickshell -p` logs here too; redirecting its
  stderr to a file keeps one grepable stream per run.
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
one-off handler. Enable it with `QUICKSHELL_DEV_PROBE=1` at launch, or by writing
a non-empty file at `$XDG_RUNTIME_DIR/quickshell-dev-probe` and reloading the
shell (`scripts/reload.sh`). The file must be non-empty: `DevProbe.qml` tests
`text() !== ""`, so `touch` alone does not enable it. After a reload the
`devprobe` target takes a moment to register; an early call can answer
`Not ready to accept queries yet`. It registers target `devprobe`:

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
geometry from the devprobe `geom` snapshot immediately before `grim`; the
dashboard and its tabs are layer surfaces, so `hyprctl clients` does not list
them. Confirm a clean reload afterward
with `scripts/reload.sh`. No packaged Wayland input injector is installed:
`wtype`, `ydotool`, `dotool`, and `wlrctl` are absent, and `xdotool` is
X11-only. The probe is the reliable hands-free trigger. `/dev/uinput` is
writable by this user, so a small helper can inject a real pointer or key
event when one is needed. Every save closes popups, so batch probe edits
together and reopen through IPC after each reload.

## Focus changes

A focus dispatch moves the user's pointer and keyboard, and the user is often
working on the same machine. Their window switches during a test loop look
exactly like a flaky fix, so a focus experiment needs the user's cooperation.

Verify focus in this order:

1. Read-only: `quickshell ipc --pid <pid> call devprobe focusMatch <token>`
   resolves the target address and dispatches nothing. An empty or wrong
   address is the whole bug when a match fails.
2. One end-to-end dispatch. Announce it, run it once, and compare
   `hyprctl activewindow -j` before and after.
3. Ask the user to pause before a loop, and keep the loop short.

Closing a grabbed panel makes the compositor restore the previously focused
window, which overrides a focus request that follows too soon. `HyprlandFocus`
waits for `PanelGrab.closing` before dispatching, so a request issued by a
panel's own click lands after the restore.

## Second instance rule

Never run a second instance while the daily shell holds the bus: test
instances claim `org.freedesktop.Notifications` at startup, pass
vacuously, and spam the live screen. Stop/mask the current holder first.

## Live Hyprland config

The active config is the Lua tree at `~/.config/hypr/` (`hyprland.lua`
plus `modules/`, autostart in `modules/autostart.lua`).
`hyprland-old.conf` is retired legacy: grepping `*.conf` for exec or bind
entries looks authoritative while being wrong.

Settings is a dashboard tab, not a toplevel (ADR 0012), so it needs no
`windowrules.lua` entry. An old `quickshell-settings` rule is harmless but
dead.

### Toplevel class

`HyprlandToplevel` has no `class` property. Class matching reads
`lastIpcObject`, which is empty on this machine under Hyprland's Lua IPC, so a
matcher keyed on it never matches anything. Read `toplevel.wayland.appId`
instead. `quickshell ipc --pid <pid> call devprobe toplevels` dumps the
address, title, appId, and IPC object for every toplevel.

## Lint entry points

- `scripts/lint.sh` runs the Qt6 qmllint over tracked QML files. Never
  use the bare `qmllint` on PATH; that binary is Qt5 and dies with a
  silent exit 255 on Quickshell imports.
- `scripts/lint-review.sh` runs the style linter and reports only
  findings not in the checked-in baseline
  (`scripts/lint-review-baseline.txt`). Regenerate the baseline with
  `scripts/lint-review.sh --update-baseline` after intentional style
  changes.
