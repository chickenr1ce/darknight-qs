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
FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
    UNTRACKED="$(git ls-files --others --exclude-standard '*.qml' || true)"
    if [[ -n "$UNTRACKED" ]]; then
        echo "lint: including untracked QML file(s):" >&2
        echo "$UNTRACKED" | sed 's/^/lint:   /' >&2
    fi
    mapfile -t FILES < <(collect_qml)
fi
"$QMLLINT" -I /usr/lib/qt6/qml "${FILES[@]}"
