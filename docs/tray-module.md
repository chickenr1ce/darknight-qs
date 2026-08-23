# Tray Module (`modules/Tray.qml`)

System tray module rendering StatusNotifierItem icons via
`Quickshell.Services.SystemTray`, mirroring waybar's tray module
(icon size 14, spacing `Globals.spacing`).

## Structure

```
ModuleBox (enableMouseArea: false)   ← box-level pane disabled; each icon is its own click target
└── Repeater over SystemTray.items
    └── Rectangle idTrayItem         ← hover/press highlight, 22×20 hit area
        ├── QsMenuAnchor             ← menu popup anchoring
        ├── IconImage (visible: false)
        ├── MultiEffect              ← re-renders the icon, optionally tinted
        └── MouseArea                ← clicks, hover, wheel
```

## Interaction map

| Input          | Behavior |
|----------------|----------|
| Left click     | `onlyMenu && hasMenu` → open menu; otherwise `activate()` |
| Right click    | `hasMenu` → open menu; **no menu** → `secondaryActivate()` fallback |
| Middle click   | `secondaryActivate()` |
| Vertical wheel | `scroll(angleDelta.y, false)` |
| Horizontal wheel | `scroll(angleDelta.x, true)` (used by items with horizontal sliders) |

The whole module hides itself when no tray items exist
(`visible: idTrayRepeater.count > 0`) so no empty padded box appears.

## Design decisions

### Menu handling via `QsMenuAnchor`

Menus are opened through Quickshell's official `QsMenuAnchor`
(`Quickshell.Widgets`) rather than manual `SystemTrayItem.display()`
calls. This gets correct positioning, screen-edge flipping, and popup
lifecycle for free, which matters on multi-screen and edge-anchored bar
setups. The right-click `secondaryActivate()` fallback preserves an
action for items that ship no menu at all.

### Declarative hover / pressed state

`isHovered` and `isPressed` bind directly to
`idTrayItemMouseArea.containsMouse` / `.pressed`. The previous version
kept them as plain properties mutated from six imperative
`onPressed` / `onEntered` / `onExited…` handlers; the binding form is
equivalent in behavior but matches the project convention of preferring
declarative bindings over imperative signal handlers.

### Symbolic icon tinting

Monochrome *symbolic* icons frequently render near-black on the dark
bar and become invisible. Symbolic icons are therefore tinted to
`Colors.text` with a `MultiEffect`:

```qml
readonly property bool isSymbolicIcon: String(idTrayItem.modelData.icon).includes("symbolic")

MultiEffect {
    anchors.fill: idTrayItemIcon
    source: idTrayItemIcon
    colorization: idTrayItem.isSymbolicIcon ? 1.0 : 0.0
    colorizationColor: Colors.text
}
```

Two details worth knowing:

- **Tinting is conditional.** Full-color icons pass through with
  `colorization: 0.0`, which leaves the image unchanged. Tinting every
  icon unconditionally would flatten colored icons (network applets,
  chat clients, media players…) into indistinguishable silhouettes.
- **The source `IconImage` is set `visible: false`.** `MultiEffect`
  renders its source into a texture itself, so leaving the source item
  visible draws every icon twice. Hidden sources still render through
  the effect.

### Icon rendering via `IconImage`

Icons load through `Quickshell.Widgets.IconImage` (purpose-built for
tray/theme icons), sized with `implicitSize: 14` so the bitmap matches
the layout size exactly.

## Known limitations

- **Symbolic detection is heuristic.** It checks whether the icon name
  contains `"symbolic"`. An app shipping a monochrome icon without the
  `symbolic` suffix will render untinted; if one shows up too dark on
  the bar, extend the check rather than enabling global colorization.
