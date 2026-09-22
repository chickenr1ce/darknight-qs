# Quickshell Desktop Shell — Architectural & Migration Plans

This directory contains the architectural blueprints, migration roadmaps, design proposals, and interactive specifications for the Quickshell Wayland shell (`chickenr1ce/darknight-qs`).

---

## Plan Directory & Index

| # | Document | Phase / Code | Status | Description |
|---|---|---|---|---|
| **01** | [`01-master-quickshell-migration.html`](01-master-quickshell-migration.html) | **ECO-HY3** (Master) | ⚪ Archived (Completed 2026-09-14) | Waybar → Quickshell migration roadmap (Phases 0–7), module checklist, and architectural decisions. Leftovers carry to 05. |
| **02** | [`02-phase-6a-unified-slab.html`](02-phase-6a-unified-slab.html) | **ECO-HY3a** (Phase 6a) | 🟢 Implemented | Unified Slab restyle specification, motion tokens (140ms hover / 120ms press), hairlines, and ModuleBox chassis. |
| **03** | [`03-phase-6b-notifications-exploration.html`](03-phase-6b-notifications-exploration.html) | **ECO-HY3b** (Phase 6b) | 🟢 Archived | Initial exploratory designs (Concepts A, B, C), live sandbox, and comparative matrix for the native notification daemon. |
| **04** | [`04-phase-6b-notifications-spec.html`](04-phase-6b-notifications-spec.html) | **ECO-HY3b** (Phase 6b) | 🟢 Implemented (spec frozen) | Concrete specification for **Design B** (Power User Action Center: `1A + 2A + 3A + 4A`), collapsible app accordions, inline reply, and floating drop panel. |
| **05** | [`05-post-migration-roadmap.html`](05-post-migration-roadmap.html) | **ECO-HY4** (Roadmap) | 🟡 Active | Post-migration roadmap: hotplug and slot carryover, calendar and weather panels, theme switching through matugen, maintenance gates. |
| **06** | [`06-architecture-review.html`](06-architecture-review.html) | **Review** | 🟡 Active | Full codebase review (layer map, inventory, twelve findings, risks, open questions) plus eight deepening candidates from the follow-up pass, ranked Strong or Worth exploring: panel state registry, monitor policy, Hyprland focus module, calendar seam, state-file module, invoke ordering, cava styles, pressable pill. |

---

## Conventions for Plan Files

- **Interactive HTML Format**: Plan files are interactive single-page HTML documents providing live previews, interactive state simulation, design tokens, and QML mapping.
- **Naming Pattern**: `NN-<phase-tag>-<descriptive-topic>.html` where `NN` is a sequential two-digit ordering index.
- **Frozen Records**: When a design session concludes, settled decisions are appended to the document under a dedicated `Frozen Decisions` section before feature implementation commences.
