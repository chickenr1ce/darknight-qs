# IPC targets

The shell answers a set of IPC targets, so a Hyprland keybind, a script, or the
`qs-theme` CLI can open a panel, toggle Do Not Disturb, or change the volume
without touching the bar. Each target is an `IpcHandler` on the service that owns
its state; the running instance registers them, and `quickshell ipc show` lists
what an instance exposes.

## How to call

```sh
quickshell ipc call <target> <function> [args]
```

When more than one instance is running, pass the pid before `call`
(`quickshell ipc --pid <pid> call ...`) so the call reaches the intended one;
`docs/dev/debugging-quickshell.md` covers finding the pid. Most functions return
a short string that the call prints. The bar-anchored toggles (`calendar`,
`notifications`) answer `ok` when the request reached the bar module and an
`error: ...` message when it cannot; `power` is declared `void`, prints nothing,
and is a no-op when its module is hidden.

## Targets

### `power`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `toggle` | — | — | Toggles the power panel under the bar's power glyph. A no-op when the power module is hidden. |
| `close` | — | — | Closes the panel. |

### `calendar`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `toggle` | — | `ok` / `error: clock module is hidden` | Opens or closes the calendar under the primary monitor's clock, the same anchor a click uses. |
| `close` | — | `ok` | Closes the panel. |

### `notifications`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `toggle` | — | `ok` / `error: notifications module is hidden` | Opens or closes the notification center under the bar's bell. |
| `close` | — | `ok` | Closes the center. |

### `dashboard`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `toggle` | — | `ok` / `error: no screen` | Toggles the attached dashboard card on the focused monitor. |
| `open` | — | `ok` / `error: no screen` | Opens the card on the Dashboard tab. |
| `apps` | — | `ok` / `error: no screen` | Toggles the app launcher: opens on the Apps tab when closed, switches to Apps when open on another tab, closes when Apps is showing. |
| `close` | — | `ok` | Closes the card. |
| `settings` | `<section>` | `ok: <section>` / `error: no section <name>` / `error: no screen` | Opens the card on the Settings tab, deep-linked to a section. |

Valid `<section>` keys, from `SettingsService.sectionRegistry`: `calendar`,
`cava`, `dashboard`, `audio`, `fonts`, `layout`, `media`, `apps`, `monitors`,
`motion`, `notifications`, `theme`, `weather`. A name that is not one of these
is rejected with `error: no section <name>`; a name with characters outside
`a-z0-9-` is echoed back as `?`.

### `dnd`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `toggle` | — | `on` / `off` | Flips Do Not Disturb and reports the new state. |
| `on` | — | `on` | Turns Do Not Disturb on. |
| `off` | — | `off` | Turns Do Not Disturb off. |
| `status` | — | `on` / `off` | Reads the state without changing it. |

DND persists across restarts in the `notifications` state file under
`$XDG_STATE_HOME/quickshell/` (by default
`~/.local/state/quickshell/notifications`), and is restored on the next start.

### `volume`

| Function | Args | Returns | Notes |
| --- | --- | --- | --- |
| `up` | — | status | Steps the default output up by 5%. Never lowers the volume; caps at 100% unless it is already above. |
| `down` | — | status | Steps the default output down by 5%. |
| `set` | `<percent>` | status | Sets the default output to an integer percent, clamped to 0–100. |
| `mute` | — | status | Toggles mute. |
| `status` | — | status | Reads the default output without changing it. |

The status return is the current percent (for example `55`; it can exceed `100`
on an amplified output), `muted`, or `error: no sink` when there is no default
output. `up`, `down`, and `set` change the level only, never the mute state.
`up` and `down` step by `Globals.volumeStep` (5): `up` rounds up to the next
multiple of the step, `down` rounds down, and neither crosses 0 or, for a normal
output, 100.

### Other targets

- `theme` — the `qs-theme` CLI drives it (`refresh`, `list`, `current`, `set`,
  `background`); see `docs/user/qs-theme.md`.
- `devprobe` — an opt-in debugging surface; see
  `docs/dev/debugging-quickshell.md`.

## Placement

- `power`, `calendar`, and `notifications` open under their bar trigger on the
  primary monitor, the same anchor a click uses. The trigger module registers the
  anchor while it is visible, so a hidden module has nothing to open under: the
  toggle answers `error: ...` (`calendar`, `notifications`) or does nothing
  (`power`).
- `dashboard` opens on the Hyprland-focused monitor, falling back to the primary
  monitor, then to the first screen. `dashboard settings <section>` opens on the
  same monitor, deep-linked. `dashboard apps` uses the same monitor and is the
  intended Super keybind target.
- A toggle that would open a panel within about 300 ms of that panel closing from
  an outside click or an IPC `close` is ignored, so the close gesture does not
  immediately reopen it.

## Hyprland keybinds (Lua)

Add lines to `~/.config/hypr/modules/binds.lua` (or wherever your binds live),
then run `hyprctl reload`. Pick combos your config doesn't already use (`SUPER + C`
closes the active window in the default `binds.lua`):

```lua
hl.bind("SUPER + D", hl.dsp.exec_cmd("quickshell ipc call dashboard toggle"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("quickshell ipc call calendar toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("quickshell ipc call notifications toggle"))
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("quickshell ipc call dnd toggle"))
```

The volume OSD reacts to any writer, so media keys already bound to `wpctl`
show it too. Routing them through the `volume` target is optional; it gives the
shell's 5% snapping and never raises an amplified output further. To switch,
replace the existing `XF86Audio*` binds (don't add these alongside them):

```lua
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("quickshell ipc call volume up"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("quickshell ipc call volume down"), {
    locked = true,
    repeating = true
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("quickshell ipc call volume mute"), {
    locked = true,
    repeating = true
})
```

See `docs/adr/0017-volume-osd.md` for how the OSD decides when to show.
