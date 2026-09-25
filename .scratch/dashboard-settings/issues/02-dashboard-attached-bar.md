# 02: Dashboard attached to bar

**What to build:** The dashboard card meets the bar with no gap. Its top edge sits directly against the bar bottom edge on the clicked screen, so the two read as one joined surface. The full screenshot at `.scratch/dashboard-settings/reference.png` includes desktop chrome that is not part of the spec. The cropped card at `.scratch/dashboard-settings/reference-card-only.png` shows the card layout to match, moved up so its top edge touches the bar.

**Blocked by:** 01 Dashboard shell

**Status:** ready-for-agent

- [ ] Card top edge touches the bar bottom edge with no visible gap at dashboard width
- [ ] Attachment holds on the clicked screen and across bar widths with no overlap into the bar
- [ ] Slide down from the bar still reads on open, instant when reduced motion is on
- [ ] Outside click plus Escape still dismiss and quick panel beside-behavior is unchanged
- [ ] Type lint plus review lint gates pass and live verification runs on a test instance
