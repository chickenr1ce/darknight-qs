# Delegated work

How a session briefs a subagent to implement or review a slice of this repo.
The brief carries the task; this file carries the standing rules, so a brief
names it in one line ("Standing rules: docs/agents/delegated-work.md") instead
of restating them.

## Standing rules for every subagent

- Work only in the worktree the brief names. Leave git history to the session
  that delegated: no `git commit`, `git push`, or `git stash`.
- Leave the running shell alone: `scripts/restart.sh` and `restart.sh --probe`
  take over the user's bar. Boot with `scripts/boot-check.sh` and look with
  `scripts/capture.sh`, which both run a throwaway instance.
- Iterate on the area's own `scripts/test-*.sh`; run `scripts/check.sh` once, at
  hand-off.

## Implementer hand-off

The hand-off lists the files changed, each acceptance criterion with how it was
checked, and any deviation from the ticket. A change the shell draws also
carries a capture of every surface it touches (`scripts/capture.sh`, see
`docs/dev/debugging-quickshell.md`), with the PNG paths.

## Reviewer brief

The reviewer gets the ticket, the diff, and the implementer's captures. It
reviews the code against `docs/dev/CODING_STANDARDS.md` and the ticket, and the
captures for visual hierarchy, column alignment, and a match with sibling
panels. It reads code and images only and edits nothing.
