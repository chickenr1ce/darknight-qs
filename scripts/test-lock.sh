#!/usr/bin/env bash
# Headless gate for the native lock screen: the pure session transitions in
# services/LockLogic.js and the power-menu rules in services/PowerLogic.js (both
# run under node through tests/qmljs.js), the lock service's place in the
# session lock and PAM wiring, and the power menu's Lock routing into
# LockService.
#
# Nothing here locks: a WlSessionLock in a throwaway instance locks the real
# compositor session, so the gate drives the transitions under node, checks the
# wiring, and never calls `lock lock`.
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

LOCKS="$(grep -c 'root\.locked =' "$SVC" || true)"
test "$LOCKS" = "1" || fail "LockService does not have exactly one session-lock writer (found $LOCKS)"
if grep -q 'locked = true' "$SURFACE" "$PREVIEW" "$SHELL"; then
    fail "a lock surface or the shell sets the session lock itself; only LockService.lock does it"
fi
if grep -q 'LockService.lock()' "$SURFACE" "$PREVIEW"; then
    fail "the lock surface or preview locks the session; only the IPC target and the power menu may"
fi
if grep -rq --exclude=test-lock.sh 'ipc call lock lock' "$ROOT/scripts"; then
    fail "a script takes the session lock; the gate never locks the live session"
fi

# The password is the PAM adapter's, never part of the service's interface.
if grep -rq 'pendingPassword' "$ROOT/services" "$ROOT/windows"; then
    fail "the password is back on a public surface; the PAM adapter keeps it privately"
fi
# The transitions are pure: adapters (PAM, Process, Timer, the clock) live in
# the service, and effects are data.
if grep -qE 'PamContext|Process \{|Timer \{|Date\.now' "$LOGIC"; then
    fail "LockLogic reaches an adapter; effects stay data and the service applies them"
fi
grep -q 'LockLogic.reduce' "$SVC" || fail "LockService does not dispatch events through LockLogic"
test "$(grep -c 'PamContext {' "$SVC")" = "1" \
    || fail "LockService does not keep exactly one PAM adapter"
test "$(grep -c 'Process {' "$SVC")" = "1" \
    || fail "LockService does not keep exactly one Process adapter"

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
grep -q 'PowerLogic.route' "$SVC" || fail "LockService does not route power keys through PowerLogic"

# --- 2. the session transitions run under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$POWERLOGIC" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('lock');
const ll = qmljs.load(process.argv[3]);
const pl = qmljs.load(process.argv[4]);

const IDLE = ll.initialState();
const kinds = result => result.effects.map(effect => effect.kind);

// Lock arms one session: locked, stamped, and every prior field reset.
const locked = ll.lock(IDLE, 1000);
check('lock/locked', locked.state.locked, true);
check('lock/locked-at', locked.state.lockedAt, 1000);
check('lock/effects', kinds(locked), ['pamReset', 'stopFailureTimer']);
check('lock/relock-keeps-stamp', ll.lock(locked.state, 2000).state.lockedAt, 1000);
check('lock/relock-no-effects', ll.lock(locked.state, 2000).effects, []);

// The one submit guard: no password, already checking, power card open, or not
// in a session all refuse without an effect.
const started = ll.submit(locked.state, 'hunter2');
check('submit/checking', started.state.authState, 'checking');
check('submit/effect', started.effects, [{ kind: 'pamStart', password: 'hunter2' }]);
check('submit/clears-message', started.state.pamMessage, '');
check('submit/empty', ll.submit(locked.state, '').effects, []);
check('submit/double', ll.submit(started.state, 'again').effects, []);
check('submit/unlocked', ll.submit(IDLE, 'hunter2').effects, []);
check('submit/power-open', ll.submit({ ...locked.state, powerOpen: true }, 'hunter2').effects, []);
check('submit/guard-can', ll.canSubmit(locked.state, 'hunter2'), true);
check('submit/guard-checking', ll.canSubmit(started.state, 'hunter2'), false);
check('submit/guard-empty', ll.canSubmit(locked.state, ''), false);
check('submit/guard-unlocked', ll.canSubmit(IDLE, 'hunter2'), false);

