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
- Verify QML behavior against a live instance (`quickshell -p <dir>`); the standalone `qml` runtime's logging is broken in this environment. `scripts/smoke-toasts.sh` is the regression gate for the notification toast layer.
- Test instances claim `org.freedesktop.Notifications` at startup: stop/mask the current holder first, and never run a second instance while the daily shell holds the bus (it passes vacuously and spams the live screen).
- Launch persistent daemons with `setsid` so they outlive the invoking shell; capture regions with `grim -g "x,y WxH"` instead of full-screen grabs.

---

## 5. Issue Tracking & Scratch Tickets

- Active feature implementation tickets live in `.scratch/<feature>/issues/` (e.g. `.scratch/notifications/issues/`).
- Tickets are tracer bullets declaring explicit blocking relationships (`Blocking` / `Blocked By`) and acceptance criteria.
- When implementing a feature in a worktree, check `.scratch/<feature>/issues/` for pending tickets and work them blockers-first.

### 5.1 Ticket conventions

These exist so history rewrites (squashes are routine here) never strand a reference:

- **Reference direction**: commit messages cite their ticket (`#NN`, e.g. `feat(notifications): toasts (#02)`); tickets describe commits in words only ("the ticket-02 feature commit"), resolvable via `git log --grep "#NN"`. Raw SHAs go stale under squash; ticket numbers don't.
- **Stable anchors are tags**: any long-lived commit anchor (review fixed point, milestone) gets a lightweight git tag at creation time (e.g. `git tag review-base/<feature> <sha>`); documents and review invocations cite the tag.
- **Updates**: flip `Status` and dependency headers freely. Scope changes append an `## Amendments` section (each entry dated) instead of editing the objective or acceptance criteria in place — the ticket file is what code-review's Spec axis judges against. Work discovered mid-ticket becomes a new ticket noting its origin ("Discovered during #NN").
- **Ownership**: a feature's tickets are edited only from that feature's worktree branch; cross-cutting docs change on the branch that owns them.
- **Lifecycle**: `.scratch/<feature>/issues/` lives only as long as the feature. When all tickets are done, review is complete, and the branch merges: promote lasting lessons to `docs/` (coding conventions, spec, retro output), then delete the folder in the same merge/squash commit. Git history is the archive — deletion loses nothing. Session handoffs (`~/.config/opencode/handoff-*.md`) die the same way: delete once the feature merges and its cutover verifies.

