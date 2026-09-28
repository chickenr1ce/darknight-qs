# Spotify Connect setup

The dashboard player block lists your Spotify Connect devices and moves the
session between them. It talks to the Spotify Web API with a token the shell
owns. Nothing works until you authorize once.

## 1. Create a Spotify app

1. Open <https://developer.spotify.com/dashboard> and create an app (any name).
2. In the app's settings, add this exact redirect URI:
   `http://127.0.0.1:45173/spotify/callback`
   (pass `--redirect-uri` to `spotify-auth.py` and register that string if the
   port is taken.)
3. Copy the app's **Client ID**. It is not a secret; the client secret is never
   used.

## 2. Authorize once

```fish
python3 ~/.config/quickshell/scripts/spotify-auth.py --client-id <your-client-id>
```

The script opens the authorization page and waits on the loopback port. After
you approve, it writes
`${XDG_STATE_HOME:-~/.local/state}/quickshell/spotify-auth.json` with mode 600.
Keep that file owner-only; it is a password.

The app can stay in development mode: you are the only user, and playback
scopes do not need app review for personal use.

## 3. Use it

Open the dashboard. The player block shows one chip per Connect device with the
active device highlighted. Click another device to move the session there.

## Re-authorize

Tokens survive restarts and refresh in place. If Spotify rejects the refresh
(password change, app deleted, scopes revoked), run step 2 again; it overwrites
the token file.

## Verify without the UI

```fish
python3 ~/.config/quickshell/scripts/spotify-connect.py devices
python3 ~/.config/quickshell/scripts/spotify-connect.py transfer --device-id <id>
```

Both print one JSON object. Exit 0 is success, 1 is a network or API failure,
2 is a missing or unreadable token file.
