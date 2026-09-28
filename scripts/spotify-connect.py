#!/usr/bin/env python3
"""Spotify Connect device control for the dashboard player block.

Backend for services/SpotifyService.qml. Reads the PKCE token written by
scripts/spotify-auth.py, refreshes the access token when it is near expiry,
and makes the two Web API calls the block needs: list Connect devices and
transfer playback to one of them.

Each subcommand prints exactly one JSON object on stdout and sets the exit
code: 0 success, 1 network or API failure, 2 local setup problem (missing or
unreadable token file). QML reads the JSON and never sees a token.

The token file is a password: keep it owner-only, never commit it. This
script ships no client id and no secret; the user authorizes their own
Spotify app once with scripts/spotify-auth.py.

Usage:
  spotify-connect.py devices [--auth-file PATH] [--devices-input FILE]
  spotify-connect.py transfer --device-id ID [--auth-file PATH] [--play]
                             [--print-request]
"""

from __future__ import annotations

import argparse
import json
import os
import stat
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE_URL = "https://api.spotify.com/v1"
ACCOUNTS_BASE_URL = "https://accounts.spotify.com"
REQUEST_TIMEOUT_S = 20
REFRESH_SKEW_S = 60


class SetupError(RuntimeError):
    """The local token file is missing, unreadable, or incomplete."""


def default_auth_file() -> str:
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(base, "quickshell", "spotify-auth.json")


def warn_world_readable(path: str) -> None:
    try:
        if os.stat(path).st_mode & (stat.S_IRGRP | stat.S_IROTH):
            print(f"warning: {path} is readable beyond owner; run chmod 600 {path}",
                  file=sys.stderr)
    except OSError:
        pass


def load_auth(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            state = json.load(handle)
    except FileNotFoundError as exc:
        raise SetupError(
            f"no Spotify token at {path}; run scripts/spotify-auth.py once") from exc
    except (OSError, ValueError) as exc:
        raise SetupError(f"cannot read Spotify token at {path}: {exc}") from exc
    if not isinstance(state, dict):
        raise SetupError(f"Spotify token at {path} is not a JSON object")
    warn_world_readable(path)
    return state


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


def http_request(method: str, url: str, *, token: str | None = None,
                 body: dict | None = None,
                 timeout: float = REQUEST_TIMEOUT_S) -> tuple[int, bytes]:
    data = None
    headers = {}
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token is not None:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def build_devices_url(api_base: str) -> str:
    return api_base.rstrip("/") + "/me/player/devices"


def build_transfer_request(api_base: str, device_id: str, play: bool = False) -> dict:
    return {
        "method": "PUT",
        "url": api_base.rstrip("/") + "/me/player",
        "body": {"device_ids": [device_id], "play": bool(play)},
    }


def parse_devices(payload) -> dict:
    devices = []
    raw = payload.get("devices") if isinstance(payload, dict) else None
    if not isinstance(raw, list):
        raw = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        device_id = str(item.get("id") or "").strip()
        name = str(item.get("name") or "").strip()
        if device_id == "" or name == "":
            continue
        try:
            volume = int(item.get("volume_percent"))
        except (TypeError, ValueError):
            volume = -1
        devices.append({
            "id": device_id,
            "name": name,
            "type": str(item.get("type") or "").strip(),
            "isActive": bool(item.get("is_active")),
            "isRestricted": bool(item.get("is_restricted")),
            "volumePercent": volume,
        })
    active_id = next((device["id"] for device in devices if device["isActive"]), "")
    return {"devices": devices, "activeId": active_id}


def api_error_message(status: int, body: bytes) -> str:
    detail = ""
    try:
        payload = json.loads(body or b"{}")
    except ValueError:
        payload = None
    if isinstance(payload, dict):
        error = payload.get("error")
        if isinstance(error, dict):
            detail = str(error.get("message") or "")
        elif isinstance(error, str):
            detail = error
    if detail:
        return detail
    if status == 403:
        return "Spotify rejected the request; Premium or a fresh scripts/spotify-auth.py may be needed"
    if status == 404:
        return "Spotify found no active playback session"
    if status == 429:
        return "Spotify rate limit hit; try again shortly"
    return f"Spotify API returned status {status}"


def refreshed_token(state: dict, auth_file: str, *, accounts_base: str = ACCOUNTS_BASE_URL,
                    now: float | None = None, force: bool = False) -> str:
    clock = time.time() if now is None else now
    access = str(state.get("access_token") or "")
    try:
        expires_at = float(state.get("expires_at"))
    except (TypeError, ValueError):
        expires_at = 0.0
    if not force and access != "" and expires_at - clock > REFRESH_SKEW_S:
        return access
    refresh = str(state.get("refresh_token") or "")
    client_id = str(state.get("client_id") or "")
    if refresh == "" or client_id == "":
        raise SetupError("Spotify token is missing client_id or refresh_token; re-run scripts/spotify-auth.py")
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": client_id,
    }).encode("utf-8")
    request = urllib.request.Request(
        accounts_base.rstrip("/") + "/api/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_S) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        raise SetupError("Spotify token refresh was rejected; re-run scripts/spotify-auth.py"
                         + (f" ({detail})" if detail else "")) from exc
    except (OSError, ValueError) as exc:
        raise SetupError(f"Spotify token refresh failed: {exc}") from exc
    access = str(payload.get("access_token") or "")
    if access == "":
        raise SetupError("Spotify token refresh returned no access_token")
    state["access_token"] = access
    try:
        expires_in = float(payload.get("expires_in") or 3600)
    except (TypeError, ValueError):
        expires_in = 3600.0
    state["expires_at"] = clock + expires_in
    if payload.get("refresh_token"):
        state["refresh_token"] = str(payload["refresh_token"])
    if payload.get("scope"):
        state["scope"] = str(payload["scope"])
    save_auth(auth_file, state)
    return access


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def command_devices(args) -> int:
    if args.devices_input:
        try:
            with open(args.devices_input, encoding="utf-8") as handle:
                payload = json.load(handle)
        except (OSError, ValueError) as exc:
            emit({"ok": False, "error": "input",
                  "message": f"cannot read --devices-input: {exc}"})
            return 2
        result = parse_devices(payload)
        result["ok"] = True
        emit(result)
        return 0
    try:
        state = load_auth(args.auth_file)
    except SetupError as exc:
        emit({"ok": False, "error": "auth_missing", "message": str(exc)})
        return 2
    try:
        token = refreshed_token(state, args.auth_file, accounts_base=args.accounts_base)
        status, body = http_request("GET", build_devices_url(args.api_base), token=token)
        if status == 401:
            token = refreshed_token(state, args.auth_file, accounts_base=args.accounts_base, force=True)
            status, body = http_request("GET", build_devices_url(args.api_base), token=token)
        if status >= 400:
            emit({"ok": False, "error": "api", "status": status,
                  "message": api_error_message(status, body)})
            return 1
        payload = json.loads(body or b"{}")
    except SetupError as exc:
        emit({"ok": False, "error": "auth_missing", "message": str(exc)})
        return 2
    except OSError as exc:
        emit({"ok": False, "error": "network", "message": f"cannot reach Spotify: {exc}"})
        return 1
    except ValueError as exc:
        emit({"ok": False, "error": "api", "message": f"Spotify returned invalid JSON: {exc}"})
        return 1
    result = parse_devices(payload)
    result["ok"] = True
    emit(result)
    return 0


