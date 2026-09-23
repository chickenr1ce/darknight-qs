# 04 — One HyprlandFocus module owns focus-and-restore (c3, F2)

Status: ready-for-agent
Blocking: (none)
Blocked By: #01
Source: docs/plans/06-architecture-review.html Part 2 c3 (Strong), Part 1 F2 (High); modules/Tray.qml focusAppWindow, services/NotificationServer.qml focusApp.

## Objective

Replace the two verbatim copies of token match plus cursor save, focus, and restore with one module. The queue-or-coalesce decision both copies dodged (one stash, skip-restore patch) moves inside the module. Extraction covers dispatch and time, not just the pure matcher.

## Acceptance criteria

- New `services/HyprlandFocus.qml` singleton (registered in `services/qmldir`) exposes `focusByTokens(rawTokens): bool` with an internal request queue: concurrent clicks queue instead of skipping the cursor restore. Dispatch routes through an injectable function property so a harness can record calls instead of hitting Hyprland IPC.
- `modules/Tray.qml` (`focusAppWindow`) and `services/NotificationServer.qml` (`focusApp`) become thin wrappers that build their token lists and call `HyprlandFocus.focusByTokens`. No duplicated matcher, cursor, or restore code remains in either file.
- Token semantics preserved: lowercase trim, first `[^a-z0-9]+` segment as key, class plus initialClass match, title overlap (>= 3 chars) beats list order, `0x` prefix handling.
- Live check (when a compositor is present): tray click and toast action each focus and restore the cursor. Headless: lint passes; queue order covered by the #07 logic gate if reachable without Hyprland imports, else documented why not.
- `scripts/lint.sh` and `scripts/lint-review.sh` pass.

## Decision (Q2)

The shared helper lives in `services/` as a singleton. Both call sites already import `qs.services`, so neither gains a new import root and no cycle is introduced.
