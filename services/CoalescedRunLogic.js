.pragma library

// The "if busy, remember one request; on exit, drain it" Process lifecycle,
// shared by the services that used to hand-roll it with per-service flags.
// `running` in the state is the single source of truth for liveness, so the
// QML side must not overwrite it from the Process's own flag: a run whose
// starter was deferred one tick (the drain's Qt.callLater) still counts as
// running, and a request landing in that tick queues instead of starting.
// Every function takes the state in and returns the next state plus what the
// caller should do (start / retry), so the QML wrapper stays a one-line
// delegate.

function copy(state) {
    return {
        running: state.running,
        pending: state.pending,
        pendingArg: state.pendingArg,
        arg: state.arg,
        attempts: state.attempts
    };
}

function initial() {
    return { running: false, pending: false, pendingArg: undefined, arg: undefined, attempts: 0 };
}

// arg is the request payload the starter receives. opts.gated holds the
// request without starting it (readership gates): remember it, start nothing;
// the caller signals release later through release().
function request(state, arg, opts) {
    const next = copy(state);
    if (opts && opts.gated) {
        next.pending = true;
        next.pendingArg = arg;
        return { state: next, start: false, arg: undefined };
    }
    if (!next.running) {
        next.running = true;
        next.pending = false;
        next.pendingArg = undefined;
        next.arg = arg;
        next.attempts = 0;
        return { state: next, start: true, arg: arg };
    }
    next.pending = true;
    next.pendingArg = arg;
    return { state: next, start: false, arg: undefined };
}

// The run ended. If something is queued (a later request, an already
// deferred starter, or the replay of a bounded retry) it drains now and wins
// over a retry. Otherwise success clears the retry budget and a failure
// inside the budget signals a retry of the same arg; the caller arms its own
// delay and calls release().
function exited(state, ok, opts) {
    const next = copy(state);
    if (next.pending) {
        const drained = next.pendingArg;
        next.pending = false;
        next.pendingArg = undefined;
        next.arg = drained;
        next.attempts = 0;
        return { state: next, start: true, arg: drained, retry: false };
    }
    if (ok) {
        next.running = false;
        next.arg = undefined;
        return { state: next, start: false, arg: undefined, retry: false };
    }
    const cap = opts && Number.isFinite(opts.maxRetries) ? opts.maxRetries : 0;
    if (next.attempts < cap) {
        next.attempts = next.attempts + 1;
        next.pending = true;
        next.pendingArg = next.arg;
        // The retry waits for the caller's delay, so the slot is free until
        // release() takes it again.
        next.running = false;
        return { state: next, start: false, arg: undefined, retry: true };
    }
    next.running = false;
    next.arg = undefined;
    return { state: next, start: false, arg: undefined, retry: false };
}

// Start the held request now (ungate, or the retry delay fired). Does not
// touch the retry count: the retry must keep its budget, only a fresh
// request resets it.
function release(state) {
    const next = copy(state);
    if (next.running || !next.pending)
        return { state: next, start: false, arg: undefined };
    const arg = next.pendingArg;
    next.running = true;
    next.pending = false;
    next.pendingArg = undefined;
    next.arg = arg;
    return { state: next, start: true, arg: arg };
}

function resetAttempts(state) {
    const next = copy(state);
    next.attempts = 0;
    return next;
}
