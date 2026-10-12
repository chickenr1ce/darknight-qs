#!/usr/bin/env bash
# Headless gate for services/CoalescedRunLogic.js, the shared "if busy,
# remember one request; on exit, drain it" Process lifecycle.
#
# Node runs the shipped logic file through tests/qmljs.js, so a broken
# CoalescedRunLogic.js fails here, not in the shell. qmltestrunner then runs
# the wrapper's event behaviour offscreen with a mock starter and a mock
# Process-like object (a launch that never runs or never exits must finish,
# not wedge), and structural greps pin ThemeService, ThemeBackground,
# WeatherService, CalendarService, SpotifyService, and MonitorService to the
# module: no hand-rolled queued flags, every decision routes through
# CoalescedRun, every run watches its Process, and every Process finishes its
# run from onExited.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "coalesced-run FAIL: $*" >&2; exit 1; }

SVC="$ROOT/services/ThemeService.qml"
BG="$ROOT/services/ThemeBackground.qml"
LOGIC="$ROOT/services/CoalescedRunLogic.js"

# --- 1. structure ---
test -f "$LOGIC" \
    || fail "services/CoalescedRunLogic.js is missing"
test -f "$ROOT/services/CoalescedRun.qml" \
    || fail "services/CoalescedRun.qml is missing"
test -f "$BG" \
    || fail "services/ThemeBackground.qml is missing"
grep -q '^\.pragma library' "$LOGIC" \
    || fail "CoalescedRunLogic.js is not a .pragma library"
grep -q '^CoalescedRun 1.0 CoalescedRun.qml' "$ROOT/services/qmldir" \
    || fail "CoalescedRun is not registered in services/qmldir"
grep -q '^ThemeBackground 1.0 ThemeBackground.qml' "$ROOT/services/qmldir" \
    || fail "ThemeBackground is not registered in services/qmldir"
grep -q '^import "CoalescedRunLogic.js" as CoalescedRunLogic' "$ROOT/services/CoalescedRun.qml" \
    || fail "CoalescedRun.qml does not import CoalescedRunLogic.js"
for svc in "$SVC" "$BG"; do
    grep -q 'import qs.services' "$svc" \
        || fail "$(basename "$svc") is missing its qs.services self-import"
done
for run in idCatalogRun idRenderRun idStatRun; do
    grep -q "$run" "$SVC" \
        || fail "ThemeService does not coalesce its runs through $run"
done
for run in idBackgroundScanRun idBackgroundApplyRun; do
    grep -q "$run" "$BG" \
        || fail "ThemeBackground does not coalesce its runs through $run"
done
# Every run must watch its Process: a launch that never runs (a missing
# binary, an exec with an empty command) has no exited to close it, so the
# wrapper needs the process to notice.
for pair in "idCatalogProcess idCatalogRun" "idStatProcess idStatRun" \
            "idRenderProcess idRenderRun"; do
    set -- $pair
    grep -qF "process: $1" "$SVC" \
        || fail "$2 does not bind process: $1, so a failed launch would wedge it"
done
for pair in "idBackgroundScanProcess idBackgroundScanRun" \
            "idBackgroundApplyProcess idBackgroundApplyRun"; do
    set -- $pair
    grep -qF "process: $1" "$BG" \
        || fail "$2 does not bind process: $1, so a failed launch would wedge it"
done
if grep -qE 'catalogQueued|renderQueued|backgroundsQueued|statQueued|backgroundQueuedPath|backgroundAttempts' "$SVC" "$BG"; then
    fail "a theme service hand-rolls a queued flag; CoalescedRun owns the run lifecycle"
fi
grep -qF 'maxRetries: 5' "$BG" \
    || fail "ThemeBackground lost the background apply retry budget of 5"
grep -q 'idBackgroundRetryTimer.restart()' "$BG" \
    || fail "ThemeBackground's retry decision no longer arms the background retry timer"

# --- 2. the lifecycle runs for real under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('coalesced-run');
const cr = qmljs.load(process.argv[3]);

const IDLE = { running: false, pending: false, pendingArg: undefined, arg: undefined, attempts: 0 };
check('initial/idle', cr.initial(), IDLE);

