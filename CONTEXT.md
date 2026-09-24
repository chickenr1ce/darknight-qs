# CONTEXT.md

## Glossary

* Calendar panel: the `windows/CalendarCenter.qml` floating window plus `services/CalendarService.qml` state. Trigger is the `modules/Clock.qml` module in the bar left cluster.
* Under its trigger: every floating panel opens on the clicked monitor directly below its trigger module, pixel aligned, not side aligned. Calendar follows Clock, notification center follows the bell, cava follows its bars, future panels follow their own modules.
* Agenda: selected day event list under the month grid. Driven by existing `selectedIso`. Dots mark days with events.
* Inline zone edit: add and remove world clock zones inside the calendar panel. No separate settings window. Persisted to a file so zones survive restart.
* Last good plus stale: offline pattern shared by events and zones. Keep the last fetched file, show a stale marker from file age instead of blank.
* Backend: secret iCal URL plus curl first, `gcalcli` later if multi calendar search or true freshness matters. Per calendar URL, token is the URL.
* Full feed plus per view expansion: poll the full ICS feed, cache locally, expand recurrences only for the rendered 42 days. Month shift never triggers network, any year renders from cache.
* Cava panel: the `windows/CavaCenter.qml` floating window plus `services/CavaService.qml` state. Trigger is the `modules/Cava.qml` visualizer in the bar right cluster, DP-1 only.
* Cava styles: six modes (Bars, Mirrored, Wave, Wave Blocks, Ribbon, Ribbon Blocks). Scroll on the bars cycles the mode, the panel dropdown picks it directly.
* Cava tuning: sensitivity, auto sensitivity, bar count, max height. Persisted to the state file so settings survive restart. Changes that affect the engine restart the cava process. Bars flatten after 600ms without frames.
* Panels registry: the `services/Panels.qml` singleton owning the one-panel rule. Triggers call its toggle functions instead of writing each other's services; each service keeps its own state by composing `services/PanelState.qml`. `Panels.anyOpen` hides toasts while any panel is open.
* Hyprland focus: the `services/HyprlandFocus.qml` singleton owning focus-match plus cursor save, focus, and restore. Concurrent clicks queue behind the in-flight read; dispatch routes through an injectable function for testing. An empty toplevel list retries for about 3s, a hung cursor snapshot focuses without restore and warns, match failures warn.
* Notification center: the `windows/NotificationCenter.qml` floating window plus `services/NotificationServer.qml` state. Groups collapse by app with a loud header, dot plus uppercase name plus count plus quiet Clear. Rows carry a 3px rail in the app color, critical rows use danger red with a dark red wash. The list scrolls inside a capped height and expanding a group glides it into view. Opening the center clears banners and keeps history.
* Notification toasts: the `components/NotificationToast.qml` banners. At most 6 show, oldest drops first. Only critical toasts stick, a 0 timeout clamps to 30s, hover pauses decay. DND or an open center suppresses new toasts. The View action focuses the app through HyprlandFocus, then invokes.
* Primary monitor: `Globals.primaryMonitor` plus `onPrimaryMonitor()` is the single DP-1 rule. DP-1-only modules declare `monitorName` and compose the check with their own content rule; the shell passes the monitor name instead of setting visibility.
* Power panel: the `windows/PowerCenter.qml` floating window plus `services/PowerService.qml` state. Trigger is the `modules/PowerMenu.qml` power glyph in the bar right cluster, DP-1 only. One flat monochrome list; Lock fires at once through the hyprlock, betterlockscreen, i3lock chain, the other four arm and need one confirm.
* Reduced motion: the `Globals.reducedMotion` switch gating every panel animation (rows, footer, shared `PanelShell` entrance, `PressScale`) to instant. Off by default.
