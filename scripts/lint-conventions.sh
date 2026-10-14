#!/usr/bin/env bash
# lint-conventions.sh — the repo's own structure rules, the ones the vendored
# review linter (scripts/qt_qml_lint.py) cannot know. Each rule is a grep over
# tracked plus untracked files; every finding prints as `RULE FILE:LINE text`.
#
#   icons-unique    each codepoint in config/Icons.qml is declared once; an
#                   alias reads `name: root.other`, never a second literal
#   section-label   a panel heading in windows/ or modules/ is a SectionLabel
#                   (the font capitalises it), never `text: ....toUpperCase()`
#   scratch-tracked .scratch/ files are committed on the feature branch, so the
#                   merge commit that deletes them leaves them in history
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

FOUND=0
report() {
    echo "$1 $2"
    FOUND=1
}

if [[ -f config/Icons.qml ]]; then
    while IFS= read -r line; do
        report icons-unique "$line"
    done < <(python3 - config/Icons.qml <<'PY'
import re
import sys

path = sys.argv[1]
seen = {}
pattern = re.compile(r'readonly property string (\w+):\s*"([^"]+)"')
with open(path, encoding="utf-8") as handle:
    for number, text in enumerate(handle, 1):
        match = pattern.search(text)
        if not match:
            continue
        name, glyph = match.groups()
        if glyph in seen:
            print(f"{path}:{number} {name} repeats the codepoint of {seen[glyph]}; write `{name}: root.{seen[glyph]}`")
        else:
            seen[glyph] = name
PY
)
fi

mapfile -t PANEL_QML < <({ git ls-files 'windows/*.qml' 'modules/*.qml'; git ls-files --others --exclude-standard 'windows/*.qml' 'modules/*.qml'; } | sort -u)
if [[ ${#PANEL_QML[@]} -gt 0 ]]; then
    while IFS= read -r line; do
        report section-label "$line use SectionLabel instead of toUpperCase()"
    done < <(grep -nE '^\s*text:.*\.toUpperCase\(\)' "${PANEL_QML[@]}" 2>/dev/null | grep -v 'charAt(0)\.toUpperCase()' | sed -E 's/^([^:]+:[0-9]+):\s*/\1 /')
fi

while IFS= read -r path; do
    report scratch-tracked "$path is untracked; commit .scratch/ on the feature branch"
done < <(git ls-files --others --exclude-standard -- .scratch)

if [[ $FOUND -ne 0 ]]; then
    exit 1
fi
echo "lint-conventions: clean"
