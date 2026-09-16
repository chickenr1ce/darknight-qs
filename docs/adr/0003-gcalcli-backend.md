# ADR 0003: gcalcli beside secret iCal, iCal stays default

Date: 2026-09-16. Feature: calendar (`#06`).

## Context

Ticket `#05` hit a wall Google built on purpose: the auto-generated
Contacts birthdays calendar has no secret iCal address, so the URL file
can never see birthdays no matter how many feeds it lists. Export and
import only postpones the backend the spec already named as the upgrade
path. Two options were real: retire iCal in favor of `gcalcli`
everywhere, or keep iCal and add `gcalcli` as an opt-in beside it.

## Decision

Both backends, iCal by default. `scripts/calendar-fetch.py` gains a
`--backend auto|ical|gcalcli` flag defaulting to auto: authenticated
`gcalcli` present means the OAuth token file exists and the binary runs,
and that selects the `gcalcli` path; anything else falls back to the
URL file exactly as today. The flag forces either way for testing and
for users who want one path pinned.

- The `gcalcli` path runs `gcalcli --nocache --nocolor agenda <start> <end>
  --tsv --details time --details title` over the same window the iCal
  path expands (`[fetchYear - 2, fetchYear + 6]`), with no `--calendar`
  filter so primary, birthdays, and holidays all arrive. `--nocache`
  because gcalcli caches the calendar list and a stale entry (deleted
  calendar) 404s the whole agenda — found live 2026-09-16 when two
  deleted calendars kept failing the poll through the cache. The `agenda`
  window is expected to return recurrences already expanded within it
  (confirm on the live poll); the helper only spans multi-day rows into
  the days map, and the checked-in TSV fixture stands in for expanded
  output until then.
- Both paths write the same `calendar-events.json` shape on the same
  poll with the same last-good-wins rule: any failure exits non-zero
  without touching the cache, and QML keeps its stale marker. QML is
  untouched.
- Each user brings their own Cloud project and OAuth client. This repo
  ships no client ID, no secret, no token. Quota, verification, and the
  full `calendar` scope gcalcli requests stay with the user, never here.
  The token file gets the same owner-only treatment as the URL file.

## Alternatives considered

- Retire iCal and require `gcalcli` for everyone: rejected. Every
  adopter would pay the per-user OAuth setup (project, consent, token)
  plus the sensitive-scope warning, and paste-a-URL onboarding (spec
  story 10, working minutes after clone) is worth keeping. Precedent:
  DMS ships a backend selector (auto/khal/dankcalendar) for the same
  reason.
- Pass `--calendar` names for primary plus birthdays plus holidays:
  rejected as the default. Calendar names vary by account and locale;
  the unfiltered agenda already covers all three unless the user ignored
  one in `gcalcli` config, which is their call. The helper still ships a
  repeatable `--gcalcli-calendar` pin (forwarded as `--calendar`) for
  users who want one path narrowed and for the argv gate to hold onto —
  the default stays unfiltered.

## Consequences

- Setup has two tiers in the helper docstring: the minutes-long iCal
  path and the Cloud project plus consent plus Desktop client plus
  first auth dance, including the testing-mode trap (unpublished apps
  get tokens that die every 7 days, so the guide says publish).
- `scripts/test-calendar-fetch.sh` covers both paths: a checked-in TSV
  fixture (single, recurring, multi-day timed and all-day, yearly
  birthday) converts to the expected JSON, and the selection rule plus
  both last-good paths are asserted with stub binaries.
- QML keeps calling the helper with `--url-file` and `--cache-file`
  only; auto-select means no QML change on either path.
