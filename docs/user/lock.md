# Lock screen

The shell ships its own lock screen: the active theme's wallpaper blurred behind
a scrim, the clock in the centre, an unlock card that appears once you start
typing, a now-playing card at the bottom, and a power card under the power
button. It locks every monitor.

## Locking

From a terminal or a keybind:

```sh
quickshell ipc call lock lock
```

The bar's power menu (the power glyph at the right of the bar) also locks: pick
**Lock** and it fires at once, without a confirm. The bar panel closes first.

A Hyprland keybind is the quickest manual lock:

```lua
hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc call lock lock"))
```

Add it to `~/.config/hypr/modules/binds.lua` and run `hyprctl reload`.

For idle locking, point hypridle's `lock_cmd` at the same call
(`~/.config/hypr/hypridle.conf`):

```conf
general {
    lock_cmd = quickshell ipc call lock lock
}
```

The lock screen and hypridle are independent: any command that reaches the
shell's `lock` target locks it.

## Unlocking

Start typing anywhere on the lock screen. The unlock card fades in with the
password field focused. Enter checks the password, Escape clears the field, and
the card hides again after six seconds without input while the field is empty.
Caps Lock is flagged when the keyboard reports it.

`lock status` prints the current state as JSON (`locked`, `authState`,
`attempts`, `powerOpen`, and the preview fields), which is useful when a script
needs to know whether the session is locked:

```sh
quickshell ipc call lock status
```

## Password check

Unlock authenticates through `PAM` with the system `login` configuration
(`/etc/pam.d/login`), the same `auth` stack as a console login, including
`pam_faillock`. The password is handed to PAM and dropped; it is not written
anywhere. PAM notices such as a faillock lockout are shown in the card, and a
failed attempt shakes the field and counts the attempts after the first.

One attempt answers exactly one PAM prompt, and the `login` stack asks for the
password once. If PAM asks for a second response, as an account that needs a
second factor does, the attempt fails with `Unsupported authentication prompt`
and the conversation is aborted. The card has no second secret to send, and
answering an empty string would hide the real reason.

Fingerprint unlock would need a custom PAM config (`auth sufficient
pam_fprintd.so` before `pam_unix.so`) and a change to `LockService`; the
shipped screen is password-only.

## Power card

The power button at the top right, or `Ctrl+P`, opens the power card under the
button. It offers Suspend (1), Reboot (2), and Shutdown (3). A digit arms an
action, Enter confirms it, Escape disarms and then closes the card, and a click
outside closes it. While the card is open the password field is disabled and
the digits go to the card.

Lock is not listed: you are already locked. Logout is not listed: it would end
the session without authentication. Reboot to Windows is not listed: it needs
`pkexec`, and the polkit prompt cannot be drawn over a session lock.

## Recovery if the shell dies while locked

The lock is a Wayland session lock: the compositor keeps the screen covered
until the locker unlocks it or dies with the compositor. If the shell crashes
while locked, the session stays locked and Hyprland shows its lock-dead screen.
hyprlock is still installed for this case.

Enable `misc:allow_session_lock_restore` in the Hyprland config **before** this
happens, so the compositor accepts a replacement locker. With the Lua config:

```lua
hl.config({ misc = { allow_session_lock_restore = true } })
```

Then, from a TTY (switch with `Ctrl+Alt+F2`), start hyprlock against the live
session:

```sh
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-1   # ls "$XDG_RUNTIME_DIR" for the live socket
hyprlock
```

Log in through hyprlock to unlock the session, then start the shell again. If
the option was off when the crash happened, the compositor refuses the new
locker; the remaining way out is to end the session (restart the compositor
from the TTY, or reboot).

The same lock applies to a shell reload: `scripts/reload.sh` keeps the process,
but a crash or a `restart.sh` that stops the shell while locked follows this
recovery path. Lock deliberately, not while testing a reload.

## Development preview

The visual surface can be inspected without locking anything.
`scripts/capture.sh` boots a throwaway instance with `QUICKSHELL_DEV_PROBE=1`;
in that instance `lock preview` toggles a full-screen overlay on the first
screen and `lock previewState <idle|typing|checking|failed|power>` opens it in
that state. Auth is stubbed there; the preview never locks.

```sh
scripts/capture.sh . lock.preview -- lock previewState typing
```

The preview IPC is gated on `QUICKSHELL_DEV_PROBE`, so the daily shell ignores
it. `scripts/capture.sh` boots its own throwaway instance, which is the safe
way to take a picture of the surface; a throwaway instance that sets the
session lock locks the real desktop.
