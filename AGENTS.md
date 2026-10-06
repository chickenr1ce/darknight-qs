# AGENTS.md — Quickshell

A Quickshell-based Wayland status bar and desktop shell (QML) replacing waybar: a
multi-monitor panel with workspaces, system tray, media/audio/CPU modules,
notifications and power menu, styled as a unified slab. Migrated from waybar;
the completed migration plan is archived at
`docs/plans/archive/01-master-quickshell-migration.html`. Workflow and repo
conventions for AI agents and contributors working in `~/.config/quickshell`;
the documentation map is `docs/README.md`.

## Always

- Worktrees: feature work happens under `$HOME/worktrees/`
  (`git worktree add $HOME/worktrees/quickshell-<topic>`); remove it once merged,
  deleting stray untracked files first.
- QML changes: load the `quickshell` and `qt-qml` skills first.
- Verify with `scripts/check.sh`; the gate and review rules live in
  `docs/dev/CODING_STANDARDS.md`.
- Live-test hand-off: after any change the shell loads (`.qml`, `qmldir`,
  settings), end the reply with a paste-ready `bash` block booting *this*
  worktree via `scripts/restart.sh --probe <worktree>`, without being asked.
  Mechanics (bus takeover, restore, log) are in
  `docs/dev/debugging-quickshell.md`.

## Read before you change

| Task | Doc |
| --- | --- |
| QML or `scripts/*.sh` change | `docs/dev/CODING_STANDARDS.md` (read first) |
| Live behavior, IPC probing, geometry, screenshots | `docs/dev/debugging-quickshell.md` |
| Quickshell Io polling / file cache | `docs/dev/quickshell-io-notes.md` |
| Adding a settings section | `docs/dev/settings-sections.md` |
| Feature tickets and ticket conventions | `docs/agents/issue-tracker.md` |
| Current context, roadmap, domain terms, why-decisions | `docs/dev/roadmap.md`, `docs/plans/README.md`, `CONTEXT.md`, `docs/adr/` (read the ADRs touching an area before changing it) |
| Research a Quickshell component | https://quickshell.org/docs/v0.3.1/guide/ |
| Qt 6 API details | `qt-docs` MCP (`qt_documentation_search` → `qt_documentation_read`), pass `version: "6.11"` (installed Qt 6.11.2; the server otherwise serves 6.12) |

## Agent skills

- `quickshell`, `qt-qml` — load for QML work.
- `qt-qml-profiler` — performance/lag investigations.
- `qt-qml-docs` / `qt-qml-test` / `qt-qml-test-run` / `qt-ui-design` — docs generation, test writing/running, UI design audits.
