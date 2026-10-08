#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

collect_qml() {
    {
        git ls-files '*.qml'
        git ls-files --others --exclude-standard '*.qml'
    } | sort -u
}

mapfile -t PYFILES < <(git ls-files '*.py')
if [[ ${#PYFILES[@]} -gt 0 ]]; then
    python3 -B -m py_compile "${PYFILES[@]}"
    echo "lint: python syntax ok (${#PYFILES[@]} files)"
fi

QMLLINT=/usr/lib/qt6/bin/qmllint
# Quickshell's QML modules ship with the shell, not Qt, so a runner without the
# shell cannot resolve them (and qmllint can crash on the unresolved modules).
if [ ! -d /usr/lib/qt6/qml/Quickshell ]; then
    echo "lint: Quickshell QML modules not found, skipping QML type lint" >&2
    exit 0
fi

FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
    UNTRACKED="$(git ls-files --others --exclude-standard '*.qml' || true)"
    if [[ -n "$UNTRACKED" ]]; then
        echo "lint: including untracked QML file(s):" >&2
        echo "$UNTRACKED" | sed 's/^/lint:   /' >&2
    fi
    mapfile -t FILES < <(collect_qml)
fi

# Quickshell resolves `import qs.<dir>` to <config>/<dir> at runtime, but qmllint
# resolves a module only through an import path, so with no import root every
# qs.* type reads as "was not found" and a real miss hides in that noise. Build a
# shim import root: one real dir per module, the module's .qml files symlinked
# in, and a generated qmldir. The writes stay in the shim; the symlinks are only
# read, so nothing lands in the tracked module dirs.
SHIM="$(mktemp -d "${TMPDIR:-/tmp}/qs-lint-XXXXXX")"
OUT="$(mktemp "${TMPDIR:-/tmp}/qs-lint-XXXXXX")"
trap 'rm -rf "$SHIM" "$OUT"' EXIT
mkdir -p "$SHIM/qs"
shopt -s nullglob
for module in config components modules windows services dev; do
    [[ -d "$ROOT/$module" ]] || continue
    mkdir -p "$SHIM/qs/$module"
    for file in "$ROOT/$module"/*.qml; do
        name="$(basename "$file" .qml)"
        ln -s "$file" "$SHIM/qs/$module/$name.qml"
        if head -n2 "$file" | grep -q '^pragma Singleton'; then
            printf 'singleton %s 1.0 %s.qml\n' "$name" "$name" >>"$SHIM/qs/$module/qmldir"
        else
            printf '%s 1.0 %s.qml\n' "$name" "$name" >>"$SHIM/qs/$module/qmldir"
        fi
    done
done

rc=0
"$QMLLINT" -I "$SHIM" -I /usr/lib/qt6/qml "${FILES[@]}" >"$OUT" 2>&1 || rc=$?
# A nonzero exit is a real qmllint error; surface it verbatim.
if [[ "$rc" -ne 0 ]]; then
    cat "$OUT"
    exit "$rc"
fi
# Warnings do not fail the gate, but an unresolved type name is what the runtime
# rejects as "<Type> is not a type", so fail on that class. The
# [signal-handler-parameters] warnings for QProcess::ExitStatus are a qmllint
# quirk, not a missing import.
MISSES="$(grep 'was not found' "$OUT" | grep '\[import\]' || true)"
if [[ -n "$MISSES" ]]; then
    echo "lint: unresolved QML type name(s); add the missing import:" >&2
    printf '%s\n' "$MISSES" >&2
    exit 1
fi
echo "lint: qmllint ok (${#FILES[@]} files)"
