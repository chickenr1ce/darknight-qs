#!/usr/bin/env bash
# instance.sh — resolve the live or newest Quickshell instance for a config dir.
#
# Every by-id runtime dir under the Quickshell runtime root holds one instance's
# log, ipc socket, and lock. Stale dirs pile up across launches, so "newest" is
# not the same as "the one running this config". This script is the one place
# that answers three questions for a config:
#   pid  — the pid of the running instance (for `quickshell ipc --pid <pid>`)
#   dir  — the by-id runtime directory for the config (newest, even after exit)
#   log  — its log.log (newest for the config, even after the process exits)
#
# Passive: it never boots an instance and never claims the bus.
# Usage: scripts/instance.sh <pid|dir|log|list> [--config DIR]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
BY_ID="$RUNTIME/quickshell/by-id"
CMD=""
CONFIG="$ROOT"

usage() {
    local fd=2
    [[ "${1:-0}" -eq 0 ]] && fd=1
    cat >&"$fd" <<'EOF'
instance.sh — resolve the live or newest Quickshell instance for a config dir.

Usage: scripts/instance.sh <command> [--config DIR]

Commands:
  pid           pid of the running instance (exit 1 if none)
  dir           by-id runtime dir of the newest instance for the config
  log           log.log of the newest instance for the config
  list          every by-id dir with its config and running pid
  help          this message

Options:
  --config DIR  config directory to resolve (default: the repo root)
EOF
    exit "${1:-0}"
}

[[ $# -ge 1 ]] || usage 2
CMD="$1"
shift

case "$CMD" in
    help|-h|--help) usage 0 ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            [[ $# -ge 2 ]] || { echo "instance: --config needs a value" >&2; exit 2; }
            CONFIG="$2"; shift 2 ;;
        *) echo "instance: unknown arg $1" >&2; exit 2 ;;
    esac
done

CONFIG="$(readlink -f "$CONFIG")"
SHELL_QML="$CONFIG/shell.qml"

# Print the newest log.log under BY_ID whose launch line names CONFIG.
log_for() {
    local newest="" candidate
    for candidate in "$BY_ID"/*/log.log; do
        [[ -f "$candidate" ]] || continue
        if grep -qF "Launching config: \"$SHELL_QML\"" "$candidate" 2>/dev/null; then
            if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
                newest="$candidate"
            fi
        fi
    done
    [[ -n "$newest" ]] && printf '%s\n' "$newest"
}

# Print the runtime dir of log_for's result.
dir_for() {
    local log
    log="$(log_for || true)"
    [[ -n "$log" ]] && printf '%s\n' "$(dirname "$log")"
}

# Print the pid of the running instance whose command line names CONFIG (via
# `-p DIR`, canonicalized) or, when no `-p` flag is present, whose working
# directory is CONFIG. Checking the flag first means a test shell booted with
# `-p OTHER` from this config's directory is not mistaken for this config's
# instance. Exact-name pgrep keeps the caller's own shell out of the result.
pid_for() {
    local config="$1" p cmd cwd val flag_cfg start best="" best_start=-1
    for p in $(pgrep -x quickshell 2>/dev/null || true); do
        cmd="$(tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null || true)"
        cwd="$(readlink -f "/proc/$p/cwd" 2>/dev/null || true)"
        if [[ "$cmd" =~ (^|[[:space:]])-p([[:space:]]+|=)([^[:space:]]+) ]]; then
            val="${BASH_REMATCH[3]}"
            [[ "$val" == /* ]] || val="$cwd/$val"
            flag_cfg="$(readlink -f "$val" 2>/dev/null || true)"
            [[ "$flag_cfg" == "$config" ]] || continue
        else
            [[ "$cwd" == "$config" ]] || continue
        fi
        start="$(awk '{print $22}' "/proc/$p/stat" 2>/dev/null || echo 0)"
        if [[ -n "$start" && "$start" -gt "$best_start" ]]; then
            best="$p"
            best_start="$start"
        fi
    done
    [[ -n "$best" ]] && printf '%s\n' "$best"
}

case "$CMD" in
    pid)
        p="$(pid_for "$CONFIG" || true)"
        [[ -n "$p" ]] || { echo "instance: no running instance for $CONFIG" >&2; exit 1; }
        printf '%s\n' "$p"
        ;;
    dir)
        d="$(dir_for || true)"
        [[ -n "$d" ]] || { echo "instance: no runtime dir for $CONFIG" >&2; exit 1; }
        printf '%s\n' "$d"
        ;;
    log)
        l="$(log_for || true)"
        [[ -n "$l" ]] || { echo "instance: no live log for $SHELL_QML" >&2; exit 1; }
        printf '%s\n' "$l"
        ;;
    list)
        for d in "$BY_ID"/*/; do
            [[ -d "$d" ]] || continue
            launch="$(grep -m1 -o 'Launching config: "[^"]*"' "$d/log.log" 2>/dev/null || true)"
            config="${launch#Launching config: \"}"
            config="${config%\"}"
            config="${config%/shell.qml}"
            p=""
            [[ -n "$config" ]] && p="$(pid_for "$config" || true)"
            printf '%s  pid=%s  %s\n' "${d%/}" "${p:-none}" "${config:-unknown}"
        done
        ;;
    *)
        echo "instance: unknown command $CMD" >&2
        usage 2
        ;;
esac
