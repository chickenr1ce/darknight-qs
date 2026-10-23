# ADR 0022: the lock screen is the shell's own session lock, not hyprlock

Date: 2026-10-23. Feature: lock-screen.

## Context

The chosen lock design is the "Ambient" card in
`docs/plans/15-lock-screen-ambient.html`: the active theme's wallpaper blurred
behind a scrim, a chip with the clock at the top, a big clock in the centre, an
unlock card that only appears once the user starts typing, a now-playing card at
the bottom, and a power card under the power button. Unlock is a PAM password
check that reports PAM's own messages, the attempt count, and a failure shake.

hyprlock can draw labels, shapes, images, and an input field, and its `cmd[]`
labels poll shell commands. It cannot hide the unlock card until a key is
pressed, cannot host the shell's power card with its arm/confirm state, and
cannot read the shell's Mpris, theme, and volume state live. Porting the design
would mean re-implementing the shell's components and services in a second
configuration language, with a one-second polling ceiling.

Quickshell 0.3.2 ships both pieces the design needs: `WlSessionLock` /
`WlSessionLockSurface` implement `ext_session_lock_v1` per screen, and
`PamContext` authenticates through libpam in a forked subprocess (no
`pamtester`). The shell already owns the palette, motion, MPRIS, and PipeWire
state the design reads.

The cost is crash exposure. A compositor holds a session lock until the client
sets `locked` false. If the shell dies while locked, the session stays locked
and Hyprland paints its lock-dead screen. hyprlock can recover the session only
when the compositor allows a replacement locker, which is off by default.

## Decision

The lock screen is a `WlSessionLock` in `shell.qml`, bound one-way to
`LockService.locked`, with one `WlSessionLockSurface` per screen hosting
`windows/LockSurface.qml`.

- **The session starts unlocked.** `LockService.locked` defaults to false, and
  only an explicit `lock lock` IPC call or the bar power menu's Lock sets it
  true. Booting the shell never locks, so `boot-check.sh`, `capture.sh`, and a
  reload cannot strand the session. The dev preview is a separate overlay
  `PanelWindow` hosting the same surface with auth stubbed; it never sets
  `locked`, and its IPC is gated on `QUICKSHELL_DEV_PROBE`.
- **PAM uses the system `login` stack.** `PamContext` runs the `auth` lines of
  `/etc/pam.d/login` (the system-local-login chain, including `pam_faillock`),
  so the password check matches a console login and the shell adds no
  root-owned PAM file outside the repository. The password lives in the service
  only until `respond()` is called and is cleared on completion. PAM info and
  error messages are shown; a failure is styled as an error, an informational
  notice is not. The unlock card shows `Wrong password` (plus the attempt count
  after the first) when PAM fails without a message.
- **The design's absolute pixel values scale with the screen.** The prototype's
  stage is 1600×900; `LockSurface` derives a scale from `Globals.lockBaseHeight`
  and every lock token is multiplied by it, so the composition keeps the
  design's proportions on the 2560×1440 panel and on a smaller monitor. Shared
  cards take the same scale through `Card` padding and `PowerActionRow`'s
  `layoutScale`, with a default of 1 for their shell panels.
- **The lock power card is the safe subset of the power menu.** It filters
  `PowerLogic.actions()` to Suspend, Reboot, and Shutdown and reuses
  `PowerLogic.press/confirm` and the argv strings, so no command is duplicated.
  Lock is the current state; Logout would end the session without
  authentication; Reboot to Windows runs `pkexec`, and the polkit agent
  (ADR 0015) cannot draw over a session lock. While the card is open it owns
  the keyboard: 1–3 arm, Enter confirms, Escape disarms then closes, and a
  click outside closes.
- **The bar power menu delegates Lock.** `PowerLogic.press(state, "lock")` now
  returns `{ run: null, lock: true }`, and `PowerService` calls
  `LockService.lock()` instead of spawning hyprlock. `PowerLogic` stays pure and
  the existing node tests cover the flag.
- **hyprlock stays installed as the recovery locker.** Its theme target and
  rendered colors are untouched; it is no longer the normal lock path.

## Alternatives considered

- **hyprlock with the Ambient design ported.** Rejected: the type-to-reveal
  card, the live media card, and the arm/confirm power card are not expressible
  in hyprlock's label/shape/input vocabulary, and polling `cmd[]` labels once a
  second would not track the theme, volume, or playback state the design shows.
- **A custom `quickshell` PAM config.** The PAM module documentation recommends
  one when the flow differs from login. This flow is login's flow, and a custom
  file would have to be installed under `/etc/pam.d` outside the repository;
  the `login` stack is the zero-setup choice. A custom config remains the
  extension point for fingerprint or a password-plus-fingerprint stack.
- **Lock from hypridle by running hyprlock.** Rejected as the default: it keeps
  two lock experiences. hypridle can instead run
  `quickshell ipc call lock lock` (documented in `docs/user/lock.md`).
- **Winboot in the lock power card.** Deferred: `pkexec` starts the polkit
  agent, which is a layer surface the compositor will not draw above a session
  lock, so the confirm would hang with no prompt. Dropping the row is the
  honest option until a polkit rule allows `efibootmgr` without a prompt.
- **A lock keybind in the shell.** The session lock owns the keyboard once
  locked, so a Hyprland bind is the right place to start it; the user page shows
  the bind and the hypridle command.

## Consequences

- The lock screen uses the shell's palette, fonts, motion tokens, MPRIS player,
  PipeWire volume, and theme background with no second configuration surface.
- A shell crash while locked leaves the session locked. `hyprlock` is the
  recovery client, and `misc.allow_session_lock_restore` must be enabled in the
  Hyprland config before relying on the native lock: with it off, the
  compositor refuses a replacement locker and the session can only be ended.
  `docs/user/lock.md` carries the TTY recovery steps.
- The bar's power menu Lock now locks through IPC, so it works without hyprlock
  and without the compositor's locker chain.
- The unlock card's reveal, message, attempt, and key rules live in
  `services/LockLogic.js` and run under node in `scripts/test-lock.sh`; the
  session lock itself is never exercised by the gate.
- `WlSessionLock` and `WlSessionLockSurface` are session-wide, so a throwaway
  instance must never lock. The preview surface exists for visual work; live
  lock testing is a deliberate manual step on a session the user can recover.
