# Quickshell Desktop Shell — Plan Artifacts

Frozen records of the Waybar → Quickshell migration and the design work that
followed it, for `chickenr1ce/darknight-qs`.

Active work lives in [`docs/dev/roadmap.md`](../dev/roadmap.md). The domain glossary is
[`CONTEXT.md`](../../CONTEXT.md); the "why" decisions are in
[`docs/adr/`](../adr/).

---

## Archived plans

Completed phases, specs, and reviews, frozen under `archive/`. Paths written
inside these files still name their original `docs/plans/` locations.

| # | Document | Status | Description |
|---|---|---|---|
| **01** | [`archive/01-master-quickshell-migration.html`](archive/01-master-quickshell-migration.html) | ⚪ Archived (2026-09-14) | Waybar → Quickshell migration roadmap (Phases 0–7), module checklist, and architectural decisions. |
| **02** | [`archive/02-phase-6a-unified-slab.html`](archive/02-phase-6a-unified-slab.html) | 🟢 Implemented | Unified slab restyle, motion tokens (140ms hover / 120ms press), hairlines, and the ModuleBox chassis. |
| **03** | [`archive/03-phase-6b-notifications-exploration.html`](archive/03-phase-6b-notifications-exploration.html) | ⚪ Archived | Exploratory notification designs (Concepts A, B, C), live sandbox, and comparative matrix. |
| **04** | [`archive/04-phase-6b-notifications-spec.html`](archive/04-phase-6b-notifications-spec.html) | 🟢 Implemented (spec frozen) | Design B spec: Power User Action Center, collapsible app accordions, inline reply, floating drop panel. |
| **05** | [`archive/05-post-migration-roadmap.html`](archive/05-post-migration-roadmap.html) | ⚪ Archived (superseded by `docs/dev/roadmap.md`) | Post-migration roadmap: hotplug, weather, matugen themes, gates. Live items moved to `docs/dev/roadmap.md`. |
| **06** | [`archive/06-architecture-review.html`](archive/06-architecture-review.html) | 🟢 Closed (2026-09-29) | Full codebase review plus eight deepening candidates. All items resolved or deferred; the status block records the per-item state. |
| **07** | [`archive/07-deepening-plan.md`](archive/07-deepening-plan.md) | 🟢 Implemented | The four Strong deepening candidates: dead notification card, one notification collection, state-file module, panel registry as a list. Shipped in `8eac72f`. |

---

## Conventions for Plan Files

- **Format**: plan artifacts are single-page HTML documents with live previews,
  state simulation, design tokens, and QML mapping. Roadmaps and shorter plans
  use Markdown (`07-deepening-plan.md`, `docs/dev/roadmap.md`).
- **Naming**: `NN-<phase-tag>-<descriptive-topic>.html`, sequential two-digit
  ordering.
- **Frozen records**: once a design session concludes and its work ships,
  settled decisions are promoted to `docs/adr/`, `CONTEXT.md`, or
  `docs/dev/coding-conventions.md`, then the artifact is moved to `archive/`. Git
  history keeps anything dropped; deletion loses nothing that has been promoted.
