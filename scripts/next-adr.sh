#!/usr/bin/env bash
# next-adr.sh — print the next free ADR number, four digits.
#
# Numbers are claimed on unmerged branches and in uncommitted worktree files
# before they reach main (two 0018s landed that way), so this scans every local
# and remote branch's docs/adr/ plus every worktree's checkout, and prints one
# past the highest number anywhere.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

{
    git for-each-ref --format='%(refname)' refs/heads refs/remotes | while IFS= read -r ref; do
        git ls-tree --name-only "$ref" docs/adr/ 2>/dev/null || true
    done
    git worktree list --porcelain | sed -n 's/^worktree //p' | while IFS= read -r tree; do
        ls "$tree/docs/adr" 2>/dev/null || true
    done
} | sed -nE 's|^(docs/adr/)?([0-9]{4})-.*|\2|p' | sort -n | tail -1 | {
    read -r highest || highest=0
    printf '%04d\n' $((10#$highest + 1))
}
