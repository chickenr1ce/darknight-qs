# ADR 0004: per-calendar gcalcli fetch with a names array

Date: 2026-09-16. Feature: calendar (`#07`).

## Context

Ticket `#06` polled with one unfiltered `agenda` call. Two live
findings broke that shape within a day. First, a weeks feed dotted
every Monday with no in-shell answer. Second, one dead list entry
404d the whole unfiltered poll while each live calendar polled clean
alone — and the CLI's cached calendar list kept serving the corpse
until caching was disabled (`#06` hotfix). Both point the same way:
the helper must address calendars one by one and must know their
names.

## Decision

The `gcalcli` path runs discovery (`list`, caching disabled) and then
one `agenda` call per enabled calendar, tagging rows by the call that
produced them and merging into the same days map. Discovery names land
in the cache as a sorted `calendars` array beside `days`; the URL-file
path writes an empty array, which is how the panel knows no settings
apply. Hiding is a denylist: a repeatable ignore flag names skipped
calendars, so new feeds arrive enabled and hidden names stay listed
for re-enabling. The existing allowlist pin stays for manual and test
use. Any single failure still fails the whole poll with the cache
untouched — per-calendar failure isolation stays out, hiding is the
escape hatch, and the stale marker keeps telling the truth.

## Alternatives considered

- Keep one unfiltered call and filter rows client side: rejected.
  Agenda rows carry no calendar column, and the only tagging detail
  (`--details calendar`) is not usable here, so per-call tagging is
  the mechanism that actually exists.
- Allowlist-only (extend the existing pin, no ignore flag): rejected.
  New calendars would arrive invisible with no discovery path back,
  and hidden names would vanish from the settings list the moment
  they are hidden.
- Fail open on a dead calendar (skip it, keep the rest): rejected.
  A merged cache missing one feed under a fresh timestamp reads as
  complete when it is not. All-or-nothing plus the honest stale
  marker stays.

## Consequences

- Six calendars mean six agenda calls plus one list call per
  15-minute poll. Personal-quota cheap, and each call keeps the
  existing timeout.
- Fixture runs (`--gcalcli-input`) write an empty names array: no
  discovery ran, so no settings apply — same rule as the URL path.
- The panel settings view (`#08`) reads names from the cache and
  writes hidden names to a state file; the poll appends one ignore
  flag per hidden name.
