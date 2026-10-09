# 05: Open on workspace (Ctrl+N and the menu)

**Status:** done

**Blocked by:** 03

**Blocking:** 07

**What to build:** Launch an app onto a chosen workspace of the monitor the
dashboard is on, from Ctrl+1…N or the "Open on workspace ▸" submenu. There is
no inline button for it.

## Acceptance criteria

- [x] `AppLogic.workspaceFor(n, firstWorkspace, perMonitor)` returns the
  absolute workspace number for the Nth slot, or `-1` when `n` is out of
  `1..perMonitor`. `AppService` feeds it
  `MonitorService.firstWorkspaceFor(monitorName)` and
  `MonitorService.workspacesPerMonitor` for the dashboard's anchor screen.
- [x] The dispatch is a Hyprland Lua call that starts the command on that
  workspace without switching to it first if Hyprland allows, verified
  against the installed Hyprland (`hyprctl eval` or the Lua API docs) before
  writing it. Record the call that works and anything rejected in this
  ticket's amendments. Terminal entries keep the terminal prefix.
- [x] Ctrl+1…9 opens the selected entry on that slot when it is within
  `workspacesPerMonitor`; out-of-range keys do nothing.
- [x] Submenu lists one item per slot (`Workspace N`), marks the current
  workspace and occupied ones, shows `ctrl N` hints, and ends with "New empty
  workspace" (the first empty workspace in this monitor's block, hidden when
  the block is full).
- [x] `scripts/test-app-launcher.sh`: node tests of `workspaceFor` for the
  primary (starts at 1) and a second monitor (starts at `perMonitor + 1`),
  plus out-of-range.
- [ ] Live: Ctrl+3 from the dashboard on each monitor opens the app on that
  monitor's third workspace.

## Amendments

- 2026-10-09 — Dispatch research (installed Hyprland 0.56.2, Lua config/IPC).
  The working call is
  `hl.dsp.exec_cmd("<command>", { workspace = <absolute> })`, dispatched as
  `Hyprland.dispatch(\`hl.dsp.exec_cmd("…", { workspace = N })\`)`.
  `HyprlandIpc::dispatch` sends `dispatch <payload>` over the compositor
  socket, and Hyprland evaluates that as `hl.dispatch(<payload>)`
  (verified: `hyprctl dispatch 'hl.dsp.exec_cmd("touch /tmp/…", { workspace = 996 })'`
  created the marker). Evidence for the options table: the installed API stub
  `/usr/share/hypr/stubs/hl.meta.lua` documents
  `hl.exec_cmd(cmd: string, rules?: table<string, string|number|boolean>)`,
  and the user's `~/.config/hypr/modules/autostart.lua` launches with
  `hl.exec_cmd("spotify", { workspace = "7" })`. The dispatcher form accepts
  the same rules table: `hl.dispatch(hl.dsp.exec_cmd("true", { workspace = "999" }))`
  and `{ workspace = 998 }` both returned `ok` and executed the command; a
  plain `hl.dsp.exec_cmd("true")` also executed. `workspace` is a Hyprland
  window rule (see the `WINDOW_RULE_EFFECT_DESCS` list in
  `/usr/include/hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp`), so
  the window opens on that workspace without a focus switch — the same
  mechanism the user's autostart relies on. Rejected: `{ workspace = …, silent = true }`
  fails with `buildRuleFromTable: unknown effect 'silent'` (there is no
  `silent` rule in the Lua set), so no silent option is passed. No
  move-window fallback was needed; it was probed harmlessly anyway:
  `hl.dsp.window.move` exists and its selector is a table
  (`{ window = "address:0x…", workspace = N }`); the string-selector form
  `hl.dsp.window.move("address:0x…", {…})` is rejected with
  `expected a table, e.g. { direction = "left" }`. No GUI app was launched, no
  workspace was switched, and no window was moved during the research.
