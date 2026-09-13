#!/usr/bin/env bash
# Repo QML lint: Qt6 qmllint over tracked QML files (or paths given as args).
# The Qt5 qmllint crashes on Quickshell imports — always use the Qt6 binary.
# Remaining `qs.*` import/unqualified warnings are pre-existing; qmllint still
# exits 0 on warnings and non-zero on real errors.
set -euo pipefail

QMLLINT=/usr/lib/qt6/bin/qmllint
FILES=("$@")
if [[ ${#FILES[@]} -eq 0 ]]; then
    mapfile -t FILES < <(git ls-files '*.qml')
fi
"$QMLLINT" -I /usr/lib/qt6/qml "${FILES[@]}"
