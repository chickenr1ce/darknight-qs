#!/usr/bin/env bash
# Headless gate for the native lock screen: the pure rules in
# services/LockLogic.js (run under node through tests/qmljs.js), the lock
# service's place in the session lock and PAM wiring, and the power menu's Lock
# routing into LockService.
#
# Nothing here locks: a WlSessionLock in a throwaway instance locks the real
# compositor session, so the gate checks the wiring and the preview surface and
# never calls `lock lock`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "lock FAIL: $*" >&2; exit 1; }

LOGIC="$ROOT/services/LockLogic.js"
SVC="$ROOT/services/LockService.qml"
SURFACE="$ROOT/windows/LockSurface.qml"
PREVIEW="$ROOT/windows/LockPreview.qml"
SHELL="$ROOT/shell.qml"
POWERLOGIC="$ROOT/services/PowerLogic.js"
POWERSVC="$ROOT/services/PowerService.qml"

# --- 1. structure: the service, the session lock, the preview, the power route ---
test -f "$LOGIC" || fail "services/LockLogic.js is missing"
test -f "$SVC" || fail "services/LockService.qml is missing"
test -f "$SURFACE" || fail "windows/LockSurface.qml is missing"
test -f "$PREVIEW" || fail "windows/LockPreview.qml is missing"
grep -q '^\.pragma library' "$LOGIC" || fail "LockLogic.js is not a .pragma library"
grep -q '^singleton LockService 1.0 LockService.qml' "$ROOT/services/qmldir" \
    || fail "LockService is not registered in services/qmldir"
grep -q 'import "LockLogic.js" as LockLogic' "$SVC" \
    || fail "LockService does not delegate to LockLogic.js"
grep -q 'import Quickshell.Services.Pam' "$SVC" \
    || fail "LockService does not import the PAM service"
grep -q 'config: "login"' "$SVC" \
    || fail "LockService does not use the system login PAM config"
grep -q 'property bool locked: false' "$SVC" \
    || fail "LockService does not start unlocked"
grep -q 'target: "lock"' "$SVC" || fail "LockService has no lock IPC target"

LOCKS="$(grep -c 'root.locked = true' "$SVC" || true)"
test "$LOCKS" = "1" || fail "LockService does not have exactly one lock() writer (found $LOCKS)"
if grep -q 'locked = true' "$SURFACE" "$PREVIEW" "$SHELL"; then
    fail "a lock surface or the shell sets the session lock itself; only LockService.lock does it"
fi
if grep -q 'LockService.lock()' "$SURFACE" "$PREVIEW"; then
    fail "the lock surface or preview locks the session; only the IPC target and the power menu may"
fi

grep -q 'WlSessionLock {' "$SHELL" || fail "shell.qml has no WlSessionLock"
grep -q 'locked: LockService.locked' "$SHELL" \
    || fail "the session lock is not bound to LockService.locked"
grep -q 'WlSessionLockSurface {' "$SHELL" || fail "shell.qml has no WlSessionLockSurface"
grep -q 'LockSurface {' "$SHELL" || fail "the session lock surface does not host LockSurface"

grep -q 'LockSurface {' "$PREVIEW" || fail "the preview does not host the same LockSurface"
grep -q 'preview: true' "$PREVIEW" || fail "the preview does not stub auth"
grep -q 'WlrLayershell.layer: WlrLayer.Overlay' "$PREVIEW" \
    || fail "the preview is not an overlay layer"
grep -q 'DevGeometry.register("lock.preview"' "$PREVIEW" \
    || fail "the preview does not register lock.preview for capture"
grep -q 'DevGeometry.unregister("lock.preview"' "$PREVIEW" \
    || fail "the preview does not unregister lock.preview"
grep -q 'QUICKSHELL_DEV_PROBE' "$SVC" || fail "the preview IPC is not dev-gated"

grep -q 'result.lock === true' "$POWERSVC" \
    || fail "the power menu does not route the lock flag"
grep -q 'LockService.lock()' "$POWERSVC" \
    || fail "the power menu Lock does not call LockService.lock"
grep -q 'lock: true' "$POWERLOGIC" || fail "PowerLogic does not flag the lock action"
if grep -qE 'hyprlock|betterlockscreen|i3lock' "$POWERLOGIC"; then
    fail "PowerLogic still spawns a locker; LockService owns the lock"
fi
if grep -qE 'systemctl|playerctl|efibootmgr|hyprctl' "$LOGIC" "$SURFACE"; then
    fail "a lock file duplicates power command strings; PowerLogic owns the argv"
fi
grep -q 'PowerLogic.press' "$SVC" || fail "LockService does not reuse PowerLogic press rules"
grep -q 'PowerLogic.confirm' "$SVC" || fail "LockService does not reuse PowerLogic confirm rules"

# --- 2. the pure reveal, message, action and key rules run under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$POWERLOGIC" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('lock');
const ll = qmljs.load(process.argv[3]);
const pl = qmljs.load(process.argv[4]);

const IDLE = { fieldLength: 0, authState: 'idle', powerOpen: false, msSinceLastKey: 6000, idleMs: 6000 };