def command_transfer(args) -> int:
    if args.print_request:
        emit({"ok": True, "request": build_transfer_request(args.api_base, args.device_id, args.play)})
        return 0
    try:
        state = load_auth(args.auth_file)
    except SetupError as exc:
        emit({"ok": False, "error": "auth_missing", "message": str(exc)})
        return 2
    request = build_transfer_request(args.api_base, args.device_id, args.play)
    try:
        token = refreshed_token(state, args.auth_file, accounts_base=args.accounts_base)
        status, body = http_request(request["method"], request["url"], token=token, body=request["body"])
        if status == 401:
            token = refreshed_token(state, args.auth_file, accounts_base=args.accounts_base, force=True)
            status, body = http_request(request["method"], request["url"], token=token, body=request["body"])
        if status >= 400:
            emit({"ok": False, "error": "api", "status": status,
                  "message": api_error_message(status, body)})
            return 1
    except SetupError as exc:
        emit({"ok": False, "error": "auth_missing", "message": str(exc)})
        return 2
    except OSError as exc:
        emit({"ok": False, "error": "network", "message": f"cannot reach Spotify: {exc}"})
        return 1
    emit({"ok": True, "deviceId": args.device_id})
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Control Spotify Connect devices for the dashboard.")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--auth-file", default=default_auth_file(),
                        help="PKCE token written by scripts/spotify-auth.py")
    common.add_argument("--api-base", default=API_BASE_URL)
    common.add_argument("--accounts-base", default=ACCOUNTS_BASE_URL)
    subparsers = parser.add_subparsers(dest="command", required=True)

    devices = subparsers.add_parser("devices", parents=[common], help="list Connect devices as JSON")
    devices.add_argument("--devices-input",
                         help="read a canned API response from a file instead of the network (tests)")

    transfer = subparsers.add_parser("transfer", parents=[common], help="move playback to one device")
    transfer.add_argument("--device-id", required=True)
    transfer.add_argument("--play", action="store_true",
                          help="start playback on the target after the transfer")
    transfer.add_argument("--print-request", action="store_true",
                          help="print the request without sending it (tests)")

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "devices":
        return command_devices(args)
    if getattr(args, "device_id", "").strip() == "":
        emit({"ok": False, "error": "usage", "message": "--device-id is required"})
        return 2
    return command_transfer(args)


if __name__ == "__main__":
    sys.exit(main())
