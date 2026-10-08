#!/usr/bin/env bash
# Headless gate for scripts/lint.sh's unresolved-type check.
#
# Copies lint.sh into a fixture module tree holding a service that drops an
# import and one that keeps it, so the gate proves the check fails the miss and
# passes the imported file. It needs the Quickshell QML modules but no live
# instance.
set -euo pipefail

# A git hook exports these; the fixture is its own repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "lint-imports FAIL: $*" >&2; exit 1; }

# Same skip as lint.sh: without the modules there is no type lint to test.
if [ ! -d /usr/lib/qt6/qml/Quickshell ]; then
    echo "lint-imports: Quickshell QML modules not found, skipping"
    exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-lint-imports-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FIX="$TMP/repo"
mkdir -p "$FIX/scripts" "$FIX/services"
git -C "$FIX" init -q
cp "$ROOT/scripts/lint.sh" "$FIX/scripts/lint.sh"

# Names IpcHandler (from Quickshell.Io) without importing it: the miss.
cat >"$FIX/services/Bad.qml" <<'EOF'
import QtQuick
import Quickshell

QtObject {
    id: root

    IpcHandler {
        target: "bad"
        function ping(): string { return "ok"; }
    }
}
EOF

# The same file with the import: the check must pass it.
cat >"$FIX/services/Good.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    IpcHandler {
        target: "good"
        function ping(): string { return "ok"; }
    }
}
EOF

LINT="$FIX/scripts/lint.sh"

if "$LINT" services/Bad.qml >"$TMP/out" 2>&1; then
    fail "missed the missing import: $(cat "$TMP/out")"
fi
grep -q 'IpcHandler was not found' "$TMP/out" \
    || fail "did not name the unresolved type: $(cat "$TMP/out")"

"$LINT" services/Good.qml >"$TMP/out" 2>&1 \
    || fail "flagged the imported file: $(cat "$TMP/out")"

echo "lint-imports: ok"
