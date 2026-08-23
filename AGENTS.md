# AGENTS.md — Quickshell

A Quickshell-based Wayland status bar and desktop shell (QML) replacing waybar: a multi-monitor panel with workspaces, system tray, media/audio/CPU modules, notifications and power menu, styled as a unified slab. Migration from waybar is in progress per `docs/plans/quickshell-migration.html`.

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

## 3. Docs

- For researching a quickshell component, refer to https://quickshell.org/docs/v0.3.1/guide/
- For current context on the project, refer to `docs/plans/quickshell-migration.html`
