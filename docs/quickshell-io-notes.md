# Quickshell Io notes

Behaviors of `Quickshell.Io` that the upstream docs leave implicit, proven
with a headless probe on 2026-09-16 (a windowless `ShellRoot` replaying the
zone poll wiring with timestamped logs of every poll start, finish, model
change, and file load).

## Process

- Changing `command` on a running process affects only the next start
  (upstream docs); the running process is never killed and keeps its
  original arguments.
- The process captures `command` when the run starts. A root-level
  `onChanged` handler runs before child bindings refresh, so a start
  issued there uses the previous arguments — observed as a poll argv
  missing the just-added zone. Defer with `Qt.callLater`; see the
  bindings rule in `docs/coding-conventions.md`.
- Guard every start with `if (!proc.running)` plus a queued flag that
  `onStreamFinished` re-checks. Never restart a run to pick up new
  arguments; queue instead.

## StdioCollector

- With `waitForEnd` (default true), every observed finish parsed the
  complete run output; `onStreamFinished` is where the result is applied
  and any queued rerun is started.

## FileView

- `setText`/`setData` are async and atomic by default (temp file plus
  rename); `saved`/`saveFailed` signal completion (upstream docs).
- `watchChanges` fires for your own writes too (observed 1ms after
  `setText`). The usual `onFileChanged: reload()` echo reassigns the
  parsed list — a new array identity even for equal content — which
  rebuilds array models and refires change handlers. A deferred
  (`Qt.callLater`) poll start coalesces the pair into one run.

## State files

- The persistence shape is three parts: a JSON or line-based file under
  the quickshell state dir, a `mkdir -p` `Process`, and a `FileView`.
  Copied, not shared, across `CalendarService` (zones), `CavaService`
  (cava tuning), and `BarVisibilityService` (module visibility). Extract
  it to one shared helper before a fourth copy appears.
- The echo guard needs a `ready` flag, not just an `applyingSettings`
  flag. A `property var` map's initializer fires `onChanged` at
  construction, before the async `FileView` load completes, so guarding
  the save on `applyingSettings` alone still writes defaults and wipes
  the file on every reload. Set `ready` in the first
  `onLoaded`/`onLoadFailed`; the `onChanged` handler refuses to save
  until then. Found live: a set-then-reload reverted to all-visible.

## Probe recipe

To settle a binding or ordering theory without touching the live shell,
run a config that creates no surfaces and claims no bus names:

```
quickshell -p <probe-dir> > /tmp/opencode/probe.log 2>&1 &
```

with a `shell.qml` holding only the `Timer`, `Process`,
`StdioCollector`, and `FileView` under test. Log starts (full argv),
finishes (parsed keys), model changes, and file loads with timestamps;
script the user action with a one-shot `Timer` and drive external edits
from the shell driver.
