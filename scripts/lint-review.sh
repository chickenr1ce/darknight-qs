#!/usr/bin/env bash
# Style lint with baseline: python review linter over tracked QML files (or
# paths given as args), reporting only findings absent from
# scripts/lint-review-baseline.txt. Line numbers are stripped before
# comparison so shifting code does not re-report old findings.
# Regenerate the baseline after intentional style changes:
#   scripts/lint-review.sh --update-baseline
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINTER="$ROOT/.agents/skills/qt-qml-review/references/lint-scripts/qt_qml_lint.py"
BASELINE="$ROOT/scripts/lint-review-baseline.txt"

command -v python3 >/dev/null || { echo "lint-review: python3 not found" >&2; exit 2; }

UPDATE=0
FILES=()
for arg in "$@"; do
    case "$arg" in
        --update-baseline) UPDATE=1 ;;
        *) FILES+=("$arg") ;;
    esac
done
if [[ ${#FILES[@]} -eq 0 ]]; then
    mapfile -t FILES < <(cd "$ROOT" && git ls-files '*.qml')
fi

# A partial regeneration would silently drop every other entry, so refuse
# scoped updates outright. Stage new files with git add first, then rerun bare.
if [[ $UPDATE -eq 1 && ${#FILES[@]} -gt 0 ]]; then
    echo "lint-review: --update-baseline always regenerates the whole baseline; rerun without file paths (stage new files with git add first)" >&2
    exit 2
fi

RAW="$(mktemp /tmp/opencode/lint-review-XXXXXX)"
CURRENT="$(mktemp /tmp/opencode/lint-review-XXXXXX)"
trap 'rm -f "$RAW" "$CURRENT"' EXIT

# Exit 1 means findings, not failure; an empty file means clean.
python3 "$LINTER" "${FILES[@]}" >"$RAW" 2>/dev/null || true
sed 's/^\([^:]*\):[0-9]* /\1 /' "$RAW" | sort -u >"$CURRENT"

if [[ $UPDATE -eq 1 ]]; then
    {
        echo "# Baseline of accepted style-linter findings (scripts/lint-review.sh)."
        echo "# Per line: FILE RULE-ID MESSAGE (line numbers stripped)."
        echo "# Regenerate with: scripts/lint-review.sh --update-baseline"
        cat "$CURRENT"
    } >"$BASELINE"
    echo "lint-review: baseline updated ($(wc -l <"$CURRENT") findings)"
    exit 0
fi

if [[ ! -f "$BASELINE" ]]; then
    echo "lint-review: no baseline; run scripts/lint-review.sh --update-baseline" >&2
    exit 2
fi

NEW="$(mktemp /tmp/opencode/lint-review-XXXXXX)"
trap 'rm -f "$RAW" "$CURRENT" "$NEW"' EXIT
comm -13 <(grep -v '^#' "$BASELINE" | sort -u) "$CURRENT" >"$NEW" || true

if [[ -s "$NEW" ]]; then
    echo "lint-review: new findings vs baseline:"
    cat "$NEW"
    exit 1
fi
echo "lint-review: clean vs baseline"
