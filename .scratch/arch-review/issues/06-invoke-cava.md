# 06 — Single invoke path plus single cava height formula (c6, c7)

Status: ready-for-agent
Blocking: (none)
Blocked By: #01
Source: docs/plans/06-architecture-review.html Part 2 c6, c7 (Worth exploring, taken: both are small, local, and low risk).

## Objective

Turn two duplicated comment-guarded patterns into owned functions: notification action ordering and cava bar height.

## Acceptance criteria

- `services/NotificationServer.qml` gains `invokeAction(notification, action)`: null-guard, then focus, then invoke. `components/NotificationToast.qml` and `components/NotificationCard.qml` each call it in one line; the duplicated ordering comments are gone from both pills.
- `modules/Cava.qml` feeds all six styles from one formula: the four bar delegates use the existing `barDrawHeight(i)` helper (no inline height math remains), and the style loader resolves through a `styleComponents` array indexed by `CavaService.styleMode` instead of a nested ternary. Mode constants stay in `CavaService` only; `windows/CavaCenter.qml` dropdown behavior unchanged.
- Lint gates pass; toast smoke gate passes (or is documented as needing the live bus, per repo rules it never runs beside the daily shell).

## Amendments

- 2026-09-23: c5 (StateFile/JsonStateFile module) and c8 (PressablePill) deferred, not dropped. c5 touches five FileViews across two services and needs a live FileView-echo harness to verify; the F4/F7 root fixes in #05 cover the daily-use pain first. c8 changes the visual press idiom in two delegates and needs pixel verification against a live instance. Both stay as future candidates; this ticket takes only the small local c6/c7 moves.
