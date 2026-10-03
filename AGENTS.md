# AGENTS.md — Quickshell

A Quickshell-based Wayland status bar and desktop shell (QML) replacing waybar: a multi-monitor panel with workspaces, system tray, media/audio/CPU modules, notifications and power menu, styled as a unified slab. Migrated from waybar; the completed migration plan is archived at `docs/plans/archive/01-master-quickshell-migration.html`.

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
  git worktree add /home/alexiz/worktrees/quickshell-<topic>
  ```
- Never scatter worktrees inside the config directory itself.
- Remove a worktree when its branch is merged; delete stray untracked files first.

---

## 3. Agent Skills

The QML and Quickshell skills (`quickshell`, `qt-qml`, and the rest) are installed in the global skills directory; the repo does not vendor them. Load `quickshell` and `qt-qml` when writing or editing any QML in this repo.
- Verification is `scripts/check.sh`: type lint (`scripts/lint.sh`), style lint (`scripts/lint-review.sh`), the headless `scripts/test-*.sh` gates, and `scripts/check-live-log.sh` (skips when no instance is running). The style linter is vendored at `scripts/qt_qml_lint.py` (BSD-3-Clause, The Qt Company); `qt-qml-review` remains available as an optional deeper pass. `scripts/smoke-toasts.sh` is a separate deliberate run because it boots its own instance.
- Review fanout: default to one spec pass plus one QML pass over the final diff, each starting from `git diff` and the ticket rather than re-reading the codebase. Add a round only when a review reports a High finding.
- `qt-qml-profiler` — performance/lag investigations
- `qt-qml-docs` / `qt-qml-test` / `qt-qml-test-run` / `qt-ui-design` — docs generation, test writing/running, UI design audits

---

## 4. Docs

- For researching a quickshell component, refer to https://quickshell.org/docs/v0.3.1/guide/
- For Qt 6 API details (signals, slots, properties, defaults, since-version), verify with the `qt-docs` MCP tools (`qt_documentation_search`, then `qt_documentation_read`) instead of recalling from training; the server carries the 6.11 docs, which match the installed Qt 6.11.2.
- For current context on the project, refer to `docs/roadmap.md`, `CONTEXT.md`, and `docs/plans/README.md`
- Domain glossary for dashboard, junction, panels registry, and the rest: `CONTEXT.md`
- Decision records for why a design is the way it is: `docs/adr/`. Read the ADRs that touch an area before changing it.
- Verify QML behavior against a live instance; the standalone `qml` runtime's logging is broken in this environment. When the daily shell already runs this worktree, use it and drive it with `quickshell ipc --pid <pid>` — never boot a second instance. `scripts/smoke-toasts.sh` is the regression gate for the notification toast layer.
- Live debugging (instance pid and log, geometry, IPC probing, the opt-in `dev/DevProbe.qml` surface): `docs/debugging-quickshell.md`; `scripts/instance.sh pid` resolves the running instance, `log`/`dir` the newest log/dir for the config.
- **Live-test hand-off**: after any change the shell loads (`.qml`, `qmldir`, settings), end the reply with a fenced `bash` block giving the exact command to boot *this* worktree — absolute path, ready to paste, without being asked. Use `scripts/restart.sh --probe <worktree>`; it stops the running shell (daily instance included) and starts `quickshell -p <worktree>` detached. Say in one line that this takes `org.freedesktop.Notifications` from the daily shell, that `scripts/restart.sh` with no `--probe` brings the daily one back, and that `scripts/instance.sh log` tails the new boot's errors.
- Io polling and file-cache behavior that upstream docs leave implicit (stale-command trap, FileView echo, probe recipe): `docs/quickshell-io-notes.md`.
- Adding a settings section (state seam, view filter, search registration): `docs/settings-sections.md`.
- Test instances claim `org.freedesktop.Notifications` at startup: stop/mask the current holder first, and never run a second instance while the daily shell holds the bus (it passes vacuously and spams the live screen).
- Launch persistent daemons with `setsid` so they outlive the invoking shell; capture regions with `grim -g "x,y WxH"` instead of full-screen grabs.
- Screenshots pasted into chat are not measurable: never call alignment from them. A visual verdict needs the capture saved to disk (`grim` to `/tmp`) plus a pixel or geometry reading; see `docs/debugging-quickshell.md`.

---

## 5. Issue Tracking & Scratch Tickets

- Active feature implementation tickets live in `.scratch/<feature>/issues/` (e.g. `.scratch/notifications/issues/`).
- Tickets are tracer bullets declaring explicit blocking relationships (`Blocking` / `Blocked By`) and acceptance criteria.
- When implementing a feature in a worktree, check `.scratch/<feature>/issues/` for pending tickets and work them blockers-first.
- `.scratch/<feature>/issues/` is the configured issue tracker and `Status: ready-for-agent` is the triage label. The engineering skills read this through `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`, with no setup step.

### 5.1 Ticket conventions

These exist so history rewrites (squashes are routine here) never strand a reference:

- **Reference direction**: commit messages cite their ticket (`#NN`, e.g. `feat(notifications): toasts (#02)`); tickets describe commits in words only ("the ticket-02 feature commit"), resolvable via `git log --grep "#NN"`. Raw SHAs go stale under squash; ticket numbers don't.
- **Stable anchors are tags**: any long-lived commit anchor (review fixed point, milestone) gets a lightweight git tag at creation time (e.g. `git tag review-base/<feature> <sha>`); documents and review invocations cite the tag.
- **Updates**: flip `Status` and dependency headers freely. Scope changes append an `## Amendments` section (each entry dated) instead of editing the objective or acceptance criteria in place — the ticket file is what code-review's Spec axis judges against. A follow-up change to a done ticket gets a dated amendment under the original; do not reopen it for a UI tweak. Work discovered mid-ticket becomes a new ticket noting its origin ("Discovered during #NN").
- **Ownership**: a feature's tickets are edited only from that feature's worktree branch; cross-cutting docs change on the branch that owns them.
- **Lifecycle**: `.scratch/<feature>/issues/` lives only as long as the feature. When all tickets are done, review is complete, and the branch merges: promote lasting lessons to `docs/` (coding conventions, spec, retro output), then delete the folder in the same merge/squash commit. Git history is the archive — deletion loses nothing. Session handoffs (`~/.config/opencode/handoff-*.md`) die the same way: delete once the feature merges and its cutover verifies.

