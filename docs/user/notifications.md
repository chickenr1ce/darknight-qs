# Notifications

The shell is the notification server. It claims `org.freedesktop.Notifications`
on the session bus at startup (`services/NotificationServer.qml`), so
notification popups and the notification center are the shell's.

Only one process can own that bus name. Stop `mako` or `dunst` and disable its
autostart first, or the shell cannot claim the bus and notifications go to the
other daemon:

```sh
# whichever of these you run
pkill mako;   systemctl --user disable --now mako.service
pkill dunst;  systemctl --user disable --now dunst.service
```

`scripts/install.sh` checks the bus at install time and warns when another
daemon holds it.

Do Not Disturb suppresses popups while keeping the history in the center. Toggle
it from the center or the Settings → Notifications row. The `dnd` IPC target
(`status`, `on`, `off`, `toggle`) does the same from a keybind or script; the
notification and DND targets are listed in [IPC targets](ipc.md).
