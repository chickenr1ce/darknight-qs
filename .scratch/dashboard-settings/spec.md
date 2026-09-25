## Problem Statement

Settings live scattered across quick panels. Cava tuning lives in the Cava panel. Calendar zones and hidden feeds live in the Calendar panel. DND lives in the notification center. Reduced motion and bar layout have no UI at all. There is no single place to see system status or adjust everything. Users asked for one dashboard plus one settings window beside the quick panels.

## Solution

A dashboard card opened from the bar center plus a standalone settings window opened from a gear in the dashboard header. The dashboard shows status blocks in the V1 order. The settings window edits the V1 settings domains. Both bind the same service state as the quick panels, so a change on either side shows on the other at once. The dashboard stays open beside quick panels. The settings window opens above the dashboard.

## User Stories

1. As a shell user, I want to open a dashboard by clicking the bar center title, so that status and settings sit one click away.
2. As a shell user, I want hover feedback on the bar center title, so that the click target is discoverable.
3. As a shell user, I want the dashboard to slide down from the bar on open, so that the motion explains where it came from.
4. As a shell user with reduced motion on, I want the dashboard to appear at once with no slide, so that motion never causes discomfort.
5. As a multi monitor user, I want the dashboard to open on the screen I clicked, so that it stays near my cursor.
6. As a shell user, I want a weather block in the dashboard even as a placeholder, so that the V1 layout reserves its space.
7. As a shell user, I want a fastfetch summary block with distro plus compositor plus uptime, so that system identity is visible at a glance.
8. As a shell user, I want live CPU plus RAM use in the dashboard, so that load is visible without opening a terminal.
9. As a shell user, I want a GPU block in the dashboard even as a placeholder, so that the V1 layout reserves its space.
10. As a shell user, I want one volume slider per audio output, so that each sink is adjustable from the dashboard.
11. As a shell user, I want the player block to show track plus artist plus play pause plus next plus previous, so that control needs no new app window.
12. As a shell user, I want repeat plus shuffle toggles in the player block, so that playback modes are one click away.
13. As a Spotify user, I want the device switch inside the player block even as a placeholder list with phone plus PC entries, so that the V1 layout reserves its space.
14. As a shell user, I want a theme picker in the dashboard even as a placeholder, so that the V1 layout reserves its space.
15. As a shell user, I want a gear in the dashboard header that opens settings above the dashboard, so that values stay visible while I edit.
16. As a shell user, I want the dashboard to stay open when I open a quick panel, so that the two complement each other.
17. As a shell user, I want outside click to close the dashboard, so that dismissal is always one gesture.
18. As a shell user, I want Escape to close the dashboard, so that keyboard dismissal matches the panels.
19. As a shell user, I want the full Cava editor in settings with style plus sensitivity plus auto plus bars plus max height, so that tuning needs no panel.
20. As a shell user, I want a Cava change in settings to show in the Cava panel at once and the reverse, so that the two never disagree.
21. As a shell user, I want to add plus remove world clock zones in settings, so that zones are managed in one place.
22. As a shell user, I want per feed show hide toggles in settings, so that calendar feeds are managed in one place.
23. As a shell user, I want a DND toggle in settings that mirrors the notification center, so that quiet hours are set from either place.
24. As a shell user, I want a reduced motion toggle in settings, so that all animation gates from one switch.
25. As a shell user, I want one checkbox per bar module for visibility, so that bar layout is adjustable without editing code.
26. As a shell user, I want bar visibility to survive restart, so that layout choice sticks.
27. As a shell user, I want settings search to filter sections plus options by name, so that a long window stays navigable.
28. As a shell user, I want a no match note on empty search, so that silence never reads as breakage.
29. As a shell user, I want notification toasts to stay hidden while the dashboard is open, so that banners never cover the card. Proposed, needs confirm.
30. As a shell user, I want dashboard plus settings in my palette tokens, so that reference cream plus peach never ship.

## Implementation Decisions

- Dashboard state seam is a new dashboard service owning visibility, composed from the shared panel state pattern with toggle plus outside close plus anti reopen. It sits deliberately outside the exclusive panels registry so quick panels open beside it.
- Mirror rule is that settings plus panels bind the same service properties for Cava plus Calendar plus DND plus reduced motion. No duplicated state exists.
- Dismissal reuses panel shell behavior for outside click plus Escape plus anti reopen timing plus reduced motion gating.
- Animation is slide down from the bar on shared timing tokens, instant when reduced motion is on.
- Geometry is a centered card near the top edge, wider than the standard panel, with new spacing tokens, opening on the clicked screen.
- Player extends the existing MPRIS players seam with repeat plus shuffle plus a device list stub shaped for Spotify Connect.
- Volume extends the audio seam with per sink sliders beside the existing default sink control.
- CPU plus RAM use lightweight polling in the existing script plus cache pattern. Fastfetch runs one shot at open.
- Placeholders for weather plus GPU plus Spotify switch plus theme picker render fixed stub blocks with no network calls and no secrets.
- Bar visibility is a new persisted property with one checkbox per module, stored in a new state file under the existing state dir pattern with an echo guard.
- Settings search filters section contents by name, hides empty sections, and shows a no match note.
- Colors use palette tokens only.
- Toast rule proposal is that an open dashboard suppresses toasts like an open panel. Needs user confirm.
- Volume sliders may stretch into space freed by dropping the date plus calendar cards.

## Testing Decisions

- Tests cover external behavior only, never internals.
- Fixture tests cover new parsing for fastfetch output plus MPRIS repeat shuffle mapping plus per sink volume mapping. Prior art is the calendar fixture suite under the tests dir.
- Type lint plus review lint gates stay green.
- Live verification runs on a test instance with the smoke toasts gate for the toast layer, never beside the daily shell on the same bus.
- Placeholder blocks pass by sight with fixed content and no network traffic.

## Out of Scope

- Module order drag, monitor pick, working theme switch, live weather, live GPU, working Spotify switch, keybind open, brightness control, audio sink order editor, media player pick.
- Dashboard tabs. V1 is one scroll view.
- Reference colors. They were layout reference only.

## Further Notes

- Choices come from the grill rounds plus the reference picture. No prototype code exists, so no snippet is inlined.
- The dashboard departs from the under trigger placement ADR by design. A new ADR or an amendment will record why.
- Open confirmations are toast suppression while the dashboard is open, no match wording, and volume stretch into freed calendar space.