// request when idle starts
let r = cr.request(cr.initial(), 'a');
check('request/idle-starts', [r.start, r.arg], [true, 'a']);
check('request/idle-state', r.state,
      { running: true, pending: false, pendingArg: undefined, arg: 'a', attempts: 0 });
let busy = r.state;

// request while busy does not start; the latest arg wins
r = cr.request(busy, 'b');
check('request/busy-held', [r.start, r.arg], [false, undefined]);
check('request/busy-state', r.state,
      { running: true, pending: true, pendingArg: 'b', arg: 'a', attempts: 0 });
const held = r.state;

// two requests while busy -> one drain with the latest arg
r = cr.request(held, 'c');
check('request/busy-latest-wins', r.state.pendingArg, 'c');
r = cr.exited(r.state, true, {});
check('drain/starts-latest', [r.start, r.arg, r.retry], [true, 'c', false]);
check('drain/state', r.state,
      { running: true, pending: false, pendingArg: undefined, arg: 'c', attempts: 0 });
const drained = r.state;

// exit with nothing pending idles
r = cr.exited(drained, true, {});
check('exit/idles', r.state, IDLE);
const idle = r.state;

// failed exit retries up to maxRetries then stops; the retry stays held for
// the caller's delay and keeps its budget across release
r = cr.request(idle, 'p');
let st = r.state;
r = cr.exited(st, false, { maxRetries: 2 });
check('retry/first', [r.retry, r.state.attempts, r.state.pendingArg], [true, 1, 'p']);
st = cr.release(r.state).state;
r = cr.exited(st, false, { maxRetries: 2 });
check('retry/second', [r.retry, r.state.attempts, r.state.pendingArg], [true, 2, 'p']);
st = cr.release(r.state).state;
r = cr.exited(st, false, { maxRetries: 2 });
check('retry/stops', [r.retry, r.state.running], [false, false]);
check('retry/held-gone', cr.release(r.state).start, false);

// success resets attempts
r = cr.request(idle, 'q');
st = r.state;
r = cr.exited(st, false, { maxRetries: 5 });
st = r.state;
check('success/resets', cr.exited(st, true, { maxRetries: 5 }).state.attempts, 0);

// a fresh request resets the attempts and swallows the held retry
r = cr.request(idle, 'x');
st = cr.exited(r.state, false, { maxRetries: 5 }).state;
check('fresh/resets-and-replaces', cr.request(st, 'y'),
      { state: { running: true, pending: false, pendingArg: undefined, arg: 'y', attempts: 0 }, start: true, arg: 'y' });

// the drain wins over a retry on the same exit
r = cr.request(idle, 'a');
st = r.state;
r = cr.request(st, 'b');
check('drain-beats-retry', cr.exited(r.state, false, { maxRetries: 5 }),
      { state: { running: true, pending: false, pendingArg: undefined, arg: 'b', attempts: 0 }, start: true, arg: 'b', retry: false });

// the drain-tick race: a's exit defers b's starter one tick, and the
// deferred drain counts as running, so a request landing in that tick
// queues instead of starting (the old occupied-rebinding started it and the
// deferred starter clobbered its arg)
r = cr.request(idle, 'a');
let busyA = r.state;
r = cr.request(busyA, 'b');
r = cr.exited(r.state, true, {});
check('tick/drain-deferred', [r.start, r.arg, r.state.running], [true, 'b', true]);
r = cr.request(r.state, 'c');
check('tick/request-queued', [r.start, r.arg, r.state.pendingArg], [false, undefined, 'c']);
check('tick/busy-stays-b', r.state, { running: true, pending: true, pendingArg: 'c', arg: 'b', attempts: 0 });
r = cr.exited(r.state, true, {});
check('tick/c-drains-after-b', [r.start, r.arg, r.state.running], [true, 'c', true]);
check('tick/idle-after-c', cr.exited(r.state, true, {}).state, IDLE);

// gated request is held, then ungate starts it
r = cr.request(idle, 'g', { gated: true });
check('gate/held', [r.start, r.state.pending, r.state.pendingArg], [false, true, 'g']);
r = cr.request(r.state, 'h', { gated: true });
check('gate/latest-wins', r.state.pendingArg, 'h');
r = cr.release(r.state);
check('gate/release-starts', [r.start, r.arg], [true, 'h']);
check('gate/released-state', r.state,
      { running: true, pending: false, pendingArg: undefined, arg: 'h', attempts: 0 });

