# Quickshell Desktop Shell — Architectural & Migration Plans

This directory contains the architectural blueprints, migration roadmaps, design proposals, and interactive specifications for the Quickshell Wayland shell (`chickenr1ce/darknight-qs`).

---

## Plan Directory & Index

| # | Document | Phase / Code | Status | Description |
|---|---|---|---|---|
| **01** | [`01-master-quickshell-migration.html`](01-master-quickshell-migration.html) | **ECO-HY3** (Master) | 🟡 Active | Waybar → Quickshell migration roadmap (Phases 0–7), module checklist, and architectural decisions. |
| **02** | [`02-phase-6a-unified-slab.html`](02-phase-6a-unified-slab.html) | **ECO-HY3a** (Phase 6a) | 🟢 Implemented | Unified Slab restyle specification, motion tokens (140ms hover / 120ms press), hairlines, and ModuleBox chassis. |
| **03** | [`03-phase-6b-notifications-exploration.html`](03-phase-6b-notifications-exploration.html) | **ECO-HY3b** (Phase 6b) | 🟢 Archived | Initial exploratory designs (Concepts A, B, C), live sandbox, and comparative matrix for the native notification daemon. |
| **04** | [`04-phase-6b-notifications-spec.html`](04-phase-6b-notifications-spec.html) | **ECO-HY3b** (Phase 6b) | 🟢 Approved / Frozen | Concrete specification for **Design B** (Power User Action Center: `1A + 2A + 3A + 4A`), collapsible app accordions, inline reply, and floating drop panel. |

---

## Conventions for Plan Files

- **Interactive HTML Format**: Plan files are interactive single-page HTML documents providing live previews, interactive state simulation, design tokens, and QML mapping.
- **Naming Pattern**: `NN-<phase-tag>-<descriptive-topic>.html` where `NN` is a sequential two-digit ordering index.
- **Frozen Records**: When a design session concludes, settled decisions are appended to the document under a dedicated `Frozen Decisions` section before feature implementation commences.
