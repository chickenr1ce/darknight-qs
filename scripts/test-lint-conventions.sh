#!/usr/bin/env bash
# Headless gate for scripts/lint-conventions.sh.
#
# Copies the script into a fixture repository, plants one violation per rule
# beside a passing neighbour, and checks that each rule fires on the violation
# alone; then fixes the tree and checks the script passes.
set -euo pipefail

# A git hook exports these; the fixture is its own repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "lint-conventions FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-lint-conventions-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

FIX="$TMP/repo"
mkdir -p "$FIX/scripts" "$FIX/config" "$FIX/windows" "$FIX/components" "$FIX/.scratch/feature"
git -C "$FIX" init -q
cp "$ROOT/scripts/lint-conventions.sh" "$FIX/scripts/"

cat >"$FIX/config/Icons.qml" <<'EOF'
QtObject {
    readonly property string open: "A"
    readonly property string close: "B"
    readonly property string openExternal: "A"
    readonly property string launch: root.open
}
EOF
cat >"$FIX/windows/Heading.qml" <<'EOF'
Text {
    text: qsTr("Output").toUpperCase()
}
EOF
cat >"$FIX/windows/Letter.qml" <<'EOF'
Text {
    text: root.name.charAt(0).toUpperCase()
}
EOF
cat >"$FIX/components/Toast.qml" <<'EOF'
Text {
    text: root.appName.toUpperCase()
}
EOF
echo "spec" >"$FIX/.scratch/feature/spec.md"

set +e
OUT="$("$FIX/scripts/lint-conventions.sh" 2>&1)"
STATUS=$?
set -e

[[ $STATUS -eq 1 ]] || fail "expected exit 1 with violations, got $STATUS: $OUT"
grep -q '^icons-unique config/Icons.qml:4 openExternal repeats the codepoint of open' <<<"$OUT" || fail "icons-unique missed the duplicate: $OUT"
[[ "$(grep -c '^icons-unique' <<<"$OUT")" -eq 1 ]] || fail "icons-unique flagged an alias or a unique codepoint: $OUT"
grep -q '^section-label windows/Heading.qml:2 ' <<<"$OUT" || fail "section-label missed the uppercase heading: $OUT"
grep -q 'Letter.qml' <<<"$OUT" && fail "section-label flagged a charAt(0) initial: $OUT"
grep -q 'Toast.qml' <<<"$OUT" && fail "section-label reached into components/: $OUT"
grep -q '^scratch-tracked .scratch/feature/spec.md ' <<<"$OUT" || fail "scratch-tracked missed the untracked ticket: $OUT"

sed -i 's/openExternal: "A"/openExternal: root.open/' "$FIX/config/Icons.qml"
sed -i 's/qsTr("Output").toUpperCase()/qsTr("Output")/' "$FIX/windows/Heading.qml"
git -C "$FIX" add .scratch

OUT="$("$FIX/scripts/lint-conventions.sh" 2>&1)" || fail "expected a clean pass after the fixes: $OUT"
grep -q 'lint-conventions: clean' <<<"$OUT" || fail "no clean report: $OUT"

echo "lint-conventions: all ok"