// release with nothing held is inert, and a running run is not double-started
check('release/nothing', cr.release(idle).start, false);
check('release/while-busy', cr.release(busy).start, false);

// resetAttempts is the background refresh reset: budget only, pending survives
r = cr.request(idle, 'z');
st = cr.exited(r.state, false, { maxRetries: 5 }).state;
check('reset-attempts/only-budget', cr.resetAttempts(st),
      { running: false, pending: true, pendingArg: 'z', arg: 'z', attempts: 0 });
check('reset-attempts/still-holds', cr.release(cr.resetAttempts(st)).start, true);
NODEEOF
# --- 3. the wrapper's offscreen event behaviour (skip without Qt 6) ---
QMLTESTRUNNER="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
WRAP_TEST="$ROOT/tests/coalesced-run.qml"
if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "coalesced-run: qmltestrunner not found, skipping the wrapper test" >&2
elif [ ! -f "$WRAP_TEST" ] || [ ! -f "$ROOT/services/CoalescedRun.qml" ]; then
    fail "the offscreen wrapper test or its component is missing"
else
    # services/ carries a qmldir whose singleton prerequisites no plain QML
    # engine can load, so the runner gets a flat qmldir-free staging dir with
    # the test beside the wrapper and its logic, where the type resolves from
    # the same directory.
    WRAP_DIR="$(mktemp -d)"
    cp "$ROOT/services/CoalescedRun.qml" "$ROOT/services/CoalescedRunLogic.js" "$WRAP_TEST" "$WRAP_DIR/"
    if [ ! -f "$WRAP_DIR/CoalescedRun.qml" ]; then
        rm -rf "$WRAP_DIR"
        fail "the wrapper staging failed"
    fi
    WRAP_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -input "$WRAP_DIR/coalesced-run.qml" >"$WRAP_OUT" 2>&1; then
        rm -rf "$WRAP_DIR" "$WRAP_OUT"
    else
        cat "$WRAP_OUT" >&2
        rm -rf "$WRAP_DIR" "$WRAP_OUT"
        fail "the CoalescedRun wrapper test failed"
    fi
fi

# --- 4. the wiring mesh: every run finishes exactly on the Process's exit ---
for pair in "idCatalogProcess idCatalogRun" "idStatProcess idStatRun" \
            "idRenderProcess idRenderRun"; do
    set -- $pair
    BLOCK="$(awk -v name="$1" '
        !found && $0 == "        id: " name { found = 1; next }
        found { if ($0 == "    }") exit; print }
    ' "$SVC")"
    test -n "$BLOCK" || fail "could not extract the $1 block"
    echo "$BLOCK" | grep -q "$2.finished(" \
        || fail "$1 does not finish its run on exit"
done
BLOCK="$(awk -v name="idBackgroundScanProcess" '
    !found && $0 == "        id: " name { found = 1; next }
    found { if ($0 == "    }") exit; print }
' "$BG")"
test -n "$BLOCK" || fail "could not extract the idBackgroundScanProcess block"
echo "$BLOCK" | grep -q 'idBackgroundScanRun.finished(' \
    || fail "idBackgroundScanProcess does not finish its run on exit"
# The apply Process routes its exit through the module's exit function, which
# finishes the run (after clearing the applied path on the retry branch).
BLOCK="$(awk -v name="idBackgroundApplyProcess" '
    !found && $0 == "        id: " name { found = 1; next }
    found { if ($0 == "    }") exit; print }
' "$BG")"
test -n "$BLOCK" || fail "could not extract the idBackgroundApplyProcess block"
echo "$BLOCK" | grep -q 'root.backgroundApplyExited(' \
    || fail "the background apply Process does not route its exit through the exit function"
grep -q 'function backgroundApplyExited' "$BG" \
    || fail "ThemeBackground has no backgroundApplyExited to finish the apply run"
APPLY_BLOCK="$(awk '/function backgroundApplyExited/{flag=1} flag{print} flag && /^    \}$/{exit}' "$BG")"
test -n "$APPLY_BLOCK" || fail "could not extract backgroundApplyExited"
echo "$APPLY_BLOCK" | grep -q 'idBackgroundApplyRun.finished(' \
    || fail "backgroundApplyExited does not finish the apply run"