- 2026-10-09 — `AppLogic` gains `workspaceFor(n, firstWorkspace, perMonitor)`
  (slot → absolute, `-1` out of range), `firstEmptyWorkspace(firstWorkspace,
  perMonitor, occupiedIds)` (first free slot in the block, `-1` when full), and
  `workspaceMenu(firstWorkspace, perMonitor, activeWorkspace, occupiedIds)`
  (the submenu descriptors). `AppService` gains `workspaceFor(n)`,
  `workspaceMenuItems()`, and `launchOnWorkspace(entry, workspace, keepOpen)`;
  `menuItems(entry, pinned, isRun, runningCount)` now passes
  `workspaceMenuItems()` as the submenu for a new `open-workspace` item.
  `launchOnWorkspace` keeps the `kitty -e` prefix for terminal entries, joins
  the entry command (field codes are already stripped by
  `DesktopEntry.parseExecString`), escapes it with `MonitorLogic.escapeLua`,
  records the launch, and closes the dashboard unless `keepOpen`.
- 2026-10-09 — `windows/DashboardAppsView.qml` adds the Ctrl+1…9 branch in
  `handleKey` (Ctrl+0 is consumed too, so no digit reaches search; only slots
  `1..workspacesPerMonitor` act), maps the submenu glyphs
  (`Icons.workspace` on the parent, `Icons.circle` for current,
  `Icons.circleOutline` for occupied, `Icons.plus` for "New empty workspace"),
  and runs `AppService.launchOnWorkspace` from `runMenuItem`. New glyphs
  `workspace` (md-view_dashboard U+F056E), `circle` (md-circle U+F0765), and
  `circleOutline` (md-circle_outline U+F0766) were verified in the installed
  GeistMono Nerd Font. The item order follows ticket 04's pinned test: with
  workspace items present the order is Open, Open on workspace, Focus window,
  Open and keep dashboard, … — ticket 04's "Focus window right after Open"
  holds on the no-submenu call it asserts.
- 2026-10-09 — `scripts/test-app-launcher.sh` gains node tests for
  `workspaceFor` (primary starts at 1, second monitor at `perMonitor + 1`,
  out-of-range, zero count, bad first), `firstEmptyWorkspace` (first free,
  gap, second monitor, full, out-of-block ids ignored), and `workspaceMenu`
  (slot labels, `(current)`, `ctrl N` hints capped at 9, occupied flags, the
  hidden new-workspace item when full), plus structural greps for the Ctrl+digit
  branch, the `MonitorService` inputs, and the `hl.dsp.exec_cmd(…, { workspace = N })`
  dispatch. `scripts/lint-review.sh` stays clean vs baseline; the baseline is
  unchanged.
- 2026-10-09 — The Live bullet stays unchecked: it needs a real Hyprland
  session and a throwaway GUI app, which this change deliberately did not
  launch. `scripts/boot-check.sh <worktree>` reports `loaded` and
  `scripts/check.sh` passes.
- 2026-10-09 — Review fixes. (1) `AppLogic.shellQuote` (POSIX single-quote,
  embedded `'` → `'\''`, empty → `''`) and `AppLogic.shellCommand`
  (argv.map(shellQuote).join(" ")); `AppService.launchOnWorkspace` now passes
  `shellCommand(parts)` through `MonitorLogic.escapeLua`, so Hyprland's
  `/bin/sh -c` sees one quoted argument per argv element instead of a raw
  space-join — spaces, `$(...)`, backticks, `;`, `&`, `<`, `>` in a
  filename can no longer split or execute. (2) `MonitorLogic.escapeLua` also
  escapes `\n`, `\r`, and `\0` (Lua string escapes), so a command carrying a
  newline no longer aborts the dispatch with "unfinished string";
  `MonitorService.setEnabledSpec` is unaffected and its tests still pass.
  (3) `AppLogic.menuItems` order now follows the spec: Open, Open on
  workspace ▸ (when present), Open, keep dashboard, Focus window (N open),
  then actions, pin, hide, copy, Kill last; ticket 04 has the matching
  amendment. (4) `scripts/test-app-launcher.sh` adds node tests for
  `shellQuote`/`shellCommand` (plain, space, embedded quote, `$()`, backticks,
  `;`, `&`, `<>`, empty, newline) and a composed
  `shellCommand → escapeLua` string, a newline/CR `escapeLua` check, a
  structural grep that `launchOnWorkspace` builds via `shellCommand`, and
  full menu-order assertions with and without workspace items. End-to-end on
  this machine: the pre-fix raw join injected `/tmp/qs-inj` under
  `hl.dsp.exec_cmd(…, { workspace = 996 })`, while the fixed
  `shellCommand` created exactly `/tmp/qs probe & ; | < > \`date\` 'quote'`
  with no injection; the probe files were removed.
