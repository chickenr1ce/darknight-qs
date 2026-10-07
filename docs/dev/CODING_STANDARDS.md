# Coding Standards — Quickshell

Rules for QML and `scripts/*.sh` changes: read this document before writing or
reviewing either. `AGENTS.md` is the entry point; this document holds the
details.

---

## 1. QML `id` Naming Convention

### Rule

- **Every `id` is prefixed with `id`** followed by a descriptive PascalCase name.
- **Exception: the root element of a file is always `id: root`.** No prefix, no suffix — just `root`.
- All other elements must use the `id` prefix. Never use bare names like `clockText`, `box`, or generic type names like `idText`, `idRectangle`, `idProcess`.

### Pattern

```
id + <DescriptivePurpose>[<TypeSuffix>]
```

- `DescriptivePurpose` — what the element *is* or *does* (e.g. `Clock`, `Workspace`, `Audio`, `Cpu`, `PanelWindow`, `BarLayout`).
- `TypeSuffix` — optional QML type hint when it aids clarity (e.g. `Label`, `Timer`, `Process`, `Button`, `MouseArea`, `Collector`, `Repeater`, `Row`).

### Examples

| Category | Example `id` |
|----------|--------------|
| Root element (any file) | `root` |
| Labels / text | `idClockLabel`, `idMediaLabel` |
| Layouts & containers | `idBarLayout`, `idWorkspaceRow` |
| Delegates & buttons | `idWorkspaceButton`, `idModuleBoxMouseArea` |
| Processes, timers & collectors | `idCpuProcess`, `idClockTimer`, `idCpuCollector` |

### Anti-patterns (do not use)

```qml
// ❌ generic / type-only
id: idText
id: idRectangle
id: idProcess
id: idTimer
id: idMouseArea

// ❌ no prefix
id: clockText
id: box
id: panelWindow

// ❌ root with prefix
id: idRoot
id: idWorkspacesRoot
id: idClockRoot
```

### Correct

```qml
// ✅ root exception
ModuleBox { id: root }
ShellRoot { id: root }
Rectangle { id: root }

// ✅ descriptive + prefixed
Text { id: idClockLabel }
Process { id: idCpuProcess }
Rectangle { id: idWorkspaceButton }
Timer { id: idMediaTimer }
```

### Notes

- Keep ids **understandable at a glance** — a reader should know the module and purpose without reading surrounding code.
- Prefer `idCpuLabel` over `idText`, `idWorkspaceButton` over `idRectangle`, `idAudioSetDefaultProcess` over `idProcessSetDefault`.
- When referencing the root from inside delegates, use `root.propertyName` (since root is always `root`).
- This convention applies to all new QML files and refactors. When editing existing files, rename generic ids to match this convention.

---

## 2. Component Encapsulation & Sizing Conventions

### Sizing Contract via `implicitWidth` / `implicitHeight`
- Reusable components (e.g. `ModuleBox`) must **never assume their parent is a `Layout`** and must not declare `Layout.*` properties on their root item.
- Sizing constraints (`minWidth`, `maxWidth`) must be computed directly within `implicitWidth`:
  ```qml
  implicitWidth: {
      let w = idModuleBoxLayout.implicitWidth + (2 * root.horizontalPadding);
      if (root.minWidth > 0) w = Math.max(w, root.minWidth);
      if (root.maxWidth > 0) w = Math.min(w, root.maxWidth);
      return w;
  }
  ```

### Layout Host Pattern
- `ModuleBox` acts as a layout host wrapping an internal `RowLayout`.
- Children declared inside `ModuleBox` are reparented to the internal layout via `default property alias content: idModuleBoxLayout.data`.
- Simple single-item modules do not need manual anchors or margins; `ModuleBox` handles vertical centering and padding automatically.

---

## 3. Dynamic Content & Visual Stability

### Handling Long / Unbounded Text (e.g., Media Player)
- Use `maxWidth` on the container combined with native Qt text elision on child text items.
- Inside layout-hosted containers, configure eliding text items with:
  ```qml
  Text {
      id: idMediaLabel
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      elide: Text.ElideRight
  }
  ```
- **Avoid arbitrary string slicing in JavaScript** (e.g., `substring(0, 39) + "…"`); let Qt Quick perform accurate sub-pixel text elision.

