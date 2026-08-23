---
name: quickshell-patterns
description: >-
  Patterns for building Quickshell desktop shells with QML. Use when
  writing, editing, or reviewing any file under a quickshell config
  directory: shell.qml or shell entry files, PanelWindow/Variants bar
  layouts, Process/StdioCollector polling, Singleton services, or
  Quickshell.Services.* usage.
metadata:
  author: alexiz
  version: "3.1"
---

# Quickshell Patterns

Quickshell-specific API patterns for any config. Generic Qt6 QML practice
(bindings hygiene, delegates, loaders, performance) lives in the `qt-qml`
skill family; apply both together. Per-project conventions (naming,
structure, shared components) come from that config's own `AGENTS.md` —
read it before writing code there.

Reference docs: https://quickshell.org/docs/v0.3.1/guide/

## Entry point & Windows

- `ShellRoot` hosts the shell. One `PanelWindow` per screen through
  `Variants { model: Quickshell.screens }`; the delegate declares
  `required property var modelData` and binds `screen: modelData`.
- Bar panels anchor to their screen edges (`anchors.top/left/right`) with an
  inner layout filling them. Keep `color: "transparent"` on the window so
  child modules render their own backgrounds, borders, and margins.
- Menus and tooltips use `PopupWindow` or floating `PanelWindow` instances
  anchored to parents rather than expanding the primary bar surface.
- Every file opens with `pragma ComponentBehavior: Bound`; imports are
  relative paths and versionless (`import QtQuick`, never `QtQuick 2.x`).

## Sizing & Layout

Components size themselves through `implicitWidth` / `implicitHeight`;
assume nothing about the parent being a layout. Accept `minWidth` /
`maxWidth` properties and clamp inside the implicit-size binding:

```qml
implicitWidth: {
    let w = idLayout.implicitWidth + 2 * root.padding;
    if (root.minWidth > 0) w = Math.max(w, root.minWidth);
    if (root.maxWidth > 0) w = Math.min(w, root.maxWidth);
    return w;
}
```

A container acting as a host for children aliases its default property into
an internal layout, so hosted children need no anchors of their own:

```qml
default property alias content: idLayout.data
```

Position each item with one scheme: anchors for free-floating geometry,
`Layout.*` inside a layout host.

## Text and numbers

- Unbounded text elides natively: give the container `maxWidth`, give the
  text `Layout.fillWidth: true`, `Layout.minimumWidth: 0`,
  `elide: Text.ElideRight`. String surgery in JS (`substring`, manual `…`)
  is off-limits; Qt elides sub-pixel accurately.
- Fluctuating values hold steady via reserved width: size the module for
  the widest expected value via `minWidth`, center the label
  (`horizontalAlignment: Text.AlignHCenter` + `Layout.fillWidth: true`).
  Reserve zero-padding (`padStart(2, "0")`) for an explicit digital-gauge
  style.

## State and services

- Cross-module state lives in `pragma Singleton` files registered in a
  `qmldir` (`singleton Name 1.0 Name.qml`). Modules bind to singleton
  properties rather than holding private copies.
- Reach for built-in services before shelling out:
  `Quickshell.Services.Mpris`, `Quickshell.Services.Pipewire`,
  `Quickshell.Bluetooth`, `Quickshell.Services.Notifications`. List-valued
  services read via `.values` (`Mpris.players.values`).
- Poll system data with `Process` + `StdioCollector` driven by a `Timer`:
  parse in `onStreamFinished` / `onExited`, clamp computed values, keep the
  previous sample in a plain property, and skip a tick while the previous
  run is still in flight:

  ```qml
  Process {
      id: idStatProcess
      command: ["cat", "/proc/loadavg"]
      stdout: StdioCollector { id: idStatCollector }
  }
  Timer {
      id: idPollTimer
      interval: 2000
      running: true
      repeat: true
      onTriggered: {
          if (!idStatProcess.running)
              idStatProcess.running = true;
      }
  }
  ```

- Prefer declarative bindings onto service objects over imperative signal
  handlers; reserve handlers for logic bindings cannot express.

## Done means

1. Components self-size through implicit sizes; clamps flow through
   `minWidth` / `maxWidth`.
2. Long text elides natively; fluctuating values reserve width.
3. Shared state sits in singletons or service singletons; modules stay
   presentation-only.
4. Polling processes skip ticks while a previous run is in flight and
   handle stream completion cleanly.
5. The config's own `AGENTS.md` conventions were read and followed.
