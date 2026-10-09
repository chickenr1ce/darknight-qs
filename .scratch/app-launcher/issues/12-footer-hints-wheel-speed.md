# 12: Footer key hints and faster wheel

**Status:** done

**Blocked by:** 11

**Blocking:** none

Discovered during the third live run (user feedback, 2026-10-09): the
prototype's footer bar of key hints is missing from the shell, and scrolling
with the mouse wheel is too slow.

## Footer

The prototype (`docs/plans/09-app-launcher-designs.html`, variant 3,
`.foot`) ends the Apps tab with a footer row:
`↵ Open · ctrl 1–N On workspace · ⇧F10 More`, a spacer, then a faint
"hover a row for actions" hint on the right.

- Compose the existing `components/KeyHint.qml` (no new primitive). `N` is
  `MonitorService.workspacesPerMonitor`, capped at 9 because only Ctrl+1…9
  exist.
- The footer sits under the list, above the card's bottom padding, and
  separated from the list by a hairline (`Colors.border`,
  `Globals.hairlineHeight`), as in the prototype. Its height is fixed and
  reserved, so the list slot shrinks to make room and nothing reflows.
- The right-hand hint uses `Colors.textFaint` and `Globals.uiCaptionSize`. It
  elides when space runs short.
- Strings use `qsTr`. Glyphs come from `config/Icons.qml` if a return-key
  glyph exists there; otherwise use the plain "↵" text in the key cap, which
  is what `KeyHint` takes.
- `docs/user/app-launcher.md` mentions the footer.

## Wheel speed

- `Globals.wheelStep` goes from 144 to 240, about four rows.
- The angleDelta path scales the step by `|angleDelta.y| / 120`. A
  high-resolution wheel that reports 15- or 30-unit chunks then moves
  proportionally instead of a full step per chunk, and a 240 delta (two
  notches coalesced) moves two steps. Rapid notches still accumulate into one
  target. Put this in `SmoothWheelLogic.wheelStep` (pure) and cover it with
  node tests: 120, 240, 15, −120, and clamping.
- Trackpad `pixelDelta` stays 1:1.

## Acceptance criteria

- [x] Footer with three `KeyHint`s and the right-hand hint, Ctrl range from
  `workspacesPerMonitor`, fixed height, hairline above it.
- [x] `scripts/test-app-launcher.sh` asserts the footer composes `KeyHint`
  three times and binds the workspace count.
- [x] `wheelStep` is 240; the step scales with the delta, with node tests.
- [x] `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  loaded.
- [ ] Live: the footer matches the prototype under haven, ash, and darknight;
  one notch moves about four rows.

## Amendments

- 2026-10-09 — Implemented in `windows/DashboardAppsView.qml` as a
  `ColumnLayout` (`idAppsFooter`) closing `idAppsLayout`: a `Globals.hairlineHeight`
  / `Colors.border` rule, a `Globals.appsFooterGap` gap, then a row of three
  `KeyHint`s (`↵` Open, `ctrl 1–%1` On workspace with the count from
  `Math.min(9, MonitorService.workspacesPerMonitor)`, `⇧F10` More) and a
  right-aligned `Colors.textFaint` / `Globals.uiCaptionSize` hint that elides at
  `Layout.minimumWidth: 0`. Its height is the fixed implicit height of those
  children, so the `Layout.fillHeight` list slot shrinks by the footer, never the
  other way; the bar sits directly under the empty note and above the card's
  bottom padding. `Globals.wheelStep` is 240 and `SmoothWheelLogic.wheelStep`
  scales the step by `|angleDelta| / 120` before clamping, so 120 is one step,
  240 is two, and 15/30-unit chunks move proportionally. `docs/user/app-launcher.md`
  documents the footer and the four-row notch. The Live criterion stays
  unchecked: it needs the running shell, which this worktree does not drive
  (no restart/reload, per the task's hard rules).
- 2026-10-09 (orchestrator, live screenshot): two fixes.
  - `KeyHint`'s label is `Layout.fillWidth`, and that propagates to the
    nested layout, so the three hints spread across the footer. Each footer
    hint now sets `Layout.fillWidth: false`, and they sit together as in
    the prototype.
  - The "Search apps…" placeholder hid on `activeFocus`, but the Apps field
    is always focused on open, so it never showed. It now hides only once
    there is text. Settings keeps its rule, because its field is not focused
    on open.

  `devprobe appsBench` on the restarted shell:
  `{"snapshotMs":2,"emptyMs":1,"stepsMs":[3,1,2,2,1],"clearMs":1,"runningMapMs":0}`.
