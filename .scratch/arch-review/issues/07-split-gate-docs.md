# 07 — First CalendarCenter split plus headless logic gate and docs (F10 partial, F12, F11)

Status: done

## Amendments

- 2026-09-23: Q1 answered as specified (settings view first). Q4
  answered by `scripts/test-panel-logic.sh`: structural assertions (the
  mesh, shadowing, matcher copies, inline height math, and style ternary
  cannot return without failing the gate) plus python oracles for the
  pure helpers with boundary values. Negative-tested by planting a panel
  write in a trigger and watching the gate fail.
- 2026-09-23: F11 closing check: branch-wide baseline diff reviewed.
  Removed 3 Cpu, 1 Tray, 1 NotificationServer, and 2 stale center
  triples; added 2 Cava, 1 HyprlandFocus, and 1 CalendarSettingsView
  triples, each documented in its ticket. No other adds.
- 2026-09-23: no new `docs/coding-conventions.md` section 4 traps beyond
  the lint-index bullet (nothing else new was verified at trap level).
  `scripts/smoke-toasts.sh` not run (daily shell holds the bus).
  `.scratch/arch-review/issues/` deletion waits for the merge commit per
  the lifecycle rule; the branch is local-only (no push requested).
Blocking: (none)
Blocked By: #01 #02 #05
Source: docs/plans/06-architecture-review.html Part 1 F10 (Medium), F12 (High), F11 (Medium); open questions Q1, Q4.

## Objective

Split one view out of the 675-line CalendarCenter behind the same PanelShell, add the missing headless regression net for panel logic, and close out the review docs.

## Acceptance criteria

- Q1 decision: the calendar-settings view (per-calendar Shown/Hidden list) splits first into `windows/CalendarSettingsView.qml` (or equivalent) behind the same PanelShell; CalendarCenter keeps month grid, agenda, and world clocks. File count grows, per-file line count falls, no behavior change.
- Q4: new `scripts/test-panel-logic.sh` gates pure panel logic without a compositor: PanelShell anchor clamp (`finalLeft = clamp(triggerCenter - panelWidth/2, ...)`), calendar `isStale` thresholds, monitor policy lookup, and HyprlandFocus queue order where reachable without Hyprland imports. The script documents why full QML boot needs a compositor and what it does instead.
- F11: baseline regenerated whole-file after all tickets; the closing check shows zero grandfathered adds on touched files.
- Docs: ADR 0001 amendment (registry), ADR 0002 amendment (cache tradeoff), lasting traps to `docs/coding-conventions.md` section 4 (one-offs to `docs/incidents/`), CONTEXT glossary only if a term changed. `.scratch/arch-review/issues/` deleted in the merge/squash commit per lifecycle rule.
- Full gates pass: `scripts/lint.sh`, `scripts/lint-review.sh`, `scripts/test-calendar-fetch.sh`, `scripts/test-calendar-clock.sh`, new `scripts/test-panel-logic.sh`, `scripts/smoke-toasts.sh` (or documented live-only skip).
