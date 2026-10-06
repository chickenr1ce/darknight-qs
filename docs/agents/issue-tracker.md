# Issue tracker: local markdown

Issues and specs for this repo live as markdown files under `.scratch/`. This
file is the single source of truth for the tracker; the engineering skills read
it and `docs/agents/triage-labels.md` with no setup step.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation tickets are one file per ticket at
  `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a
  single combined tickets file
- Tickets are tracer bullets: each declares its explicit blocking relationship
  and its acceptance criteria
- Triage state is a `**Status:**` line near the top of each ticket; the
  vocabulary is in `docs/agents/triage-labels.md`, and `ready-for-agent` marks a
  ticket an agent can pick up
- Dependencies are `**Blocking:**` and `**Blocked by:**` headers near the top.
  A ticket is ready when every ticket it is blocked by is done
- When implementing a feature, work `.scratch/<feature>/issues/` pending tickets
  blockers-first
- Flip `Status` and dependency headers freely as state changes
- Commit messages cite their ticket as `#NN` (for example
  `feat(notifications): toasts (#02)`); resolve it with `git log --grep "#NN"`.
  Tickets describe commits in words only ("the ticket-02 feature commit") — raw
  SHAs go stale under squash, ticket numbers don't
- Any long-lived commit anchor (review fixed point, milestone) gets a lightweight
  git tag at creation time (e.g. `git tag review-base/<feature> <sha>`);
  documents and review invocations cite the tag
- Acceptance criteria name exact file paths and symbols (`ThemeService.catalog`,
  not `ThemeService.themes`), so an implementing agent does not have to guess
  which API is meant
- Scope changes append a dated `## Amendments` entry under the original
  objective instead of editing the objective or acceptance criteria in place —
  the ticket file is what code-review's Spec axis judges against. A follow-up
  change to a done ticket gets a dated amendment under the original; do not
  reopen it for a UI tweak. Work discovered mid-ticket becomes a new ticket
  noting its origin ("Discovered during #NN")
- Durable docs (`CONTEXT.md`, ADRs, `docs/`) describe a pending ticket in words
  rather than by its `.scratch/` path: the folder is deleted when the feature
  merges, so the path dangles

## Ownership

A feature's tickets are edited only from that feature's worktree branch;
cross-cutting docs change on the branch that owns them.

## Lifecycle

`.scratch/<feature>/issues/` lives only as long as the feature. When all tickets
are done, review is complete, and the branch merges: promote lasting lessons to
`docs/` (coding conventions, spec, retro output), then delete the folder in the
same merge/squash commit. Git history is the archive — deletion loses nothing.
Session handoffs (`~/.config/opencode/handoff-*.md`) die the same way: delete
once the feature merges and its cutover verifies.

## When a skill says "publish to the issue tracker"

Create a new ticket file under `.scratch/<feature-slug>/issues/`, numbered from
`01`, with `**Status:**`, `**Blocked by:**`, an objective, and acceptance
criteria.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. Tickets are normally passed by path or by
number, resolved in the feature's `issues/` directory.
