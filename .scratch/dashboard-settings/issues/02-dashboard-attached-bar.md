# 02: Dashboard attached to bar

**What to build:** The dashboard card meets the bar with no gap. Its top edge sits directly against the bar bottom edge on the clicked screen, so the two read as one joined surface. The full screenshot at `.scratch/dashboard-settings/reference.png` includes desktop chrome that is not part of the spec. The cropped card at `.scratch/dashboard-settings/reference-card-only.png` shows the card layout to match, moved up so its top edge touches the bar.

**Blocked by:** 01 Dashboard shell

**Status:** ready-for-agent

- [ ] Card top edge touches the bar bottom edge with no visible gap at dashboard width
- [ ] Attachment holds on the clicked screen and across bar widths with no overlap into the bar
- [ ] Slide down from the bar still reads on open, instant when reduced motion is on
- [ ] Outside click plus Escape still dismiss and quick panel beside-behavior is unchanged
- [ ] Type lint plus review lint gates pass and live verification runs on a test instance

## Amendments

- 2026-09-25: layout skeleton counts as this ticket per the card layout to
  match sentence. The card now carries the tab row plus weather, system, CPU,
  volume, player with Spotify devices, and calendar stubs in palette tokens
  with no network traffic. Tabs stay a static indicator since V1 is one scroll
  view. Live data lands in 06 and final order plus polish stays in 07, whose
  calendar revision still applies.
- 2026-09-25: all attached chrome shaping reverted on user direction. Seam
  cover, notch discs, flare Shape, window widening, and radius overrides are
  out. Attached mode is the top margin branch only, so the card keeps plain
  panel chrome touching the bar.
- 2026-09-25: NOT DONE. Junction shaping is unresolved and the live look is
  unapproved, so no box is checked. This commit is a checkpoint of attachment
  plus layout skeleton only. Ticket stays open until the junction verdict
  lands.
- 2026-09-25: junction verdict landed by prototype (`.scratch/dashboard-settings/prototype-junction.html`):
  concave fillet, default radius 16, user adjustable 0 to 32. The window
  widens to `dashboardWidth + 2r` and shifts left by `r`; top margin 31 for a
  1px underlap under the bar; the border stroke drops the top segment; the
  mask follows the outline; the widened window clamps to `PanelEdgeMargin`.
  The radius value lives on `DashboardService.junctionRadius`; `PanelShell`
  gains an opt-in `junctionRadius` defaulting to 0. Recorded in ADR 0005.
  Ticket stays open until the slices and live check land.
