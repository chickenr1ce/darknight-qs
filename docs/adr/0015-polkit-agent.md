# ADR 0015: the polkit agent is a native Quickshell dialog

Date: 2026-10-06. Feature: polkit-agent (`#01`).

## Context

Privileged authentication (pkexec, systemd, mounting disks) is handled by a
polkit authentication agent: a long-lived process that registers with polkitd
over D-Bus and shows a password prompt when an action needs authorization.

The shell used `hyprpolkitagent`, which broke on 2026-08-23 when a Qt 6.11.2
update removed a private API its QML style plugin linked, so the dialog failed
to load and every pkexec returned "Not authorized" (see
`docs/incidents/polkit-agent-incident.md`). It was worked around with
`polkit-kde-agent`, which is stable but renders a KDE surface with none of the
shell's design language and pulls a KDE dependency for one dialog.

Quickshell 0.3.1 ships `Quickshell.Services.Polkit` (`PolkitAgent` +
`AuthFlow`), which owns the D-Bus registration, the PAM conversation, identity
selection, and cancellation. Only the dialog UI has to be written.

## Decision

The agent is a native Quickshell window, not an external agent.

- `services/PolkitService.qml` is a singleton that owns one `PolkitAgent` and
  exposes `isActive`, `flow`, `identities`, `identityName`,
  `hasMultipleIdentities`, `submit(value)`, `cancel()`, `cycleIdentity()`. The
  agent has to outlive any dialog, so it lives in the singleton and registers
  once per shell session.
- `windows/PolkitDialog.qml` is a `PanelWindow` on `WlrLayer.Overlay` with
  `WlrKeyboardFocus.Exclusive`, visible only while `PolkitService.isActive`, and
  instantiated once in `shell.qml`.
- The dialog is the B2 "Context Runner" direction
  (`docs/plans/archive/08-polkit-agent-designs.html`): a 520px three-tier slab —
  a mono meta line, an input row with an inline Unlock pill, and an accelerator
  footer — separated by 1px hairlines.
- PAM's `supplementaryMessage` can be an error *or* an informational message (a
  faillock lockout notice), so the message row shows when
  `supplementaryMessage !== "" || failed`, styled as an error only when
  `supplementaryIsError || failed`.
- The error row shakes on failure with the design's 280ms keyframe sequence,
  gated by `Globals.reducedMotion`.
- Enter submits, Esc cancels, Tab cycles identities, a scrim click cancels.

## Alternatives considered

- **Keep `hyprpolkitagent`.** The upstream rebuild fixed the immediate break, but
  the package links Qt private API, so any Qt bump can break auth again, and its
  generic style cannot adopt the shell's palette or tokens; rejected.
- **Keep `polkit-kde-agent`.** Stable, but a foreign KDE surface and dependency;
  rejected for a shell that deliberately unifies one visual vocabulary.
- **A GTK agent (`polkit-gnome`, `lxqt-policykit`).** Same off-style problem;
  rejected.

## Consequences

- Auth UI inherits the shell's theme (palette, radii, fonts, reduced motion) and
  no external agent package is needed.
- The agent lives in the shell process: a shell restart briefly unregisters it
  until the shell is back. The shell must be the only registered agent, so
  `polkit-kde-agent` is removed from the Hyprland autostart.
- The Qt-private-API failure class cannot recur here: `Quickshell.Services.Polkit`
  uses public APIs, and the shell tracks the framework.
- On a lockout, the dialog surfaces the PAM notice instead of failing silently.
