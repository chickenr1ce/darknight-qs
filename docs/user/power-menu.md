# Power menu keybind

The power menu opens from the bar's power icon. To open it from the keyboard,
bind a Hyprland key to the shell's `power` IPC target:

```lua
hl.bind("SUPER + X", hl.dsp.exec_cmd("quickshell ipc call power toggle"))
```

Add the line to `~/.config/hypr/modules/binds.lua` (or wherever your Hyprland
binds live) and run `hyprctl reload`.

The panel opens under the bar's power icon, the same anchor the icon click
uses, so a keybind and a click place it identically. `quickshell ipc call
power close` closes it. The keybind does nothing while the power module is
hidden in the bar, since there is no icon to anchor under.

The power target is one of several; [IPC targets](ipc.md) covers the rest,
including the calendar, notifications, dashboard, Do Not Disturb, and volume
targets. The opt-in `devprobe` surface is documented separately in
`docs/dev/debugging-quickshell.md`.
