# ADR 0009: Spotify Connect uses a shell-owned PKCE token

Date: 2026-09-28. Feature: dashboard-spotify (`#01`, `#02`).

## Context

The dashboard player block shipped with two placeholders: a flat cover-art
rectangle and a fixed Phone/PC device list. Finishing the device switch means
moving the Connect session between devices, which only the Spotify Web API can
do (`GET /me/player/devices`, `PUT /me/player`). That needs an OAuth token with
`user-read-playback-state` and `user-modify-playback-state`.

A working token already existed on this machine, minted by another application
under a client id baked into that application (not the user's). Reusing it
would work today but couples the shell to a third-party app registration: delete
that application, or have its credentials rotated, and the switch dies. The
user chose a dedicated app instead.

## Decision

The shell owns its Spotify credential, end to end.

- `scripts/spotify-auth.py` runs the Authorization Code flow with PKCE against a
  Spotify Developer app the user creates. The redirect is a loopback URL
  (`http://127.0.0.1:45173/spotify/callback` by default), the flow listens for
  the callback locally, and the resulting tokens are written owner-only. The
  repo ships no client id and no secret.
- The token lives at
  `${XDG_STATE_HOME:-~/.local/state}/quickshell/spotify-auth.json`, mode 600,
  alongside the calendar secret. `scripts/spotify-auth.py` writes it;
  `scripts/spotify-connect.py` refreshes it in place when the access token is
  within 60s of expiry and persists a rotated refresh token if one comes back.
  It is a password: never committed, warned about when group/other-readable.
- `scripts/spotify-connect.py` is the only thing that touches the token or the
  network. It prints exactly one JSON object per call and sets an exit code:
  0 success, 1 network or API failure, 2 local setup problem. The shape mirrors
  `scripts/calendar-fetch.py`.
- `services/SpotifyService.qml` owns the device list (`devices`,
  `activeDeviceId`, `authMissing`, `lastError`) and exposes `refreshDevices()`
  plus `transferTo(deviceId)`. It polls every 10s only while the dashboard is
  open. QML never sees a token or a URL.
- The player block renders one chip per device, highlights the active one,
  leaves restricted devices inert, and transfers on click. A missing token
  clears the list and hides the row rather than breaking the block.
- Cover art binds `MprisPlayer.trackArtUrl` through a `ClippingRectangle` so the
  art clips to the card radius; the flat fill is the empty/loading state.

Transfer sends `play: true`: it moves the session to the chosen device and
resumes there, matching how Connect hands off between devices. A `play: false`
transfer does not reliably wake the desktop client, so the switch always asks
for playback.

## Alternatives considered

- **Reuse the token already on the machine.** Fastest, but it is another app's
  registration; the shell would break when that app or its credentials go away.
  Rejected by the user in favour of ownership.
- **Client Credentials flow.** Spotify issues app-only tokens with no user
  playback scopes, so it cannot list or move a Connect session. Not viable.
- **Select among MPRIS players instead of real Connect devices.** The official
  Linux client exposes one MPRIS player regardless of Connect devices, so this
  is not a device switch at all.
- **Shell out to a Spotify TUI (`spotify_player`, `ncspot`).** Neither is
  installed, and neither offers a device-transfer command the block could call.
- **Put OAuth in QML (`XMLHttpRequest`/`Process`).** Puts token handling and
  refresh into presentation code and re-implements the calendar backend's proven
  split. Rejected for the same reason ADR 0002 kept network out of QML.

## Consequences and known limits

- The user must create a Spotify app and authorize once. Setup is documented in
  `docs/spotify-connect.md`; until then `authMissing` is true and the device row
  is hidden.
- Spotify's PKCE refresh does not rotate the refresh token in this flow
  (verified live 2026-09-28), so the stored token is long-lived and refresh
  rewrites only the access token.
- The switch needs a Spotify Premium account: playback control returns 403
  without it. `SpotifyService.lastError` carries the backend message and the
  failure is logged; the block does not surface a toast.
- A device list is per-account, not per-machine, so a second instance sees the
  same devices. Polling is capped at 10s while the dashboard is open, well
  inside Spotify's rate limits.
- Live verification of a true two-device transfer needs a second Connect device
  (e.g. the phone); the backend path and single-device list were verified
  against the live API.