### Stabilizing Fluctuating Numbers (e.g., CPU, Memory, Volume)
- **Do not use whitespace string padding** (e.g., `padStart(2, " ")`). It causes asymmetric visual gaps on the left side of single-digit numbers.
- **Stabilize using `minWidth` and centered text**: Set `minWidth` on the `ModuleBox` to accommodate the maximum expected number of digits, and center the label:
  ```qml
  Text {
      id: idCpuLabel
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
  }
  ```
- Alternatively, use zero-padding (`padStart(2, "0")`) if a digital gauge / sysmon style is explicitly desired.
- **Keep state-swapped controls laid out**: when a control appears/disappears
  with state (e.g. Clear All on empty history, badge on zero count), keep it
  laid out `disabled` (dim + inert) or reserve its width instead of hiding it,
  so siblings never slide.

---

## 4. QML Layout & General Best Practices

- **Never mix `anchors` and `Layout.*` on the same item.**
- **Versionless imports (Qt 6):** Use `import QtQuick` and `import QtQuick.Layouts` without version numbers.
- **Prefer declarative bindings** over imperative JavaScript assignments in signal handlers.
- **Positioners bypass `Behavior`**: `Column`/`Row` repositioning after a child is
  removed moves surviving children in a single step — `Behavior on y` never
  fires (verified empirically 2026-08-24). To animate model-driven reflow, use
  a `ListView` with a `displaced` Transition.
- **ListView assigns delegate `required property` values after instantiation**:
  delegate bindings evaluate once with the role null/undefined. Null-guard
  role-dependent bindings inside delegates (or wrap the delegate so role
  access is confined to one assignment).
- **Never size a window from animated content**: binding window/viewport
  height to `contentHeight` while a `displaced`/`add` transition runs is a
  feedback loop — `contentHeight` tracks the *animated* positions, the
  viewport collapses, and off-viewport delegates are destroyed mid-animation.
  Use a fixed-size canvas plus an input `mask` Region tracking real content.
- **Font family roles**: Iosevka (`Globals.fontFamily`) is the bar/module
  identity; `Globals.uiFontFamily` (Geist) is the reading-surface family for
  notification toasts, the notification center, the dashboard, and future prose
  UI. Both, plus the icon family, are user-selectable in Settings → Fonts and
  persisted by `FontService`; the names here are the shipped defaults. Text
  sizes on reading surfaces come from the named `Globals.ui*Size` scale; never
  hardcode pixel sizes there. The dashboard's type roles are in
  "Dashboard type roles" below.
