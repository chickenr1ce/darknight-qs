# Coding Conventions — Quickshell QML

Style and structural rules for QML source in this repository.
`AGENTS.md` is the entry point; this document holds the details.

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
  notification toasts, the notification center, and future prose UI. Text
  sizes on reading surfaces come from the named `Globals.ui*Size` scale —
  never hardcode pixel sizes there.
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
  despite the docs claiming seconds (verified empirically 2026-09-12). Treat
  `0` as never-expire; fall back to 5s for `-1` and other non-positive values.
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
    color: Colors.lavender
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
    color: Colors.lavender
    Layout.fillWidth: true
}
```

This ordering is a deliberate project style choice and intentionally overrides the
ORD-1 rule of generic QML linters (which expect attached properties after plain
assignments). Treat ORD-1 flags on `Layout.*` placement as false positives.

---

## 5. Design Language for Panels and Plugins

All panels and plugins share tokens and primitives; never invent a parallel visual vocabulary.

### No new primitive

- If a panel needs a button, card, header, or shell, extend the shared component in `components/` (`PanelShell`, `PanelHeader`, `Card`, `IconButton`, `PillButton`, `PressFeedback`, `PressScale`).
- New panels compose `PanelShell` plus `PanelHeader`; new rows and cards compose `Card`. Ad-hoc `Rectangle` plus `MouseArea` buttons are off-limits.

### No raw values

- Colors, type sizes, radii, spacing, and durations come from `config/Colors.qml` or `config/Globals.qml` by role name (`Colors.panel`, `Colors.accent`, `Globals.panelPadding`, `Globals.cardRadius`), never hardcoded hex or pixel literals.
- Bar identity stays Iosevka (`Globals.fontFamily`); reading surfaces use the named Geist scale (`Globals.ui*Size`). Text sizes on reading surfaces never hardcode pixels.

### No layout reflow on state change

- Reserve width with `TextMetrics` plus `minWidth` for state-swapped glyphs; keep disabled controls laid out (dim plus inert) instead of hiding them.
- Panels use a fixed canvas plus input `mask` Region (see `PanelShell`); never bind window height to animated content.
