# Issue tracker: local markdown

Issues and specs for this repo live as markdown files under `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation tickets are one file per ticket at
  `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a
  single combined tickets file
- Triage state is a `**Status:**` line near the top of each ticket; the
  vocabulary is in `docs/agents/triage-labels.md`
- Dependencies are `**Blocking:**` and `**Blocked by:**` headers near the top.
  A ticket is ready when every ticket it is blocked by is done
- Commit messages cite their ticket as `#NN` (for example
  `feat(notifications): toasts (#02)`); resolve it with `git log --grep "#NN"`
- Acceptance criteria name exact file paths and symbols (`ThemeService.catalog`,
  not `ThemeService.themes`), so an implementing agent does not have to guess
  which API is meant
- Scope changes append a dated `## Amendments` entry under the original
  objective instead of editing the objective or acceptance criteria in place
- Durable docs (`CONTEXT.md`, ADRs, `docs/`) describe a pending ticket in words
  rather than by its `.scratch/` path: the folder is deleted when the feature
  merges, so the path dangles

`AGENTS.md` section 5 carries the full workflow, lifecycle, and amendment
rules. This file is the pointer the engineering skills read.

## When a skill says "publish to the issue tracker"

Create a new ticket file under `.scratch/<feature-slug>/issues/`, numbered from
`01`, with `**Status:**`, `**Blocked by:**`, an objective, and acceptance
criteria.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. Tickets are normally passed by path or by
number, resolved in the feature's `issues/` directory.
