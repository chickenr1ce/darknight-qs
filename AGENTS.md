# AGENTS.md — Quickshell QML Conventions

This file defines project conventions for AI agents and contributors working in `~/.config/quickshell`.

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

---

## 4. QML Layout & General Best Practices

- **Never mix `anchors` and `Layout.*` on the same item.**
- **Versionless imports (Qt 6):** Use `import QtQuick` and `import QtQuick.Layouts` without version numbers.
- **Prefer declarative bindings** over imperative JavaScript assignments in signal handlers.

---

## 5. Docs

- For researching a quickshell component, refer to https://quickshell.org/docs/v0.3.1/guide/
- For current context on the project, refer to `plans/quickshell-migration.html`

### Notes

- Keep ids **understandable at a glance** — a reader should know the module and purpose without reading surrounding code.
- Prefer `idCpuLabel` over `idText`, `idWorkspaceButton` over `idRectangle`, `idAudioSetDefaultProcess` over `idProcessSetDefault`.
- When referencing the root from inside delegates, use `root.propertyName` (since root is always `root`).
- This convention applies to all new QML files and refactors. When editing existing files, rename generic ids to match this convention.
