# 07: Docs, ADR, and the Super bind cutover

**Status:** ready-for-human

**Blocked by:** 04, 05, 06

**Blocking:** none

**What to build:** Durable docs for the launcher, the decision record, and the
switch of Super from rofi to the shell. The bind lives in the user's Hyprland
config outside this repo, so the cutover is a human step.

## Acceptance criteria

- [x] `docs/adr/0018-app-launcher-dashboard-tab.md`: the launcher is a
  dashboard tab replacing Media, not a standalone window; why (one surface,
  existing junction and focus path, Media was empty); the trade-offs (no
  launcher beside the dashboard, Super must deep-link); variant 3 chosen with
  Focus/Kill inline, workspaces in Ctrl+N and the menu.
- [x] `CONTEXT.md` glossary entries: App launcher (Apps tab), Inline actions,
  Kill (graceful close of every window), Workspace slot (per-monitor N).
  Describe pending work in words, not `.scratch/` paths.
- [x] `docs/user/app-launcher.md` (keys, mouse, menu, pin/hide/unhide,
  terminal apps) linked from `docs/README.md` and `README.md`; the `apps`
  function added to `docs/user/ipc.md`.
- [x] `docs/dev/roadmap.md` and `docs/plans/README.md` updated
  (`09-app-launcher-designs.html` row moved to archived once shipped).
- [ ] Human: in `~/.config/hypr/modules/binds.lua`, the `SUPER_L` and
  `SUPER_R` binds call `quickshell ipc call dashboard apps` instead of the
  rofi launcher; the rofi script stays until a week of daily use passes.

## Amendments

- 2026-10-09: Repo-side criteria done; the human Super-bind box stays
  unchecked and `~/.config/hypr/modules/binds.lua` is untouched.
  `docs/adr/0018-app-launcher-dashboard-tab.md` follows ADR 0017's shape
  (Context, Decision, Alternatives considered, Consequences) and records the
  amended decisions from tickets 04 and 05: strict window matching (the
  Baldur's Gate 3 / Unity false positive), graceful Kill, close-before-focus,
  the Lua `hl.dsp.exec_cmd(cmd, { workspace = N })` dispatch with per-argument
  shell quoting, and the menu fitting inside the card without growing it.
  `docs/user/app-launcher.md` is written from the shipped code and linked from
  `docs/README.md` and `README.md`; `docs/user/ipc.md` now lists `apps` among
  the valid settings sections. `docs/plans/README.md` marks
  `09-app-launcher-designs.html` Implemented but keeps the row under Active:
  the artifact does not move to `archive/` until the branch merges, per that
  file's frozen-record convention.
- 2026-10-09: Review fixes. `AppService.hiddenEntries` now resolves against
  `root.entries` through the pure `AppLogic.resolveHidden` (one-line delegate,
  `DesktopEntries.byId` kept only as the NoDisplay fallback), so the binding
  depends on `DesktopEntries.applications.values` and the Settings → Apps
  section refreshes when an app is installed or removed while the shell runs;
  `scripts/test-app-launcher.sh` gains node checks for it.
  `docs/user/app-launcher.md`: inline buttons show on any selected or hovered
  app row, "up to three sections", and kitty must be installed. ADR 0018 cites
  design variants 1 and 5 for the detail pane only and lists category
  pills/filter chips as a separate rejected shape. `README.md` gains a kitty
  row in the optional-tools table.
