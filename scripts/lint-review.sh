#!/usr/bin/env bash
# Style lint with baseline: python review linter over tracked QML files (or
# paths given as args), reporting only findings absent from
# scripts/lint-review-baseline.txt. Line numbers are stripped before
# comparison so shifting code does not re-report old findings. Repeated
# findings are counted: a second occurrence of an already-baselined
# FILE RULE-ID MESSAGE is reported as new.
# Regenerate the baseline after intentional style changes:
#   scripts/lint-review.sh --update-baseline
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINTER="$ROOT/.agents/skills/qt-qml-review/references/lint-scripts/qt_qml_lint.py"
BASELINE="$ROOT/scripts/lint-review-baseline.txt"

command -v python3 >/dev/null || { echo "lint-review: python3 not found" >&2; exit 2; }

UPDATE=0
FILES=()
EXPLICIT_PATHS=0
for arg in "$@"; do
    case "$arg" in
        --update-baseline) UPDATE=1 ;;
        *) FILES+=("$arg"); EXPLICIT_PATHS=1 ;;
    esac
done

# A partial regeneration would silently drop every other entry, so refuse
# scoped updates outright. Untracked QML files are included below, so new
# files are linted (and baselined) without staging first.
if [[ $UPDATE -eq 1 && $EXPLICIT_PATHS -eq 1 ]]; then
    echo "lint-review: --update-baseline always regenerates the whole baseline; rerun without file paths" >&2
    exit 2
fi
if [[ ${#FILES[@]} -eq 0 ]]; then
    UNTRACKED="$(cd "$ROOT" && git ls-files --others --exclude-standard '*.qml' || true)"
    if [[ -n "$UNTRACKED" ]]; then
        echo "lint-review: including untracked QML file(s):" >&2
        echo "$UNTRACKED" | sed 's/^/lint-review:   /' >&2
    fi
    mapfile -t FILES < <(cd "$ROOT" && { git ls-files '*.qml'; git ls-files --others --exclude-standard '*.qml'; } | sort -u)
fi

RAW="$(mktemp /tmp/opencode/lint-review-XXXXXX)"
CURRENT="$(mktemp /tmp/opencode/lint-review-XXXXXX)"
trap 'rm -f "$RAW" "$CURRENT"' EXIT

# Exit 1 means findings, not failure; an empty file means clean.
python3 "$LINTER" "${FILES[@]}" >"$RAW" 2>/dev/null || true
# Keep duplicate lines: the comparison below is multiset-aware, so an increased
# count of an already-baselined FILE RULE-ID MESSAGE is a new finding.
sed 's/^\([^:]*\):[0-9]* /\1 /' "$RAW" | sort >"$CURRENT"

if [[ $UPDATE -eq 1 ]]; then
    {
        echo "# Baseline of accepted style-linter findings (scripts/lint-review.sh)."
        echo "# Per line: FILE RULE-ID MESSAGE (line numbers stripped)."
        echo "# Repeated lines record repeated findings; keep them."
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
# Multiset difference: report each current occurrence beyond the count the
# baseline accepted. grep/comm can't express this (sort -u erased counts).
python3 - "$BASELINE" "$CURRENT" >"$NEW" <<'PY'
import collections
import sys

baseline_path, current_path = sys.argv[1], sys.argv[2]


def counts(path, skip_comments):
    tally = collections.Counter()
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if skip_comments and line.startswith("#"):
                continue
            tally[line] += 1
    return tally


accepted = counts(baseline_path, skip_comments=True)
seen = counts(current_path, skip_comments=False)
for line in sorted((seen - accepted).elements()):
    print(line)
PY

if [[ -s "$NEW" ]]; then
    echo "lint-review: new findings vs baseline:"
    cat "$NEW"
    exit 1
fi
echo "lint-review: clean vs baseline"
