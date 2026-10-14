# 04 — ADR 0019, CONTEXT.md, user page, plan status

**Status:** done
**Blocked by:** 01, 02, 03
**Blocking:** none

## Objective

Record the decisions and the vocabulary once the behaviour has shipped.

## Scope

- `docs/adr/0019-workspaces-dashboard-tab.md`. It records:
  - the decision for design 1a and the alternatives (1b, 1c, lanes 2a–2c, and
    round 1's rail, list, and matrix);
  - the card-size rule: the layout derives from the view width and the height
    scrolls past the cap;
  - the refresh strategy and its accepted staleness;
  - the exact confirmed `hl.dsp.*` calls for switch, silent move, floating, and
    fullscreen;
  - right click as the window menu and middle click as a graceful close;
  - that the scratchpad is excluded.
- `CONTEXT.md`:
  - rewrite the "Dashboard tabs" entry so Workspaces is no longer listed under
    "Coming soon";
  - add a "Workspace overview" entry naming `windows/DashboardWorkspacesView.qml`,
    `services/WorkspaceService.qml`, and `services/WorkspaceLogic.js`.
- `docs/user/workspaces-tab.md`: the mouse map (left, drag, right, middle) and
  the window menu.
- `docs/plans/README.md`: move plan 13 to 🟢 Implemented with "Option 1a shipped,
  ADR 0019".
- `docs/dev/roadmap.md`: remove or close any Workspaces-tab item.
- Durable docs describe this feature in words and never link to `.scratch/`.

## Acceptance criteria

- ADR 0019 exists and cites the confirmed Lua calls verbatim.
- `CONTEXT.md` no longer lists Workspaces as a placeholder.
- `scripts/check.sh` passes.
