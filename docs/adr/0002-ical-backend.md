# ADR 0002: Secret iCal first, `gcalcli` later

Date: 2026-09-16. Feature: calendar (`#02`).

## Context

The calendar needs event dots plus a day agenda without a Google Cloud
project, OAuth dance, or QML touching the network. Two backends were real
candidates: the per-calendar secret iCal URL (one bearer URL, polled) versus
`gcalcli` (OAuth, multi-calendar search, true freshness).

## Decision

Secret iCal first. `scripts/calendar-fetch.py` (stdlib only) polls the primary
secret URL every 15 minutes, converts the feed to a local JSON cache, and QML
reads only the file:

- Cache shape: `{"fetchedAt": <local ISO>, "days": {<iso-date>: [{"t": "HH:MM"|"", "s": <title>}]}}`.
  Times are normalized to system-local at fetch time, so QML does lookups only.
- Recurrences expand in the helper over `[fetchYear − 2, fetchYear + 6]`
  (capped at 2000 instances per event), so any reasonable browse — including a
  year ahead — renders from cache with no network on month shift. Supported
  subset: `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY` with `INTERVAL`, `COUNT`, `UNTIL`,
  `BYDAY`, `BYMONTHDAY`, plus `EXDATE`/`RDATE`. `RECURRENCE-ID` overrides are
  ignored (base occurrence kept) — noted v1 limit.
- Any failure (network, conversion) exits non-zero without touching the cache:
  last good wins, and QML derives the stale marker from cache age instead of
  blanking. Writes are atomic (`mkstemp` + `os.replace`).
- The secret URL is a bearer token: it lives outside the repo at
  `${XDG_STATE_HOME:-~/.local/state}/quickshell/calendar-url` with owner-only
  permissions (the helper warns if group/other can read it), plain `https://`
  only, and rotation is Google's "Reset" control plus re-pasting. Covered by
  `scripts/test-calendar-fetch.sh` against a checked-in fixture (single,
  recurring, multi-day, TZID, UTC, folded lines).

## Amendments

- 2026-09-23 (arch review #05, Q3): the last-good events cache stays
  under `XDG_CACHE_HOME` (`CalendarService.cacheFile`). A cache cleaner
  can wipe it, and the stale marker covers failed polls but not a wiped
  cache. Moving the fallback to the state dir plus a startup seed stays
  out of scope until users ask.

## Alternatives considered

- `gcalcli` stays the named upgrade path for multi-calendar search or
  minute-level freshness; the secret address lags minutes to hours, which is
  fine for a day agenda but not for reminders. Both backends share the
  last-good-plus-stale offline pattern, so the QML side (`#03`) does not care
  which one fills the cache.
- QML-side recurrence expansion from cached rules was rejected: it would put
  date math into presentation code and re-expand on every month shift, while
  the helper expands once per poll.

## Consequences

- QML gains a 15-minute poll (`Process` + `Timer`, skipping ticks while a run
  is in flight) plus a `FileView` on the cache — ticket `#03`.
- Path defaults (`XDG_STATE_HOME`/`XDG_CACHE_HOME` with `~/.local/state` and
  `~/.cache` fallbacks) are duplicated in the helper and `CalendarService`;
  the helper additionally accepts explicit paths, which is what QML passes.