check('reveal/idle-hidden', ll.revealShown(IDLE), false);
check('reveal/just-typed', ll.revealShown({ ...IDLE, msSinceLastKey: 0 }), true);
check('reveal/before-boundary', ll.revealShown({ ...IDLE, msSinceLastKey: 5999 }), true);
check('reveal/at-boundary', ll.revealShown({ ...IDLE, msSinceLastKey: 6000 }), false);
check('reveal/nonempty-holds', ll.revealShown({ ...IDLE, fieldLength: 3, msSinceLastKey: 99999 }), true);
check('reveal/negative-elapsed', ll.revealShown({ ...IDLE, msSinceLastKey: -1 }), false);
check('reveal/checking', ll.revealShown({ ...IDLE, authState: 'checking', msSinceLastKey: 99999 }), true);
check('reveal/failed', ll.revealShown({ ...IDLE, authState: 'failed', msSinceLastKey: 99999 }), true);
check('reveal/power-hides-typing', ll.revealShown({ ...IDLE, powerOpen: true, fieldLength: 2, msSinceLastKey: 0 }), false);
check('reveal/power-hides-auth', ll.revealShown({ ...IDLE, powerOpen: true, authState: 'checking' }), false);

check('msg/idle-empty', ll.messageText('idle', '', false, 0), '');
check('msg/checking', ll.messageText('checking', '', false, 0), 'Checking…');
check('msg/failed-one', ll.messageText('failed', '', false, 1), 'Wrong password');
check('msg/failed-three', ll.messageText('failed', '', false, 3), 'Wrong password · 3 attempts');
check('msg/failed-pam', ll.messageText('failed', 'Authentication failure', true, 2), 'Authentication failure · 2 attempts');
check('msg/idle-info', ll.messageText('idle', 'The account is temporarily locked', false, 0), 'The account is temporarily locked');
check('msg/error-idle-info', ll.messageIsError('idle', 'notice', false), false);
check('msg/error-idle-error', ll.messageIsError('idle', 'bad', true), true);
check('msg/error-empty', ll.messageIsError('idle', '', true), false);
check('msg/error-checking', ll.messageIsError('checking', '', true), false);
check('msg/error-failed', ll.messageIsError('failed', '', false), true);

const actions = ll.powerActions(pl.table());
check('actions/ids', actions.map(a => a.id), ['suspend', 'reboot', 'shutdown']);
check('actions/hints', actions.map(a => a.hint), ['1', '2', '3']);
check('actions/excludes-lock-logout-winboot',
      actions.filter(a => a.id === 'lock' || a.id === 'logout' || a.id === 'winboot').length, 0);
for (let i = 0; i < actions.length; i++)
    check('actions/argv-' + actions[i].id, actions[i].argv, pl.argv(actions[i].id));
const missing = ll.powerActions(pl.table().filter(entry => entry.id !== 'suspend'));
check('actions/missing-keeps-hints', missing.map(a => [a.id, a.hint]), [['reboot', '2'], ['shutdown', '3']]);

check('route/arm-1', ll.powerRoute(actions, '', '1'), { kind: 'arm', id: 'suspend' });
check('route/arm-2', ll.powerRoute(actions, '', '2'), { kind: 'arm', id: 'reboot' });
check('route/arm-3', ll.powerRoute(actions, '', '3'), { kind: 'arm', id: 'shutdown' });
check('route/arm-out-of-range', ll.powerRoute(actions, '', '4'), { kind: 'none' });
check('route/arm-zero', ll.powerRoute(actions, '', '0'), { kind: 'none' });
check('route/enter-confirms', ll.powerRoute(actions, 'reboot', 'Return'), { kind: 'confirm' });
check('route/enter-key-confirms', ll.powerRoute(actions, 'reboot', 'Enter'), { kind: 'confirm' });
check('route/enter-idle', ll.powerRoute(actions, '', 'Return'), { kind: 'none' });
check('route/escape-disarms', ll.powerRoute(actions, 'reboot', 'Escape'), { kind: 'disarm' });
check('route/escape-closes', ll.powerRoute(actions, '', 'Escape'), { kind: 'close' });
check('route/other-key', ll.powerRoute(actions, 'reboot', 'x'), { kind: 'none' });

check('caps/letter-on', ll.capsLockAfterKey(false, false, true, true, false), true);
check('caps/letter-off', ll.capsLockAfterKey(true, false, true, false, false), false);
check('caps/shift-ignored', ll.capsLockAfterKey(true, false, true, false, true), true);
check('caps/key-on', ll.capsLockAfterKey(false, true, false, false, false), true);
check('caps/key-off', ll.capsLockAfterKey(true, true, false, false, false), false);
check('caps/nonletter', ll.capsLockAfterKey(true, false, false, false, false), true);
check('initial/name', ll.initial('alexiz'), 'A');
check('initial/spaces', ll.initial('  bob'), 'B');
check('initial/empty', ll.initial(''), '?');
check('initial/number', ll.initial('7up'), '7');

const lockPress = pl.press({ armed: '' }, 'lock');
check('power/lock-flag', lockPress.lock, true);
check('power/lock-run', lockPress.run, null);
check('power/lock-disarms', lockPress.state.armed, '');
check('power/lock-arg', pl.argv('lock'), null);
check('power/lock-over-armed', pl.press({ armed: 'reboot' }, 'lock').lock, true);
check('power/confirm-suspend', pl.confirm({ armed: 'suspend' }).run, pl.argv('suspend'));
check('power/confirm-shutdown', pl.confirm({ armed: 'shutdown' }).run, pl.argv('shutdown'));
NODEEOF

echo "lock: all ok"