# --- 5. Weather and Calendar coalesce the same way ---
WSVC="$ROOT/services/WeatherService.qml"
CSVC="$ROOT/services/CalendarService.qml"
for svc in "$WSVC" "$CSVC"; do
    grep -q '^import qs.services' "$svc" \
        || fail "$(basename "$svc") is missing its qs.services self-import"
done
for pair in "$WSVC:idWeatherProcess:idWeatherRun" "$WSVC:idGeocodeProcess:idGeocodeRun" \
            "$CSVC:idEventsProcess:idEventsRun" "$CSVC:idZoneProcess:idZoneRun"; do
    IFS=: read -r svc proc run <<<"$pair"
    grep -q "$run" "$svc" \
        || fail "$(basename "$svc") does not coalesce through $run"
    grep -qF "process: $proc" "$svc" \
        || fail "$run does not bind process: $proc, so a failed launch would wedge it"
    BLOCK="$(awk -v name="$proc" '
        !found && $0 == "        id: " name { found = 1; next }
        found { if ($0 == "    }") exit; print }
    ' "$svc")"
    test -n "$BLOCK" || fail "could not extract the $proc block"
    echo "$BLOCK" | grep -q "$run.finished(" \
        || fail "$proc does not finish its run on exit"
done
if grep -qE 'pollQueued|geocodeQueued|eventsPollQueued|zonePollQueued' "$WSVC" "$CSVC"; then
    fail "a service hand-rolls a queued flag; CoalescedRun owns the run lifecycle"
fi
# The weather boot fetch is load-driven: the location file's first load
# defers bootPoll, which polls only when applyLocation did not already. The
# node test in test-panel-logic.sh covers the pure decision; this pins the
# trigger, since the QML ordering itself is only inspectable.
grep -qF 'Qt.callLater(root.bootPoll)' "$WSVC" \
    || fail "WeatherService does not defer the boot poll from the location load"
grep -qF 'readonly property bool searchBusy: idGeocodeRun.running' "$WSVC" \
    || fail "the geocode search does not report busy through its run"

# --- 6. Spotify and Monitor coalesce the poll the same way ---
PSSVC="$ROOT/services/SpotifyService.qml"
PMSVC="$ROOT/services/MonitorService.qml"
for svc in "$PSSVC" "$PMSVC"; do
    grep -q '^import qs.services' "$svc" \
        || fail "$(basename "$svc") is missing its qs.services self-import"
done
for pair in "$PSSVC:idDevicesProcess:idDevicesRun" "$PMSVC:idMonitorsProcess:idMonitorsRun"; do
    IFS=: read -r svc proc run <<<"$pair"
    grep -q "$run" "$svc" \
        || fail "$(basename "$svc") does not coalesce through $run"
    grep -qF "process: $proc" "$svc" \
        || fail "$run does not bind process: $proc, so a failed launch would wedge it"
    BLOCK="$(awk -v name="$proc" '
        !found && $0 == "        id: " name { found = 1; next }
        found { if ($0 == "    }") exit; print }
    ' "$svc")"
    test -n "$BLOCK" || fail "could not extract the $proc block"
    echo "$BLOCK" | grep -q "$run.finished(" \
        || fail "$proc does not finish its run on exit"
done
if grep -qE 'pollQueued|pendingRefresh' "$PSSVC" "$PMSVC"; then
    fail "a service hand-rolls a queued flag; CoalescedRun owns the run lifecycle"
fi
# The Spotify transfer keeps its drop-when-busy semantics: it must not join
# the poll run, where a second pick would become a queued request.
TRANSFER_BLOCK="$(awk -v name="idTransferProcess" '
    !found && $0 == "        id: " name { found = 1; next }
    found { if ($0 == "    }") exit; print }
' "$PSSVC")"
test -n "$TRANSFER_BLOCK" || fail "could not extract the Spotify transfer Process block"
echo "$TRANSFER_BLOCK" | grep -q 'root.applyTransferResult(' \
    || fail "the Spotify transfer Process no longer applies its own result"
if grep -qF 'process: idTransferProcess' "$PSSVC"; then
    fail "the Spotify transfer must drop while busy, not coalesce into a run"
fi

echo "coalesced-run: all ok"
