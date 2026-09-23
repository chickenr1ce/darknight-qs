# 01 — Remove dead Cpu module, record deviation, refresh baseline

Status: done

## Deviation entry (05 Cpu slot row)

Cpu slot steady state, picked 2026-09-23: Cava holds the bar slot; `modules/Cpu.qml` deleted, no flag. Restore from git history if a CPU readout earns daily use.

## Notes

- `scripts/lint-review.sh --update-baseline` never ran: the scoped-update guard fired even with no file paths because it tested the already-populated file list. Fixed the guard to test explicit paths only (one variable, same message). This fix was required to regenerate the baseline for this ticket.
- Baseline regenerated whole-file: 3 Cpu entries plus 1 stale CalendarCenter entry dropped (72 findings). Gate clean after.
Blocking: #02 #03 #04 #05 #06 #07
Blocked By: (none)
Source: docs/plans/06-architecture-review.html Part 1 F1 (High), F11 (Medium); docs/plans/05-post-migration-roadmap.html Cpu slot row.

## Objective

Delete the unused Cpu module, record the steady-state choice per the 05 carryover row, and regenerate the lint baseline so later tickets start from a clean gate.

## Acceptance criteria

- `modules/Cpu.qml` deleted; no import or call site references it (`grep -rn "Cpu" --include=*.qml` shows only unrelated matches or none).
- The 05 Cpu slot decision is logged as one deviation entry (README or docs/plans/05 note, one line: Cava holds the slot, Cpu removed).
- `scripts/lint.sh` passes; `scripts/lint-review.sh` passes (regenerate baseline if the deletion shifts findings, whole-baseline only).
- `scripts/test-calendar-fetch.sh` and `scripts/test-calendar-clock.sh` pass.
