# 02: Explore a persisted-settings module behind StateFile

**What to build:** A design note, not code. Decide whether `StateFile` should
own more of the save path (the pre-load guard, JSON serialization, defaults)
and what shape that interface takes, given how differently the services parse.

**Blocking:** None

**Blocked by:** None

**Status:** needs-triage

## Origin

Candidate 1 of the 2026-10-07 architecture review proposed a schema module
(`{ key: { default, clamp } }`) owning parse, clamp, serialize and the guard.
Review feedback, verified against the code, showed the services' semantics do
not fit one schema:

- `MprisPlayers.applyApps` merges stored entries with the live `apps` map and
  keeps keys the file lacks.
- `BarVisibilityService.parseVisibility` starts from all-visible defaults and
  accepts only `false` from the file.
- `StateParsers.parseAudioSettings` filters two string lists (`hidden`,
  `order`); `parseFontSettings` keeps strings that `FontService.isAllowed`
  then checks against a runtime list.
- Calendar zones and hidden calendars are newline lists, not JSON;
  `ThemeService` uses `ThemeParsers.serializeSelection`.

A schema would need per-service parse hooks, so its depth is unproven.

## Questions to answer

- Is the smallest useful step a guard inside `StateFile.save()` itself
  (rejecting writes until `loaded`), so the seven copied guards disappear?
  What breaks for the unguarded Calendar and Weather writes?
- Does a `saveJson(obj)` helper earn its keep, or is it a pass-through over
  `JSON.stringify(payload) + "\n"`?
- Is there a second adapter shape (not just "JSON object with clamps") that
  justifies a schema seam?

## Acceptance criteria

- [ ] A short recommendation appended to this ticket under `## Amendments`,
      choosing among: guard in `StateFile.save()`, a `saveJson` helper, a
      schema module, or no change, with the reason.
- [ ] If the answer is a code change, a new ticket in this folder with exact
      symbols; if it is "no change", an ADR offer so future reviews don't
      re-suggest the schema.