- **A bare singleton name can resolve to a C++ type**: if a file imports both
  a Quickshell service module (for a delegate's role type) and the matching
  `qs.*` module, e.g. `NotificationServer` from `Quickshell.Services.Notifications`
  vs our `qs.services` singleton, the C++ type shadows the singleton and calls
  die at runtime (`... is not a function`, verified 2026-09-12). Alias the
  service import (`import Quickshell.Services.Notifications as Notif`) and say
  why in a comment.
- **Deleted C++ objects null out delegate bindings**: the notification server
  deletes/recreates `NotificationAction` objects on update, so delegates
  briefly hold a dead `modelData` during rebuild — null-guard member access
  (`modelData ? modelData.text : ""`), not just the role assignment. Same for
  any animator callback touching a model object (`retireToast()`), which can
  fire after its row is retired.
- **`PanelWindow` takes no keyboard focus by default**: `focusable` is false
  (layer-shell keyboard interactivity None), so `TextInput.forceActiveFocus()`
  succeeds Qt-side while the compositor keeps routing keys to the focused app
  (verified 2026-09-12). Any window hosting text input needs `focusable: true`
  (on-demand: focus on click only, never stolen unprompted).
- **`expireTimeout` arrives in milliseconds**: Quickshell 0.3.1 delivers ms
  despite the docs claiming seconds (verified empirically 2026-09-12). A `0`
  timeout clamps to `Globals.toastStickyClampMs`, currently 30s; fall back
  to 5s for `-1` and other non-positive values.
  Only critical urgency sticks, checked through
  `NotificationServer.isCritical(notification)`.
- **Hover probes must sit above StyledText**: text items rendering StyledText
  accept hover themselves and shadow a probe placed underneath. Put the probe
  topmost with `Qt.NoButton` so clicks pass through, and route the covered
  controls' highlights via probe-relative geometry instead of `containsMouse`.
- **Reserve glyph width with `TextMetrics` + `minWidth`**: state-swapped glyphs
  (e.g. bell / slashed bell) differ in advance width and reflow the bar on
  swap. Measure the widest variant offscreen and reserve it, so the swap never
  moves siblings (verified live 2026-09-13).
- **`HyprlandToplevel.address` omits the `0x` prefix**: the `address:` window
  selector needs it, so prepend `0x` when missing (verified live 2026-09-13).
  Selecting by `class:` needs no prefix.
- **Focusing a Hyprland window warps the cursor**: snapshot the position first
  (`hyprctl cursorpos`) and restore it after with
  `hl.dsp.cursor.move({ x, y })`; focus stays on the window
  (verified live 2026-09-13).
- **`hyprctl keyword` is dead under Hyprland's Lua config parser**:
  `hyprctl keyword monitor DP-2,disable` prints `keyword can't work with
  non-legacy parsers. Use eval.` and no-ops, so a `Process` around it updates
  no state (verified live 2026-10-06, Hyprland 0.56.2 with the quattro Lua
  config). Configure monitors through `hyprctl eval 'hl.monitor({ … })'`;
  ADR 0016.
- **SNI theme icons arrive as `image://icon/` and draw `currentColor` black**:
  Qt renders monochrome panel SVGs (e.g. Papirus `spotify-linux-32`,
  `steam_tray_mono`) as black on the dark bar, so tint theme sources to text
  and pass pixmaps through untinted (verified live 2026-09-13).
- **No comments unless absolutely necessary** (verdict 2026-09-16,
  supersedes the why-only rule above): the code states the what, `docs/`
  keeps the why. Keepers are machine directives (`// qmllint disable ...`,
  `//@ pragma`, shebangs) and user-manual docstrings cited as docs. Trap
  knowledge belongs in `docs/`, not beside the code.
- **Fixed-height rows pin overflow to the top**: a row height shorter than its
  tallest child never centers the excess — a 22px pill in a fixed 18px row
  spans top to bottom of the slot (measured 8..30 in a 34 bar, verified live
  2026-09-14). Size rows to fit their tallest child instead of fixing height
  below content.
- **A `Card` in a horizontal row must set `Layout.fillHeight: true`**: without
  it the shorter card floats centered against its taller sibling instead of
  sharing the row height (measured live 2026-09-27: a 40px weather card
  floating in an 89px row beside an 89px system card). The card's implicit
  height follows its content, so a one-line card stays short even when the row
  grows to fit a taller neighbour.
- **A `Card` in a top-level `RowLayout` trips a recursive-rearrange warning**:
  `Card.implicitWidth` binds to `parent.width`, so a row sized from its parent
  reads a child that reads the row back; Qt logs `Detected recursive rearrange.
  Aborting after two iterations` and abandons the pass (verified live
  2026-09-27: the dashboard meters row at the shell layout root). Pin the
  flexible card's `Layout.preferredWidth` (e.g. `0`) so the layout stops
  reading its implicit width. A row nested inside another layout does not
  trigger it.
- **`anchors.verticalCenter` rounds fractional centers down**: a 23 row in a
  34 zone must sit at 5.5 but the anchor lands on 5 (measured live via IPC,
  verified 2026-09-14). Pin with an explicit fractional margin
  (`topMargin: (zoneHeight - implicitHeight) / 2`) when centering odd into
  even; at scale 2 the half pixel lands on a physical pixel and stays crisp.
- **Root-level change handlers run before child bindings refresh**: a root
  `onWorldZonesChanged` fires before a child `Process.command` binding
  re-evaluates, so starting the process there captures the previous
  arguments (verified live 2026-09-16: a new zone stayed blank until the
  next minute tick). Defer the start with
  `Qt.callLater(() => idZoneProcess.running = true)`; the command read at
  launch then sees the fresh value.
- **`Behavior` animation starts before its `duration` binding refreshes**:
  a `duration: visible ? openMs : closeMs` inside the animated `Behavior`
  still holds the previous value when the animation starts, so open runs at
  close speed and close at open speed (verified live 2026-09-16: open 220 /
  close 1000 appeared swapped). Read the inverted ternary in `PanelShell`
  (`panelVisible ? centerCloseMs : centerOpenMs`); do not "fix" it back.
- **Nothing renders outside the panel layout**: `PanelShell` masks the window
  to the layout rect, so an overlay popup or floating list is clipped and dead
  on arrival. Grow the layout in-flow instead — the expanding dropdown list
  pushes rows down exactly like the calendar settings view (verified live
  2026-09-16).
- **Centered `Repeater` rows round upward**: per-item `AlignVCenter` floors
  fractional centers, biasing a mirror axis ~0.7px high at scale 1 (measured
  live via `grim` plus per-column pixel midpoints, 2026-09-16). Correct with an
  explicit optical nudge (`centerOpticalNudge`); `Shape` paths use float
  coordinates and need none.
- **Nerd glyphs need a measured optical nudge**: icon-font advances carry
  extra right bearing, so a `centerIn`-aligned glyph renders ~1px left of its
  box center (measured live via `grim` pixel reads at scale 1, verified
  2026-09-23). Correct with a named token (`glyphOpticalNudge`) and re-measure
  after any font-family change, since fallback resolution can shift bearings.
- **ORD-1 now encodes the project order**: `id, layout, properties, signals,
  assignments, attached, states, transitions, handlers, children, functions`.
  `Layout.*` sits directly under `id`; group blocks (`anchors {}`, `font {}`,
  `border {}`, `margins {}`) and JavaScript braces (`try {}`, `return {}`)
  are scopes, not child objects. Remaining ORD-1 findings are genuine —
  fix the code, do not re-baseline them.
- **Remaining linter tripwire**: object-literal keys named like properties
  fake out the imperative-assignment rule (build settings objects with
  bracket assignment).
- **`scripts/lint.sh` and `scripts/lint-review.sh` lint tracked plus untracked
  QML** (`git ls-files` plus `--others --exclude-standard`), warning on
  stderr when untracked files are included. Stage deletions before running
  the gate: an unstaged deletion (file gone, index entry kept) fails
  `lint.sh` with `Failed to open file` and exit 255 (verified 2026-09-23).
- **Files in a `qmldir` module never see siblings implicitly**: a service file
  naming a sibling type needs `import qs.services` (its own module) and the
  sibling needs a `qmldir` entry. `qmllint` resolves the sibling anyway, so
  only a live `quickshell -p` boot catches the missing import (`... is not a
  type`, verified 2026-09-23).
- **A directory without a `qmldir` is an implicit module**: `components/`,
  `config/`, `modules/`, and `windows/` need no `qmldir` and resolve through
  `qs.components`, `qs.config`, `qs.modules`, and `qs.windows`. Only
  `services/` and `dev/` carry a `qmldir`, because they declare singletons.
- **`qmllint` cannot resolve `qs.*`-rooted sibling types**: a file whose root
  type comes from an import path qmllint lacks (e.g. a `Card` from
  `qs.components`) fails as a type everywhere it is used, cascading
  `unresolved-type` noise across importers while the gate still exits 0.
  Existing files warn the same way, so a live `quickshell -p` boot is the
  authority on whether a type resolves (verified 2026-09-25).
- **A binding that reads and writes the same property loops**: memoizing
  inside the binding (read the cached text, write it back) registers the
  memo as a dependency of itself — startup logs `Binding loop detected`.
  Memoize with an explicit refresh function driven by `onLoaded` instead,
  early-returning on identical input (verified 2026-09-23).

### Dashboard type roles

Every `Text` in the dashboard fills one role. The Control row is the shell's
shared control scale for pill and button labels, not a dashboard-only style; its
example names the control whose label takes the role. Family is
`Globals.uiFontFamily` (Geist) throughout. The role sets size, weight, and
tracking. `tnum` is not a role: set `features: ({ "tnum": 1 })` on any readout
whose digits change while it is visible, so they do not jitter in place.

| Role | Size | Weight | Tracking | Example id |
| --- | --- | --- | --- | --- |
| Hero | `Globals.uiDisplaySize` 28 | `Font.DemiBold` | none | `idWeatherTemp` |
| Primary | `Globals.uiBodySize` 14 | `Font.DemiBold` | none | `idPlayerTrack` |
| Row label | `Globals.uiBodySize` 14 | `Font.Normal` | none | `idUsageLabel` |
| Value | `Globals.uiCaptionSize` 12 | `Font.Medium` | none | `idUsageValue` |
| Field label | `Globals.uiCaptionSize` 12 | `Font.Medium` | `Globals.uiLetterSpacing` | `idSystemSpecLabel` |
| Section caption | `Globals.uiCaptionSize` 12 | `Font.Medium` | `Globals.uiLetterSpacing` | `idThemeCaption` |
| Hero caption | `Globals.uiCaptionSize` 12 | `Font.Medium` | none | `idWeatherCity` |
| Secondary | `Globals.uiCaptionSize` 12 | `Font.Normal` | none | `idPlayerArtist` |
| Control | `Globals.uiPillSize` 13 | `Font.Medium` | none | `idPlayerDeviceChip` |

- Field labels and section captions track; values do not. All three are
  `uiCaptionSize` `Font.Medium`, so the tracking is what separates a metadata
  label (RAIN, KRNL, Theme) from a data value (usage percent, sink percent).
  Hero caption is a static context line, the weather city name, so it stays
  untracked as well.
- Two control scales, chosen by level. Navigation tabs (Dashboard, Media,
  Performance, Workspaces) are page-level and use the 14 Primary or Row scale;
  inline buttons and chips use the `uiPillSize` 13 Control scale. The selected
  treatment differs with the scale: an active tab turns DemiBold and gains an
  underline, while a highlighted pill stays Medium and gains a fill.
- `NET` is a row label, not a field label. It labels a data row the way CPU, GPU,
  and RAM do, and it sits in the network footer, not in a label and value
  metadata list. Keep it at `uiBodySize` `Font.Normal` with no tracking.

### Attribute Ordering: `Layout.*` directly under `id`

Attached `Layout.*` properties come **immediately after the `id` line**, before all
property declarations, bindings, and other attributes:

```qml
// ✅ correct
Text {
    id: idMediaLabel

    Layout.fillWidth: true
    Layout.minimumWidth: 0

    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Colors.accent
}

Rectangle {
    id: idWorkspaceButton

    Layout.alignment: Qt.AlignVCenter

    required property int index
    implicitWidth: 40
}
```

```qml
// ❌ wrong — Layout.* buried among assignments/properties
Text {
    id: idMediaLabel
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Colors.accent
    Layout.fillWidth: true
}
```

This ordering is a deliberate project style choice and intentionally overrides the
ORD-1 rule of generic QML linters (which expect attached properties after plain
assignments). Treat ORD-1 flags on `Layout.*` placement as false positives.

- **`AuthFlow` reports a failed attempt through `failed`, not `supplementaryMessage`**: `completed(false)` sets `failed` and re-opens the session, while `supplementaryMessage` is only populated when PAM emits `show-error`. A PAM message row must show on `supplementaryMessage !== "" || failed`, and style it as an error only when `supplementaryIsError || failed` — PAM also sends informational notices (a faillock lockout) with `supplementaryIsError` false.
- **A signal handler can read a stale binding**: `AuthFlow.failedChanged` fires before a sibling `hasMessage` binding re-evaluates, so a handler that guards on that binding sees the old value and the action silently never runs. Trigger on the property change directly (an `onHasMessageChanged`) and defer the work with `Qt.callLater`, which also coalesces the multiple triggers.
- **`clip: true` is correct for a password field and a masked progress track**: `TextInput` scrolls its content but does not contain it, so an unclipped field paints a long value over its neighbours. The review linter's PRF-3 is a scene-graph batching advisory; bless a deliberate case with `scripts/lint-review.sh --update-baseline`.

---

## 5. Design Language for Panels and Plugins

All panels and plugins share tokens and primitives; never invent a parallel visual vocabulary.

### No new primitive

- If a panel needs a button, card, header, or shell, extend the shared component in `components/` (`PanelShell`, `PanelHeader`, `Card`, `IconButton`, `PillButton`, `PressFeedback`, `PressScale`).
- New panels compose `PanelShell` plus `PanelHeader`; new rows and cards compose `Card`. Ad-hoc `Rectangle` plus `MouseArea` buttons are off-limits.

### No copied rows

- Two settings rows or sections that share a shape compose one shared component (`SettingsToggleRow`, `SettingsSliderRow`, or a section view such as `CavaSettingsView`) rather than a copy. A control's label and hint live in the shared component once, never per section.
- A value row counts as a row: two label/value rows that share a shape (label, value, their own `TextMetrics`, and a `Slider`) compose one component, not a copy. `components/SettingsSliderRow.qml` owns that shape; `CavaSettingsView` and `DashboardSettingsView` compose it.

### No raw values

- Colors, type sizes, radii, spacing, and durations come from `config/Colors.qml` or `config/Globals.qml` by role name (`Colors.panel`, `Colors.accent`, `Globals.panelPadding`, `Globals.cardRadius`), never hardcoded hex or pixel literals.
- Bar identity defaults to Iosevka (`Globals.fontFamily`, user-selectable in
  Settings → Fonts); reading surfaces use the named Geist scale
  (`Globals.ui*Size`). Text sizes on reading surfaces never hardcode pixels.
- Glyphs come from `config/Icons.qml` through `components/Icon.qml`; never write a nerd-font glyph literal in a module. The registry is the single source of truth for icon codepoints, so no glyph depends on fontconfig fallback picking a foreign family.

### No layout reflow on state change

- Reserve width with `TextMetrics` plus `minWidth` for state-swapped glyphs; keep disabled controls laid out (dim plus inert) instead of hiding them.
- Panels use a fixed canvas plus input `mask` Region (see `PanelShell`); never bind window height to animated content.

---

## 6. Shell scripts

Conventions for the shell scripts under `scripts/`. `scripts/lint-shell.sh`
(shellcheck at warning severity) covers the mechanical rules; this section
covers the judgement calls it cannot check.

### Shebang and dialect

A `#!/bin/sh` script stays POSIX: no `[[ ]]`, `local`, `mapfile`, arrays, or
`pipefail`. The test and lint scripts are `#!/usr/bin/env bash` and may use them.

### Errors and output

`die "message"` writes `script: message` to stderr and exits 1; fail loudly and
early. `say "message"` writes progress to stderr, so a command's stdout stays
machine-readable. Results a caller parses go to stdout, one per line.

### Untrusted text

Strip control characters from any name, URL, or tool error that came from
outside the script before printing it, so an escape sequence cannot reach the
terminal. `safe` removes every control character for a single line; `safe_lines`
keeps newlines so a block listing holds its shape.

### Validate before you write

Resolve and check every argument first, then mutate. One bad argument leaves the
target unchanged. A batch verb refuses the whole batch on the first problem
rather than half-applying it.

### Symlinks and paths

Refuse a symlinked source, destination, or any directory a write or delete
traverses. A destructive verb takes a slug: exactly one plain path segment,
lowercased, with no `/`, no `..`, no leading dot, and characters limited to
`a-z0-9._+-`. That makes the path it names the only path it can touch. Delete
only a plain file directly under the intended directory, never with `rm -r`.

### Options and operands

Long options are `--name value`. `--` ends option parsing, so an operand that
begins with `-` is reachable (`qs-theme remove-background -- -wall.png`). An
unknown `--option` is an error, not an operand.

### The theme-root seam

`qs-theme` writes the theme root itself for `install`, `remove`, and the
background verbs; the running shell owns the catalog, the selection, and the
applied background. After a theme-root write, ping the shell best-effort
(`quickshell ipc call theme refresh >/dev/null 2>&1 || true`) so it rescans
without a restart. The write still succeeds when the shell is down.

### Tests

Every `scripts/*.sh` change gets a headless `scripts/test-*.sh` check wired into
`scripts/check.sh`. The check runs offline: clone a local fixture repository
instead of reaching the network, and put a stub `quickshell` on `PATH` instead
of contacting the running shell.

The gate runs from a git hook, where git exports `GIT_DIR`, `GIT_WORK_TREE`, and
`GIT_INDEX_FILE`. A check that runs `git -C <tempdir> ...` must clear those
first or it retargets this repository; `scripts/check.sh` unsets them at the top,
so run a new git-using check through the gate rather than on its own.

---

## 7. Verification and review

Verification is `scripts/check.sh`: type lint (`scripts/lint.sh`), style lint
(`scripts/lint-review.sh`), shell lint (`scripts/lint-shell.sh`, skips when
shellcheck is not installed), the headless `scripts/test-*.sh` gates, and
`scripts/check-live-log.sh` (skips when no instance is running). The style
linter is vendored at `scripts/qt_qml_lint.py` (BSD-3-Clause, The Qt Company).
`scripts/smoke-toasts.sh` is a separate deliberate run because it boots its own
instance; it is the regression gate for the notification toast layer. A `pre-commit` hook (`.githooks/`, enabled once per clone with
`git config core.hooksPath .githooks`) runs the gate; bypass a single commit with
`--no-verify`.

Review fanout: default to one spec pass plus one QML pass over the final diff,
each starting from `git diff` and the ticket rather than re-reading the codebase,
and verify any shell-semantics claim, and any Qt API claim through `qt-docs`,
before reporting it. Add a round only when a review reports a High finding.
