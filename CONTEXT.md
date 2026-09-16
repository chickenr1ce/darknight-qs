# CONTEXT.md

## Glossary

* Calendar panel: the `windows/CalendarCenter.qml` floating window plus `services/CalendarService.qml` state. Trigger is the `modules/Clock.qml` module in the bar left cluster.
* Under its trigger: every floating panel opens on the clicked monitor directly below its trigger module, pixel aligned, not side aligned. Calendar follows Clock, notification center follows the bell, future panels follow their own modules.
* Agenda: selected day event list under the month grid. Driven by existing `selectedIso`. Dots mark days with events.
* Inline zone edit: add and remove world clock zones inside the calendar panel. No separate settings window. Persisted to a file so zones survive restart.
* Last good plus stale: offline pattern shared by events and zones. Keep the last fetched file, show a stale marker from file age instead of blank.
* Backend: secret iCal URL plus curl first, `gcalcli` later if multi calendar search or true freshness matters. Per calendar URL, token is the URL.
* Full feed plus per view expansion: poll the full ICS feed, cache locally, expand recurrences only for the rendered 42 days. Month shift never triggers network, any year renders from cache.
