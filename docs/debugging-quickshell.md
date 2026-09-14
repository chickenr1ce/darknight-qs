# Debugging the live shell

How to observe the running daily instance without disrupting it.

## Logs

- Text log: `tail -f /run/user/1000/quickshell/by-id/*/log.log`. Config
  reloads land here as `Configuration Loaded`, failures as
  `Failed to load configuration` with a `caused by` chain naming the file
  and line. The config auto-reloads on save, so watch this file after edits.
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
- For exact widget geometry, expose a plain-numbers object from the component
  (positions and sizes only, never QML objects), return it as
  `JSON.stringify(...)` from a `: string` handler, and read it with
  `quickshell ipc call <target> <fn> <i>`. Handler args need concrete types
  (`QVariant` is rejected at registration) and untyped returns come back
  void. Open the surface through IPC first so layout has run, and remove the
  probe in one pass afterward. Every save reloads and closes popups, so batch
  probe edits together.

## Second instance rule

Never run a second instance while the daily shell holds the bus: test
instances claim `org.freedesktop.Notifications` at startup, pass
vacuously, and spam the live screen. Stop/mask the current holder first.

## Live Hyprland config

The active config is the Lua tree at `~/.config/hypr/` (`hyprland.lua`
plus `modules/`, autostart in `modules/autostart.lua`).
`hyprland-old.conf` is retired legacy: grepping `*.conf` for exec or bind
entries looks authoritative while being wrong.

## Lint entry points

- `scripts/lint.sh` runs the Qt6 qmllint over tracked QML files. Never
  use the bare `qmllint` on PATH; that binary is Qt5 and dies with a
  silent exit 255 on Quickshell imports.
- `scripts/lint-review.sh` runs the style linter and reports only
  findings not in the checked-in baseline
  (`scripts/lint-review-baseline.txt`). Regenerate the baseline with
  `scripts/lint-review.sh --update-baseline` after intentional style
  changes.
