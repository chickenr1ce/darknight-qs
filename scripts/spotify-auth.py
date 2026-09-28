#!/usr/bin/env python3
"""One-time Spotify authorization for the dashboard Connect switch.

Runs the OAuth 2.0 Authorization Code flow with PKCE against a Spotify
Developer app you own. Everything happens on this machine: the browser
redirect lands on a loopback port this script listens on, the code is
exchanged for tokens, and the tokens are written to
~/.local/state/quickshell/spotify-auth.json (mode 600). The Connect backend
(scripts/spotify-connect.py) then refreshes from that file.

Setup, once:
  1. Create an app at https://developer.spotify.com/dashboard.
  2. In the app settings add the redirect URI printed below
     (default http://127.0.0.1:45173/spotify/callback; pass --redirect-uri to
     use another loopback port and register the same string).
  3. Run scripts/spotify-auth.py --client-id <your-client-id> and authorize in
     the browser it opens.

The client id is not a secret; this script ships neither a client id nor a
client secret. The token file is a password: keep it owner-only, never commit
it.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import http.server
import json
import os
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

ACCOUNTS_BASE_URL = "https://accounts.spotify.com"
DEFAULT_REDIRECT_URI = "http://127.0.0.1:45173/spotify/callback"
SCOPES = "user-read-playback-state user-modify-playback-state user-read-currently-playing"
CALLBACK_TIMEOUT_S = 180
TOKEN_TIMEOUT_S = 20


class SetupError(RuntimeError):
    """Authorization could not complete."""


def default_auth_file() -> str:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(base, "quickshell", "spotify-auth.json")


def code_verifier(length: int = 64) -> str:
    raw = base64.urlsafe_b64encode(os.urandom(length)).decode("ascii")
    return raw.rstrip("=")[:128]


def code_challenge(verifier: str) -> str:
    digest = hashlib.sha256(verifier.encode("utf-8")).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def validate_redirect_uri(uri: str) -> tuple[str, int, str]:
    parsed = urllib.parse.urlparse(uri)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"} or not parsed.port:
        raise SetupError(
            "redirect_uri must be an http loopback URL with an explicit port, "
            "e.g. http://127.0.0.1:45173/spotify/callback")
    return parsed.hostname, parsed.port, parsed.path or "/"


def build_authorize_url(client_id: str, redirect_uri: str, scope: str, state: str,
                        challenge: str, accounts_base: str = ACCOUNTS_BASE_URL) -> str:
    query = urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "scope": scope,
        "state": state,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
    })
    return accounts_base.rstrip("/") + "/authorize?" + query


def wait_for_callback(redirect_uri: str, expected_state: str, timeout: float) -> str:
    host, port, path = validate_redirect_uri(redirect_uri)
    result = {"code": None, "state": None, "error": None}
    done = threading.Event()

    class CallbackHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path != path:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not found")
                return
            params = urllib.parse.parse_qs(parsed.query)
            result["code"] = (params.get("code") or [None])[0]
            result["state"] = (params.get("state") or [None])[0]
            result["error"] = (params.get("error") or [None])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            message = ("Spotify authorization received. You can close this tab."
                       if not result["error"]
                       else "Spotify authorization failed. You can close this tab.")
            self.wfile.write(f"<html><body><h2>{message}</h2></body></html>".encode("utf-8"))
            done.set()

        def log_message(self, *args):  # noqa: D401, N802
            return

    class ReusableServer(http.server.HTTPServer):
        allow_reuse_address = True

    try:
        server = ReusableServer((host, port), CallbackHandler)
    except OSError as exc:
        raise SetupError(f"cannot bind {host}:{port} for the callback: {exc}") from exc

    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.1}, daemon=True)
    thread.start()
    try:
        if not done.wait(max(5.0, timeout)):
            raise SetupError("timed out waiting for the Spotify callback; run the script again")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=1.0)

    if result["error"]:
        raise SetupError(f"Spotify denied the authorization: {result['error']}")
    if result["state"] != expected_state:
        raise SetupError("Spotify callback state did not match; run the script again")
    if not result["code"]:
        raise SetupError("Spotify callback carried no code; run the script again")
    return result["code"]


def exchange_code(client_id: str, code: str, redirect_uri: str, verifier: str,
                  accounts_base: str = ACCOUNTS_BASE_URL) -> dict:
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "code_verifier": verifier,
    }).encode("utf-8")
    request = urllib.request.Request(
        accounts_base.rstrip("/") + "/api/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=TOKEN_TIMEOUT_S) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        raise SetupError("Spotify token exchange failed"
                         + (f": {detail}" if detail else "")) from exc
    except (OSError, ValueError) as exc:
        raise SetupError(f"Spotify token exchange failed: {exc}") from exc


def save_auth(path: str, state: dict) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        os.replace(tmp, path)
        os.chmod(path, 0o600)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Authorize Spotify once for the dashboard Connect switch.")
    parser.add_argument("--client-id", default=os.environ.get("SPOTIFY_CLIENT_ID") or "",
                        help="Spotify Developer app client id (or set SPOTIFY_CLIENT_ID)")
    parser.add_argument("--redirect-uri", default=DEFAULT_REDIRECT_URI,
                        help="loopback redirect URI registered on the app")
    parser.add_argument("--auth-file", default=default_auth_file())
    parser.add_argument("--no-browser", action="store_true", help="print the URL without opening a browser")
    parser.add_argument("--timeout", type=float, default=CALLBACK_TIMEOUT_S)
    parser.add_argument("--print-authorize-url", action="store_true",
                        help="print the authorize URL and exit without listening (tests)")
    parser.add_argument("--code-verifier", default=None, help="override the PKCE verifier (tests)")
    parser.add_argument("--state", default=None, help="override the OAuth state (tests)")
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    client_id = args.client_id.strip()
    if client_id == "":
        print("error: --client-id is required (or set SPOTIFY_CLIENT_ID); create an app at "
              "https://developer.spotify.com/dashboard", file=sys.stderr)
        return 2
    try:
        validate_redirect_uri(args.redirect_uri)
    except SetupError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    verifier = args.code_verifier or code_verifier()
    challenge = code_challenge(verifier)
    oauth_state = args.state or secrets.token_urlsafe(24)
    url = build_authorize_url(client_id, args.redirect_uri, SCOPES, oauth_state, challenge)
    if args.print_authorize_url:
        print(url)
        return 0

    print(f"Register this exact redirect URI on your Spotify app:\n  {args.redirect_uri}")
    print(f"Authorize here:\n  {url}")
    if not args.no_browser:
        try:
            webbrowser.open(url)
        except Exception:  # noqa: BLE001 - a headless session just uses the printed URL
            pass

    try:
        code = wait_for_callback(args.redirect_uri, oauth_state, timeout=args.timeout)
        tokens = exchange_code(client_id, code, args.redirect_uri, verifier)
    except SetupError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    access = str(tokens.get("access_token") or "")
    refresh = str(tokens.get("refresh_token") or "")
    if access == "" or refresh == "":
        print("error: Spotify token response was missing an access or refresh token", file=sys.stderr)
        return 1
    now = time.time()
    try:
        expires_in = float(tokens.get("expires_in") or 3600)
    except (TypeError, ValueError):
        expires_in = 3600.0
    save_auth(args.auth_file, {
        "client_id": client_id,
        "redirect_uri": args.redirect_uri,
        "scope": str(tokens.get("scope") or SCOPES),
        "token_type": str(tokens.get("token_type") or "Bearer"),
        "access_token": access,
        "refresh_token": refresh,
        "obtained_at": now,
        "expires_at": now + expires_in,
        "accounts_base_url": ACCOUNTS_BASE_URL,
    })
    print(f"Saved Spotify token to {args.auth_file} (mode 600).")
    print("The dashboard Connect switch is ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
