# Polkit authentication

Privileged actions go through polkit: `pkexec`, service control through systemd,
mounting disks, and apps that ask to reconfigure the system. Polkit decides
whether the action is allowed, then hands the password prompt to a *polkit
authentication agent*, a process running as you. The shell registers its own
agent at startup, so that prompt is the shell's dialog. No separate agent
package is needed.

## What the shell does

- Registers one agent for the whole session when the shell starts. The agent
  lives in the shell process (`services/PolkitService.qml`), not in the dialog
  window, so the shell registers it before a request can arrive.
- Shows the prompt in its own dialog (`windows/PolkitDialog.qml`). The dialog
  names the action, the identity authenticating, the PAM prompt or message, and
  the key hints. When polkit offers more than one identity, the dialog can
  switch between them.
- Cancels the request on Esc, so an abandoned conversation does not linger.
  Clicking outside the dialog no longer cancels; only Esc does.

| Key | Action |
| --- | --- |
| Enter or Return | submit the password |
| Esc | cancel the request |
| Tab | switch to the next identity, when polkit offers more than one |

## The shell must be the only agent

More than one registered agent is the usual cause of a prompt that never
appears, a prompt from the wrong program, or authentication that fails after an
update. Unless you have a reason to run another agent, let the shell be the only
one and remove the others from your session.

Stop and disable the common ones:

```sh
# hyprpolkitagent: systemd user unit, also D-Bus activated
systemctl --user disable --now hyprpolkitagent.service

# polkit-kde-agent: KDE autostart and a static user unit
systemctl --user mask plasma-polkit-agent.service
```

The KDE agent's autostart entry,
`/etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop`, sets
`OnlyShowIn=KDE`, so it does not start under Hyprland. Masking the unit covers a
manual start. A GTK agent such as `polkit-gnome` or `lxqt-policykit` starts from
its own autostart entry or an `exec-once` line. Remove that line.

If your Hyprland config still launches an agent, delete the line. The old
`.conf` layout used:

```
exec-once = systemctl --user start hyprpolkitagent
```

An installed but disabled agent does not register. Only a running one does.
Check what is running:

```sh
pgrep -af 'polkit.*agent'                          # any agent process
systemctl --user is-enabled hyprpolkitagent.service
```

`/usr/lib/polkit-1/polkitd` is the daemon, not an agent, and
`polkit-agent-helper@.service` is part of polkitd's PAM flow. Leave both alone.

The shell has no agent while it is stopped or restarting, so a `pkexec` in that
window fails. Start the shell again and it re-registers. `scripts/restart.sh`
keeps that window clean: it refuses to start a second instance until the old one
has exited, and fails loudly if the new agent cannot register ("An
authentication agent already exists").

## Check that it works

Trigger a prompt and confirm you get the shell's dialog, the dark slab with the
action in the footer:

```sh
pkexec /bin/true
```

Enter your password. The command exits silently on success. If a foreign dialog
appears, another agent is still registered. If nothing appears and `pkexec`
reports "Not authorized", check that the shell is running with
`pgrep -x quickshell`, then read the run's log, covered in
`docs/dev/debugging-quickshell.md`.

### Lockouts while testing

Every cancel (Esc) or wrong password records a `polkit-1` failure with PAM
`faillock`; three in a row lock the account, and a locked account rejects `sudo`
too because `pam_faillock` blocks before `pam_unix`. This is the PAM stack's
policy, not the shell's: the agent cannot stop a cancel from counting. Reset the
tally between `pkexec /bin/true` attempts:

```sh
faillock --user "$USER" --reset
```

The tally file is owned by your user, so the reset needs no `sudo`. To make
testing less punishing, edit `/etc/security/faillock.conf` as root and raise
`deny` or lower `unlock_time`; this is optional and changes lockout behavior
system-wide:

```
deny = 10
unlock_time = 60
```

## Troubleshooting

- **No prompt at all.** The shell is not running, or its agent did not register.
  Confirm the Quickshell build has the module at
  `/usr/lib/qt6/qml/Quickshell/Services/Polkit`, then restart the shell and try
  once more.
- **The wrong dialog appears.** Another agent is registered. Stop it with the
  commands above so the shell is the only one.
- **The account is locked out.** Cancelled and failed attempts add a PAM
  `faillock` entry — the `polkit-1` entries come from cancelled or failed polkit
  prompts. `faillock --user "$USER"` lists them, and
  `faillock --user "$USER" --reset` clears the count; the tally file is owned by
  your user, so no `sudo` (which is blocked while locked) is needed. Otherwise
  wait out the system's `unlock_time`, 10 minutes by default.
- **A stuck helper.** A dialog that is neither submitted nor cancelled can leave
  a `polkit-agent-helper@*` unit behind. Cancel the request with Esc, then clear
  a stuck unit with `sudo systemctl stop 'polkit-agent-helper@*'`.