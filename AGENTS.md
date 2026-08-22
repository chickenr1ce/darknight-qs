# AGENTS.md — Quickshell QML Conventions

This file defines project conventions for AI agents and contributors working in `~/.config/quickshell`.

## QML `id` Naming Convention

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

| File | Element | `id` |
|------|---------|------|
| `shell.qml` | `ShellRoot` (root) | `root` |
| `shell.qml` | `Variants` | `idScreenVariants` |
| `shell.qml` | `PanelWindow` | `idPanelWindow` |
| `shell.qml` | `RowLayout` (bar) | `idBarLayout` |
| `shell.qml` | `Item` (spacer) | `idSpacer` |
| `components/ModuleBox.qml` | `Rectangle` (root) | `root` |
| `components/ModuleBox.qml` | `RowLayout` | `idModuleBoxLayout` |
| `components/ModuleBox.qml` | `MouseArea` | `idModuleBoxMouseArea` |
| `modules/Workspaces.qml` | `ModuleBox` (root) | `root` |
| `modules/Workspaces.qml` | `RowLayout` | `idWorkspaceRow` |
| `modules/Workspaces.qml` | `Repeater` | `idWorkspaceRepeater` |
| `modules/Workspaces.qml` | `Rectangle` (delegate) | `idWorkspaceButton` |
| `modules/Workspaces.qml` | `Text` | `idWorkspaceLabel` |
| `modules/Workspaces.qml` | `MouseArea` | `idWorkspaceMouseArea` |
| `modules/Clock.qml` | `Text` | `idClockLabel` |
| `modules/Clock.qml` | `Timer` | `idClockTimer` |
| `modules/Cpu.qml` | `Text` | `idCpuLabel` |
| `modules/Cpu.qml` | `Process` | `idCpuProcess` |
| `modules/Cpu.qml` | `StdioCollector` | `idCpuCollector` |
| `modules/Cpu.qml` | `Timer` | `idCpuTimer` |
| `modules/Media.qml` | `Timer` | `idMediaTimer` |
| `modules/Media.qml` | `Text` | `idMediaLabel` |
| `modules/Audio.qml` | `Text` | `idAudioLabel` |
| `modules/Audio.qml` | `Process` (set-default) | `idAudioSetDefaultProcess` |
| `modules/Audio.qml` | `Process` (mixer) | `idAudioMixerProcess` |
| `modules/Notifications.qml` | `Text` | `idNotificationsIcon` |
| `modules/Notifications.qml` | `Process` | `idNotificationsProcess` |
| `modules/PowerMenu.qml` | `Text` | `idPowerMenuIcon` |
| `modules/PowerMenu.qml` | `Process` | `idPowerMenuProcess` |

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

### Docs

For researching a quickshell component, refer to https://quickshell.org/docs/v0.3.1/guide/

For current context on the project, refer to plans/quickshell-migration.html

### Notes

- Keep ids **understandable at a glance** — a reader should know the module and purpose without reading surrounding code.
- Prefer `idCpuLabel` over `idText`, `idWorkspaceButton` over `idRectangle`, `idAudioSetDefaultProcess` over `idProcessSetDefault`.
- When referencing the root from inside delegates, use `root.propertyName` (since root is always `root`).
- This convention applies to all new QML files and refactors. When editing existing files, rename generic ids to match this convention.
