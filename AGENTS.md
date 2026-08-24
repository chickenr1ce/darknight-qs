# AGENTS.md — Quickshell

A Quickshell-based Wayland status bar and desktop shell (QML) replacing waybar: a multi-monitor panel with workspaces, system tray, media/audio/CPU modules, notifications and power menu, styled as a unified slab. Migration from waybar is in progress per `docs/plans/01-master-quickshell-migration.html`.

Workflow and repo conventions for AI agents and contributors working in `~/.config/quickshell`.

---

## 1. Coding Conventions (read first)

All QML style rules — `id` naming, component encapsulation & sizing, dynamic content
stability, layout best practices, attribute ordering — live in:

> **`docs/coding-conventions.md`** — read it before writing or reviewing any QML in this repo.

---

## 2. Git Worktrees

- Feature work happens in worktrees, **always created under the sibling
  `/home/alexiz/worktrees/` folder**, e.g.:
  ```
  git worktree add ../worktrees/quickshell-<topic>
  ```
- Never scatter worktrees inside the config directory itself.
- Remove a worktree when its branch is merged; delete stray untracked files first.

---

## 3. Agent Skills

QML/Quickshell agent skills live in `.agents/skills/`:
- `quickshell-patterns` / `qt-qml` — load when writing or editing any QML in this repo
- `qt-qml-review` — part of the standard verification pass (with qmllint) after QML changes
- `qt-qml-profiler` — performance/lag investigations
- `qt-qml-docs` / `qt-qml-test` / `qt-qml-test-run` / `qt-ui-design` — docs generation, test writing/running, UI design audits

---

## 4. Docs

- For researching a quickshell component, refer to https://quickshell.org/docs/v0.3.1/guide/
- For current context on the project, refer to `docs/plans/01-master-quickshell-migration.html`
