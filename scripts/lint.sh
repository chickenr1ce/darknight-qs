#!/usr/bin/env bash
set -euo pipefail

mapfile -t PYFILES < <(git ls-files '*.py')
if [[ ${#PYFILES[@]} -gt 0 ]]; then
    python3 -B -m py_compile "${PYFILES[@]}"
    echo "lint: python syntax ok (${#PYFILES[@]} files)"
fi

QMLLINT=/usr/lib/qt6/bin/qmllint
FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
    mapfile -t FILES < <(git ls-files '*.qml')
fi
"$QMLLINT" -I /usr/lib/qt6/qml "${FILES[@]}"