// One attempt answers one prompt. A second prompt asks for a secret the card
// cannot collect, so the attempt fails and the conversation aborts.
const first = ll.pamPrompt(started.state);
check('prompt/first-effect', first.effects, [{ kind: 'pamRespond' }]);
check('prompt/first-answered', first.state.pamAnswered, true);
check('prompt/first-keeps-checking', first.state.authState, 'checking');
const second = ll.pamPrompt(first.state);
check('prompt/second-effects', kinds(second), ['pamAbort', 'restartFailureTimer']);
check('prompt/second-failed', second.state.authState, 'failed');
check('prompt/second-attempt', second.state.attempts, 1);
check('prompt/second-message', second.state.pamMessage, 'Unsupported authentication prompt');
check('prompt/second-error', second.state.pamMessageIsError, true);
check('prompt/second-never-responds', second.effects.filter(e => e.kind === 'pamRespond').length, 0);
check('prompt/prompt-idle-ignored', ll.pamPrompt(locked.state).effects, []);
check('prompt/prompt-unlocked-ignored', ll.pamPrompt(IDLE).effects, []);

// Completion only counts while a check is in flight, so a late result after
// unlock, after a failure, or after a relock is inert.
const failed = ll.pamCompleted(started.state, false);
check('complete/fail-state', failed.state.authState, 'failed');
check('complete/fail-attempt', failed.state.attempts, 1);
check('complete/fail-effects', kinds(failed), ['pamReset', 'restartFailureTimer']);
check('complete/fail-keeps-message', ll.pamCompleted({ ...started.state, pamMessage: 'notice' }, false).state.pamMessage, 'notice');
const welcome = ll.pamCompleted(started.state, true);
check('complete/success-unlocked', welcome.state.locked, false);
check('complete/success-idle', welcome.state.authState, 'idle');
check('complete/success-effects', kinds(welcome), ['pamReset', 'stopFailureTimer']);
check('complete/late-after-unlock', ll.pamCompleted(welcome.state, false).state.attempts, 0);
check('complete/late-after-unlock-effects', kinds(ll.pamCompleted(welcome.state, true)), ['pamReset']);
check('complete/late-after-failure', ll.pamCompleted(failed.state, true).state.locked, true);
check('complete/late-after-second-prompt', ll.pamCompleted(second.state, false).state.attempts, 1);
check('complete/late-unlocked', ll.pamCompleted(IDLE, true).state.locked, false);

// PAM's own notices show as given; failure styling is derived by messageIsError.
const notice = ll.pamMessage(started.state, 'The account is temporarily locked', false);
check('message/text', notice.state.pamMessage, 'The account is temporarily locked');
check('message/error-flag', notice.state.pamMessageIsError, false);
check('message/error-set', ll.pamMessage(started.state, 'bad', true).state.pamMessageIsError, true);
check('message/error-coerced', ll.pamMessage(started.state, 'bad', 'yes').state.pamMessageIsError, false);

// The failure timer only clears a live failure.
const cleared = ll.failureReset({ ...failed.state, pamMessage: 'Wrong password' });
check('reset/state', cleared.state.authState, 'idle');
check('reset/message', cleared.state.pamMessage, '');
check('reset/error-flag', cleared.state.pamMessageIsError, false);
check('reset/effects', kinds(cleared), ['stopFailureTimer']);
check('reset/ignored-idle', ll.failureReset(locked.state).effects, []);
check('reset/ignored-unlocked', ll.failureReset({ ...failed.state, locked: false }).effects, []);

// A PAM that will not start is a failed attempt, not a stuck spinner.
const startFailed = ll.startFailed(started.state);
check('start/failed', startFailed.state.authState, 'failed');
check('start/attempt', startFailed.state.attempts, 1);
check('start/effects', kinds(startFailed), ['pamReset', 'restartFailureTimer']);
check('start/ignored-idle', ll.startFailed(locked.state).effects, []);

// Unlock and relock both start clean: no stale attempt, message, arm or card.
const dirty = {
    ...failed.state,
    attempts: 4,
    powerOpen: true,
    powerArmed: 'reboot',
    pamMessageIsError: true
};
const out = ll.unlock(dirty);
check('unlock/reset', [out.state.locked, out.state.authState, out.state.attempts, out.state.powerOpen, out.state.powerArmed], [false, 'idle', 0, false, '']);
check('unlock/effects', kinds(out), ['pamReset', 'stopFailureTimer']);
const relockDirty = { ...out.state, attempts: 4, powerArmed: 'reboot', powerOpen: true, pamMessage: 'x' };
const relocked = ll.lock(relockDirty, 5000);
check('relock/reset', [relocked.state.attempts, relocked.state.powerArmed, relocked.state.powerOpen, relocked.state.lockedAt], [0, '', false, 5000]);
check('relock/message', relocked.state.pamMessage, '');
check('relock/locked', relocked.state.locked, true);

