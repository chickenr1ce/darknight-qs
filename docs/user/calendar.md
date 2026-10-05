# Calendar setup

The calendar panel reads Google Calendar secret iCal URLs. There is no settings
field for them yet, so you write the URL file once. Each URL is a bearer token:
keep the file owner-only and never commit it. The panel keeps working offline
from the last good cache.

## Add your calendar URLs

The URL file lives in the XDG state directory. One URL per non-blank line; a
single URL also works.

```fish
mkdir -p ~/.local/state/quickshell
printf '%s\n' '<primary-url>' '<holidays-url>' > ~/.local/state/quickshell/calendar-url
chmod 600 ~/.local/state/quickshell/calendar-url
```

If you set `XDG_STATE_HOME`, substitute it for `~/.local/state`. On bash or POSIX
`sh`, the same, with `$HOME` in place of `~`:

```sh
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
printf '%s\n' '<primary-url>' '<holidays-url>' > "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/calendar-url"
chmod 600 "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/calendar-url"
```

`bash` does not expand `~` inside `${...}`, which is why the POSIX form uses
`$HOME`.

## Get the URLs from Google Calendar

In Google Calendar on the web, open **Settings for my calendars**, pick a
calendar, go to **Integrate calendar**, and copy the **Secret address in iCal
format**. Repeat for holidays or any other calendar with its own secret address.
The panel merges every feed in the file into one event cache.

Because the secret address is a bearer token, treat it like a password. Rotate
it from Google's **Reset** control for that calendar, then rewrite the URL file
with the new value.

## Multi-calendar and birthdays (gcalcli)

The Contacts birthdays calendar has no secret iCal address, so the URL file can
never see it. Install `gcalcli` and follow the Tier 2 steps in the
[`scripts/calendar-fetch.py`](../../scripts/calendar-fetch.py) docstring to
unlock birthdays and per-calendar toggles: `gcalcli` polls each discovered
calendar separately and records every name, and the calendar panel's settings
can hide a noisy feed. That path needs your own Cloud project and a one-time
OAuth grant, so the trust decision is yours.
