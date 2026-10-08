#!/usr/bin/env bash
# Headless gate for the Spotify Connect backend (ticket 02).
#
# Offline by design: it exercises the pure parsing plus request construction
# in scripts/spotify-connect.py and the PKCE URL building in
# scripts/spotify-auth.py, and checks the failure contract (exit 2 plus a JSON
# error) without ever touching the network or a real token.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONNECT="$ROOT/scripts/spotify-connect.py"
AUTH="$ROOT/scripts/spotify-auth.py"
FIXTURE="$ROOT/tests/fixtures/spotify-devices.json"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/qs-spotify-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "spotify-connect FAIL: $*" >&2; exit 1; }

# --- 1. device normalization matches the fixture and survives bad input ---
python3 - "$CONNECT" "$FIXTURE" <<'EOF'
import importlib.util, json, sys

spec = importlib.util.spec_from_file_location("spotify_connect", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

fixture = json.load(open(sys.argv[2]))
parsed = mod.parse_devices(fixture)
devices = parsed["devices"]
assert parsed["activeId"] == fixture["devices"][0]["id"], "active device not picked up"
assert [d["name"] for d in devices] == ["Workstation", "Pixel 9", "Living Room speaker"]
assert devices[0] == {
    "id": "702341f5c9bd8b7f84aa9b789a1df8cded69d710",
    "name": "Workstation",
    "type": "Computer",
    "isActive": True,
    "isRestricted": False,
    "volumePercent": 54,
}, devices[0]
assert devices[1]["isActive"] is False and devices[1]["isRestricted"] is False
assert devices[2]["isRestricted"] is True, "restricted flag lost"
assert devices[2]["volumePercent"] == -1, "missing volume should read -1"

assert mod.parse_devices(None) == {"devices": [], "activeId": ""}
assert mod.parse_devices({}) == {"devices": [], "activeId": ""}
assert mod.parse_devices({"devices": "nope"}) == {"devices": [], "activeId": ""}
assert mod.parse_devices({"devices": [None, {"name": "no id"}, {"id": "x"}]}) == {"devices": [], "activeId": ""}
assert mod.parse_devices({"devices": [{"id": "x", "name": "Y", "is_active": True}]})["activeId"] == "x"
assert mod.parse_devices({"devices": [{"id": "x", "name": "Y", "volume_percent": "bad"}]})["devices"][0]["volumePercent"] == -1
EOF
echo "spotify-connect: device normalization ok"

# --- 2. devices subcommand wraps the parse in {ok: true} ---
OUT="$(python3 "$CONNECT" devices --devices-input "$FIXTURE")"
python3 - "$OUT" "$FIXTURE" <<'EOF'
import json, sys
out = json.loads(sys.argv[1])
fixture = json.load(open(sys.argv[2]))
assert out["ok"] is True, out
assert out["activeId"] == fixture["devices"][0]["id"]
assert len(out["devices"]) == 3
EOF
echo "spotify-connect: devices fixture ok"

# --- 3. transfer request construction ---
python3 - "$CONNECT" <<'EOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("spotify_connect", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

assert mod.build_devices_url("https://api.spotify.com/v1/") == "https://api.spotify.com/v1/me/player/devices"
assert mod.build_transfer_request("https://api.spotify.com/v1/", "abc", True) == {
    "method": "PUT",
    "url": "https://api.spotify.com/v1/me/player",
    "body": {"device_ids": ["abc"], "play": True},
}
assert mod.build_transfer_request("https://api.spotify.com/v1", "abc")["body"]["play"] is False
EOF
PRINT="$(python3 "$CONNECT" transfer --device-id abc --print-request)"
python3 - "$PRINT" <<'EOF'
import json, sys
out = json.loads(sys.argv[1])
assert out["ok"] is True and out["request"]["method"] == "PUT"
assert out["request"]["body"] == {"device_ids": ["abc"], "play": False}
EOF
PRINT_PLAY="$(python3 "$CONNECT" transfer --device-id abc --play --print-request)"
python3 - "$PRINT_PLAY" <<'EOF'
import json, sys
out = json.loads(sys.argv[1])
assert out["request"]["body"] == {"device_ids": ["abc"], "play": True}, out
EOF
echo "spotify-connect: request construction ok"

# --- 4. a missing token exits 2 with a JSON error, never a traceback ---
set +e
OUT="$(python3 "$CONNECT" devices --auth-file "$WORK/absent.json" 2>/dev/null)"
CODE=$?
set -e
[[ "$CODE" -eq 2 ]] || fail "missing token should exit 2, got $CODE"
python3 - "$OUT" <<'EOF'
import json, sys
out = json.loads(sys.argv[1])
assert out["ok"] is False and out["error"] == "auth_missing", out
EOF

set +e
OUT="$(python3 "$CONNECT" transfer --device-id abc --auth-file "$WORK/absent.json" 2>/dev/null)"
CODE=$?
set -e
[[ "$CODE" -eq 2 ]] || fail "missing token transfer should exit 2, got $CODE"

# --- 5. authorize URL carries PKCE, scope and loopback redirect ---
URL="$(python3 "$AUTH" --client-id testid --code-verifier verifier123 --state st --print-authorize-url)"
python3 - "$URL" <<'EOF'
import base64, hashlib, sys, urllib.parse
url = sys.argv[1]
parsed = urllib.parse.urlparse(url)
assert parsed.netloc == "accounts.spotify.com" and parsed.path == "/authorize", parsed
q = urllib.parse.parse_qs(parsed.query)
assert q["client_id"] == ["testid"]
assert q["response_type"] == ["code"]
assert q["redirect_uri"] == ["http://127.0.0.1:45173/spotify/callback"]
assert q["code_challenge_method"] == ["S256"]
assert "user-modify-playback-state" in q["scope"][0]
assert "user-read-playback-state" in q["scope"][0]
assert q["state"] == ["st"]
expected = base64.urlsafe_b64encode(hashlib.sha256(b"verifier123").digest()).decode().rstrip("=")
assert q["code_challenge"] == [expected], (q["code_challenge"], expected)
EOF
echo "spotify-connect: authorize URL ok"

# --- 6. auth refuses to run without a client id, and rejects bad redirects ---
set +e
python3 "$AUTH" --print-authorize-url >/dev/null 2>&1
CODE=$?
set -e
[[ "$CODE" -eq 2 ]] || fail "auth without a client id should exit 2, got $CODE"

python3 - "$AUTH" <<'EOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("spotify_auth", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

assert mod.validate_redirect_uri("http://127.0.0.1:45173/spotify/callback") == ("127.0.0.1", 45173, "/spotify/callback")
assert mod.validate_redirect_uri("http://localhost:9000/x") == ("localhost", 9000, "/x")
for bad in ("https://127.0.0.1:1/x", "http://example.com:1/x", "http://127.0.0.1/x", "not a url"):
    try:
        mod.validate_redirect_uri(bad)
    except mod.SetupError:
        pass
    else:
        raise AssertionError(f"accepted bad redirect {bad!r}")
EOF
echo "spotify-connect: auth guards ok"

echo "spotify-connect: all ok"
