# 05 — Calendar seam owns staleness plus poll fixes (c4, F3-F7, F8 decision)

Status: ready-for-agent
Blocking: #07
Blocked By: #01
Source: docs/plans/06-architecture-review.html Part 2 c4 (Strong); Part 1 F3 (High), F4/F5/F7 (Medium), F6 (Low), F8 (Medium); open questions Q3.

## Objective

Move "last good plus stale" fully behind the CalendarService seam and fix the small poll defects at the same time. The view keeps layout only.

## Acceptance criteria

- `services/CalendarService.qml` owns the clock: `now` property plus rollover tick, `isStale(nowMs, fetchedAtMs, failed)` pure helper, `eventsStale` binding, `staleLabel()` text, and internal `todayIso` updates. `monthCells` no longer depends on view-owned time.
- `windows/CalendarCenter.qml` binds `eventsStale` and `staleLabel()` from the service; its 1 s timer and its write to `CalendarService.todayIso` are gone. No other consumer needs the removed clock.
- F3: `setCalendarHidden` defers the repoll with `Qt.callLater` so the process command binding refreshes first (same pattern zones already use).
- F4: hidden and zone `FileView.onLoaded` handlers compare before assigning, so own `setText` writes cause zero extra polls.
- F5: cache reload keeps a raw-text dirty check; identical content does not rebuild the grid and agenda models.
- F6: the empty events `StdioCollector` is removed or streams helper stderr to the log; a failed fetch names its cause via exit code plus stderr.
- F7: state-dir creation is ordered before first read (reload state files when the mkdir process exits, or equivalent); cold start with no state dir loads defaults with nothing silent.
- F8 decision (Q3): the last-good cache stays under `XDG_CACHE_HOME`. Rationale recorded as an ADR 0002 amendment: cache cleaners can wipe it, the stale marker covers failed polls but not a wiped cache, and a state-dir move plus startup seed stays out of scope until users ask.
- Helper tests pass; lint gates pass.
