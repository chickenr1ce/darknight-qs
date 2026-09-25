# 01: Dashboard shell

**What to build:** Clicking the bar center title toggles a centered dashboard card on the clicked screen. The card slides down from the bar on open and appears at once when reduced motion is on. It stays open beside quick panels and closes on outside click plus Escape.

**Blocked by:** None

**Status:** done

- [x] Center click toggles the dashboard on the clicked screen with hover feedback on the title
- [x] Open animation is slide down from the bar, instant when reduced motion is on
- [x] Dashboard stays open when a quick panel opens and closes on outside click plus Escape
- [x] Type lint plus review lint gates pass and live verification runs on a test instance

## Amendments

- 2026-09-25: box 3 holds at registry level only. Live IPC probing with no
  pointer involved showed the dashboard plus the calendar close each other
  symmetrically through the focus grab outside path, so PanelShell reuse plus
  visible beside-behavior conflict under one grab per surface. Landed: Panels
  never touches dashboard visibility, guarded by scripts/test-panel-logic.sh
  section 8. True visual coexistence needs one grab covering both windows and
  moves to #08.