// The power card: toggle, arm, cancel, close.
check('power/toggle-open', ll.togglePower(locked.state).state.powerOpen, true);
check('power/toggle-disarms', ll.togglePower({ ...locked.state, powerArmed: 'reboot' }).state.powerArmed, '');
check('power/toggle-close', ll.togglePower({ ...locked.state, powerOpen: true }).state.powerOpen, false);
check('power/arm', ll.arm(locked.state, 'suspend').state.powerArmed, 'suspend');
check('power/arm-same', ll.arm({ ...locked.state, powerArmed: 'suspend' }, 'suspend').state.powerArmed, 'suspend');
check('power/cancel', ll.arm({ ...locked.state, powerArmed: 'suspend' }, '').state.powerArmed, '');
check('power/close', [ll.closePower({ ...locked.state, powerOpen: true, powerArmed: 'suspend' }).state.powerOpen, ll.closePower({ ...locked.state, powerOpen: true, powerArmed: 'suspend' }).state.powerArmed], [false, '']);

// Confirm runs the armed action's argv, and only inside a locked session.
const armedLocked = { ...locked.state, powerOpen: true, powerArmed: 'reboot' };
const confirmed = ll.confirm(armedLocked, pl.confirm({ armed: 'reboot' }));
check('confirm/run', confirmed.effects, [{ kind: 'run', argv: pl.argv('reboot') }]);
check('confirm/closes', confirmed.state.powerOpen, false);
check('confirm/disarms', confirmed.state.powerArmed, '');
check('confirm/idle', ll.confirm(armedLocked, pl.confirm({ armed: '' })).effects, []);
check('confirm/unknown', ll.confirm({ ...armedLocked, powerArmed: 'nope' }, pl.confirm({ armed: 'nope' })).effects, []);
check('confirm/no-resolution', ll.confirm(armedLocked, null).effects, []);

// The lock card routes the digits PowerLogic gives it, and the card's drawn
// hints are that context's own numbering.
const lockRows = pl.rows('lock');
check('card/ids', lockRows.map(row => row.id), ['suspend', 'reboot', 'shutdown']);
check('card/hints', lockRows.map(row => row.hint), ['1', '2', '3']);
const armedByKey = ll.powerKey(locked.state, pl.route('lock', '', '2'), null);
check('card/key-arms', armedByKey.state.powerArmed, 'reboot');
check('card/key-unknown-digit', ll.powerKey(locked.state, pl.route('lock', '', '4'), null).state.powerArmed, '');
check('card/key-escape-disarms', ll.powerKey(armedByKey.state, pl.route('lock', armedByKey.state.powerArmed, 'Escape'), null).state.powerArmed, '');
check('card/key-escape-closes', ll.powerKey(locked.state, pl.route('lock', '', 'Escape'), null).state.powerOpen, false);
const keyConfirm = ll.powerKey(armedByKey.state, pl.route('lock', 'reboot', 'Return'), pl.confirm({ armed: 'reboot' }));
check('card/key-confirms', keyConfirm.effects, [{ kind: 'run', argv: pl.argv('reboot') }]);
check('card/key-confirm-closes', keyConfirm.state.powerOpen, false);

