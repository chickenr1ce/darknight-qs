# Polkit Agent Incident – 2026-08-23

**Symptom:** `btrfs-assistant-launcher` (as normal user) failed with pkexec
"Not authorized"; even `pkexec /bin/true` failed for uid 1000.

**Status:** Worked around with `polkit-kde-agent`. Revert to `hyprpolkitagent`
once upstream fix lands (see *Revert conditions*).

---

## Diagnosis chain

1. **Wrong launch method (user error, fixed):**
   - ❌ `sudo btrfs-assistant-launcher` → stripped Wayland/X env → Qt xcb crash
     (`could not connect to display :0`). The accompanying `libxcb-cursor0`
     warning was a **red herring** (`xcb-util-cursor` was installed).
   - ✅ `btrfs-assistant-launcher` **as normal user**: the script escalates via
     `pkexec` itself and passes `--display=/run/user/1000/wayland-1`.

2. **pkexec "Not authorized" despite rules:** user is in `wheel` + `empower`;
   `/usr/share/polkit-1/rules.d/empower.rules` should auto-YES → rules were not
   the problem.

3. **Root cause:** `hyprpolkitagent`'s password dialog fails to load.
   `journalctl -b _PID=2161`:

   ```
   Cannot load library /usr/lib/qt6/qml/org/hyprland/style/impl/libhyprland-quick-style-implplugin.so:
   /usr/lib/libhyprland-quick-style-impl.so: undefined symbol:
   _ZN23QUntypedPropertyBindingC1EP23QPropertyBindingPrivate, version Qt_6_PRIVATE_API
   ```

   `hyprland-qt-support 0.1.0-13.1` (CachyOS rebuild) links the Qt **private**
   API, broken by `qt6-base 6.11.2-2.1`. Auth aborts instantly → "Not authorized".
   Upstream bug (open): [hyprwm/hyprland-qt-support#13 – "libhyprland-quick-style-impl.so
   fails with undefined symbol after Qt6 update"](https://github.com/hyprwm/hyprland-qt-support/issues/13)
   (opened 2026-08-20; identical symbol error reported there).

## Fix applied

```sh
sudo pacman -S polkit-kde-agent
pkill hyprpolkitagent
/usr/lib/polkit-kde-authentication-agent-1 &   # verified: "Listener online"
sudo systemctl stop 'polkit-agent-helper@*'    # clear hung auth conversation
```

Hyprland autostart updated accordingly:
`~/.config/hypr/modules/autostart.lua` now execs
`/usr/lib/polkit-kde-authentication-agent-1` instead of `hyprpolkitagent`.

Startup log noise `qt.qpa.services: Failed to register with host portal …
Unable to open /proc/<pid>/root` is **cosmetic** portal registration failure,
unrelated to authentication.

## Gotchas

- Never launch btrfs-assistant with `sudo`; use the launcher's built-in pkexec
  path.
- The `libxcb-cursor0` Qt message appears whenever the xcb QPA plugin fails for
  *any* reason — don't chase it.
- User is in `empower` and `nopasswdlogin` groups → blanket passwordless polkit
  escalation once an agent works (security note, user's choice).
  If `pkexec /bin/true` still prompts with a working agent, `empower.rules`
  isn't matching as assumed — investigate separately.
- Earlier "successful" pkexec journal entries were root-invoked (sudo path);
  not evidence of working user-side auth.

## Revert conditions

Watch [upstream issue #13](https://github.com/hyprwm/hyprland-qt-support/issues/13) /
CachyOS rebuilding `hyprland-qt-support` against a
fixed Qt. Then: reinstall/enable `hyprpolkitagent`, remove the KDE agent from
autostart.

## Long-term: custom Quickshell agent

Quickshell ships `Quickshell.Services.Polkit` (`PolkitAgent` + `AuthFlow`) since
Oct 2025 — it handles D-Bus registration, PAM conversation and cancellation;
only the dialog UI must be written (~100–200 lines QML). This uses public APIs,
so it is immune to the private-API breakage class above. Reference
implementations: caelestia-shell (`modules/polkit/`), end-4/dots-hyprland
(`modules/ii/polkit/`), zesis (`Widgets/Polkit/`).

Plan: verify `ls /usr/lib/qt6/qml/Quickshell/Services/ | grep -i polkit`, build
it after the waybar→quickshell migration settles, then drop the KDE agent from
autostart. Keep cancel-on-Esc/focus-loss correct — a wedged dialog leaves hung
`polkit-agent-helper@*` units behind (observed during this incident).