// The dev preview runs the same transitions and never takes the session lock;
// its adapter stubs auth, and a confirm there never runs a command.
const typing = ll.previewPhase(IDLE, 'typing', 42);
check('preview/typing-phase', typing.state.previewPhase, 'typing');
check('preview/typing-auth', typing.state.authState, 'idle');
check('preview/typing-open', typing.state.previewOpen, true);
check('preview/typing-stamp', typing.state.lockedAt, 42);
const checking = ll.previewPhase(IDLE, 'checking', 43);
check('preview/checking-auth', checking.state.authState, 'checking');
const previewFailed = ll.previewPhase(IDLE, 'failed', 44);
check('preview/failed-state', [previewFailed.state.authState, previewFailed.state.attempts], ['failed', 3]);
check('preview/failed-no-timer', previewFailed.effects, []);
check('preview/failure-clears', ll.failureReset(previewFailed.state).state.authState, 'idle');
const previewPower = ll.previewPhase(IDLE, 'power', 45);
check('preview/power-open', previewPower.state.powerOpen, true);
check('preview/unknown-phase', ll.previewPhase({ ...IDLE, previewPhase: 'typing' }, 'nope', 1).state.previewPhase, 'typing');
check('preview/never-locks', [typing.state.locked, checking.state.locked, previewFailed.state.locked, previewPower.state.locked], [false, false, false, false]);
check('preview/open', ll.previewToggle(IDLE, 9).state.previewOpen, true);
check('preview/close', ll.previewToggle({ ...IDLE, previewOpen: true, authState: 'failed' }, 9).state.previewOpen, false);
check('preview/submit-starts-check', ll.submit(typing.state, 'hunter2').state.authState, 'checking');
const previewArmed = { ...previewPower.state, powerArmed: 'reboot' };
check('preview/confirm-no-run', ll.confirm(previewArmed, pl.confirm({ armed: 'reboot' })).effects, []);
check('preview/confirm-closes', ll.confirm(previewArmed, pl.confirm({ armed: 'reboot' })).state.powerOpen, false);

// Closing the power card in the preview returns the phase to idle: the power
// phase describes an open card, so `lock status` must not report a stale one.
const previewClosed = ll.closePower(previewPower.state);
check('preview/power-close-phase', previewClosed.state.previewPhase, 'idle');
check('preview/power-close-closes', previewClosed.state.powerOpen, false);
const previewToggledClosed = ll.togglePower(previewPower.state);
check('preview/power-toggle-phase', previewToggledClosed.state.previewPhase, 'idle');
check('preview/power-confirm-phase', ll.confirm(previewArmed, pl.confirm({ armed: 'reboot' })).state.previewPhase, 'idle');
const previewCard = ll.togglePower(typing.state).state;
check('preview/card-opens', previewCard.powerOpen, true);
check('preview/toggle-keeps-unlocked', ll.previewToggle(previewCard, 9).state.locked, false);
// While the real session is locked the preview is inert, so an in-flight check
// is not reset and its completion still unlocks.
const realChecking = ll.submit(locked.state, 'hunter2').state;
check('preview/toggle-inert-while-locked', ll.previewToggle(realChecking, 9), { state: realChecking, effects: [] });
check('preview/phase-inert-while-locked', ll.previewPhase(realChecking, 'failed', 9), { state: realChecking, effects: [] });
check('preview/locked-check-still-unlocks', ll.pamCompleted(ll.previewToggle(realChecking, 9).state, true).state.locked, false);
check('reduce/no-unauthenticated-unlock', ll.reduce(locked.state, { kind: 'unlock' }).state.locked, true);

// reduce() is the one entry the service dispatches through.
check('reduce/lock', ll.reduce(IDLE, { kind: 'lock', now: 7 }).state.lockedAt, 7);
check('reduce/submit', ll.reduce(locked.state, { kind: 'submit', password: 'pw' }).state.authState, 'checking');
check('reduce/unknown', ll.reduce(IDLE, { kind: 'nope' }).effects, []);

// --- the selectors, unchanged ---
const VIEW = { fieldLength: 0, authState: 'idle', powerOpen: false, msSinceLastKey: 6000, idleMs: 6000 };

check('reveal/idle-hidden', ll.revealShown(VIEW), false);
check('reveal/just-typed', ll.revealShown({ ...VIEW, msSinceLastKey: 0 }), true);
check('reveal/before-boundary', ll.revealShown({ ...VIEW, msSinceLastKey: 5999 }), true);
check('reveal/at-boundary', ll.revealShown({ ...VIEW, msSinceLastKey: 6000 }), false);
check('reveal/nonempty-holds', ll.revealShown({ ...VIEW, fieldLength: 3, msSinceLastKey: 99999 }), true);
check('reveal/negative-elapsed', ll.revealShown({ ...VIEW, msSinceLastKey: -1 }), false);
check('reveal/checking', ll.revealShown({ ...VIEW, authState: 'checking', msSinceLastKey: 99999 }), true);
check('reveal/failed', ll.revealShown({ ...VIEW, authState: 'failed', msSinceLastKey: 99999 }), true);
check('reveal/power-hides-typing', ll.revealShown({ ...VIEW, powerOpen: true, fieldLength: 2, msSinceLastKey: 0 }), false);
check('reveal/power-hides-auth', ll.revealShown({ ...VIEW, powerOpen: true, authState: 'checking' }), false);

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
