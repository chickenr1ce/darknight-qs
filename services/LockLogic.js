.pragma library

// The lock session (ADR 0022) as one plain state value plus pure transitions.
// Every event returns { state, effects }. LockService owns the state, applies
// the effects through its PAM, preview, timer and process adapters, and keeps
// its public functions as one-line delegates, so the gate drives the rules
// under node instead of grepping the service for binding text.

const PHASES = ["idle", "typing", "checking", "failed", "power"];

function initialState() {
    return {
        locked: false,
        lockedAt: 0,
        authState: "idle",
        attempts: 0,
        pamMessage: "",
        pamMessageIsError: false,
        pamAnswered: false,
        powerOpen: false,
        powerArmed: "",
        previewOpen: false,
        previewPhase: "idle"
    };
}

function merge(state, changes) {
    const out = {};
    for (const key in state)
        out[key] = state[key];
    for (const key in changes)
        out[key] = changes[key];
    return out;
}

function outcome(state, effects) {
    return { state: state, effects: effects || [] };
}

function active(state) {
    return state.locked || state.previewOpen;
}

function canSubmit(state, password) {
    if (password === "")
        return false;
    if (state.authState === "checking")
        return false;
    if (state.powerOpen)
        return false;
    return active(state);
}

function lock(state, now) {
    if (state.locked)
        return outcome(state);
    const fresh = merge(initialState(), {
        locked: true,
        lockedAt: typeof now === "number" ? now : 0
    });
    return outcome(fresh, [{ kind: "pamReset" }, { kind: "stopFailureTimer" }]);
}

function unlock(state) {
    return outcome(initialState(), [{ kind: "pamReset" }, { kind: "stopFailureTimer" }]);
}

function submit(state, password) {
    if (!canSubmit(state, password))
        return outcome(state);
    const checking = merge(state, {
        authState: "checking",
        pamMessage: "",
        pamMessageIsError: false,
        pamAnswered: false
    });
    return outcome(checking, [{ kind: "pamStart", password: password }]);
}

// One attempt answers exactly one PAM prompt. A second responseRequired prompt
// within the same attempt asks for a secret the card has no field for, so the
// attempt fails and the conversation is aborted. Answering "" would let PAM
// reach its own conclusion and hide why the unlock did not happen.
function pamPrompt(state) {
    if (state.authState !== "checking")
        return outcome(state);
    if (!state.pamAnswered)
        return outcome(merge(state, { pamAnswered: true }), [{ kind: "pamRespond" }]);
    const failed = merge(state, {
        authState: "failed",
        attempts: state.attempts + 1,
        pamAnswered: false,
        pamMessage: qsTr("Unsupported authentication prompt"),
        pamMessageIsError: true
    });
    return outcome(failed, [{ kind: "pamAbort" }, { kind: "restartFailureTimer" }]);
}

function pamMessage(state, text, isError) {
    return outcome(merge(state, { pamMessage: text, pamMessageIsError: isError === true }));
}

function pamCompleted(state, success) {
    if (!active(state) || state.authState !== "checking")
        return outcome(state, [{ kind: "pamReset" }]);
    if (success === true)
        return unlock(state);
    const failed = merge(state, {
        authState: "failed",
        attempts: state.attempts + 1,
        pamAnswered: false
    });
    return outcome(failed, [{ kind: "pamReset" }, { kind: "restartFailureTimer" }]);
}

function startFailed(state) {
    if (state.authState !== "checking")
        return outcome(state);
    const failed = merge(state, {
        authState: "failed",
        attempts: state.attempts + 1,
        pamAnswered: false
    });
    return outcome(failed, [{ kind: "pamReset" }, { kind: "restartFailureTimer" }]);
}

function failureReset(state) {
    if (!active(state) || state.authState !== "failed")
        return outcome(state);
    const idle = merge(state, { authState: "idle", pamMessage: "", pamMessageIsError: false });
    return outcome(idle, [{ kind: "stopFailureTimer" }]);
}

function togglePower(state) {
    if (state.powerOpen)
        return closePower(state);
    return outcome(merge(state, { powerOpen: true, powerArmed: "" }));
}

// Closing the card also drops the dev preview back to its idle phase: the power
// phase describes an open card, and a stale phase makes `lock status` disagree
// with the surface the preview is drawing.
function closePower(state) {
    return outcome(merge(state, {
        powerOpen: false,
        powerArmed: "",
        previewPhase: state.previewOpen ? "idle" : state.previewPhase
    }));
}

function arm(state, armed) {
    if (armed === state.powerArmed)
        return outcome(state);
    return outcome(merge(state, { powerArmed: armed }));
}

// resolution is the PowerLogic.confirm({ armed }) result for the current arm;
// it carries the argv. The lock screen never runs a command outside a locked,
// non-preview session, so a confirm in the dev preview only closes the card.
function confirm(state, resolution) {
    if (!resolution)
        return closePower(state);
    const closed = merge(state, {
        powerOpen: false,
        powerArmed: resolution.state.armed,
        // Confirming in the dev preview closes the card without a run; the
        // phase must not stay on the card it just closed.
        previewPhase: state.previewOpen ? "idle" : state.previewPhase
    });
    if (!state.locked || state.previewOpen || resolution.run === null)
        return outcome(closed);
    return outcome(closed, [{ kind: "run", argv: resolution.run }]);
}

// route is the PowerLogic.route(context, armed, key) result.
function powerKey(state, route, resolution) {
    if (route.kind === "arm")
        return arm(state, route.id);
    if (route.kind === "disarm")
        return arm(state, "");
    if (route.kind === "close")
        return closePower(state);
    if (route.kind === "confirm")
        return confirm(state, resolution || null);
    return outcome(state);
}

// The dev preview runs the session's own transitions. The phase picks the real
// auth and power state the surface draws, and the service's adapter stubs auth.
// It never takes the session lock (ADR 0022), and it is inert while the real
// session is locked: opening it resets auth, so an in-flight PAM check would
// have its completion ignored and the user would have to retype.
function previewToggle(state, now) {
    if (state.locked)
        return outcome(state);
    if (state.previewOpen)
        return outcome(merge(initialState(), { locked: state.locked }));
    const open = merge(initialState(), {
        locked: state.locked,
        previewOpen: true,
        previewPhase: "idle",
        lockedAt: typeof now === "number" ? now : 0
    });
    return outcome(open);
}

function previewPhase(state, phase, now) {
    if (state.locked || PHASES.indexOf(phase) === -1)
        return outcome(state);
    const base = merge(initialState(), {
        locked: state.locked,
        previewOpen: true,
        previewPhase: phase,
        lockedAt: typeof now === "number" ? now : 0
    });
    if (phase === "checking")
        return outcome(merge(base, { authState: "checking", pamAnswered: true }));
    if (phase === "failed")
        return outcome(merge(base, { authState: "failed", attempts: 3 }));
    if (phase === "power")
        return outcome(merge(base, { powerOpen: true }));
    return outcome(base);
}

function reduce(state, event) {
    switch (event.kind) {
    case "lock":
        return lock(state, event.now);
    case "submit":
        return submit(state, event.password);
    case "pamPrompt":
        return pamPrompt(state);
    case "pamMessage":
        return pamMessage(state, event.text, event.isError);
    case "pamCompleted":
        return pamCompleted(state, event.success === true);
    case "startFailed":
        return startFailed(state);
    case "failureReset":
        return failureReset(state);
    case "togglePower":
        return togglePower(state);
    case "closePower":
        return closePower(state);
    case "armPower":
        return arm(state, event.armed);
    case "cancelPower":
        return arm(state, "");
    case "confirmPower":
        return confirm(state, event.resolution);
    case "key":
        return powerKey(state, event.route, event.resolution);
    case "previewToggle":
        return previewToggle(state, event.now);
    case "previewPhase":
        return previewPhase(state, event.phase, event.now);
    }
    return outcome(state);
}

function revealShown(input) {
    if (input.powerOpen)
        return false;
    if (input.authState !== "idle")
        return true;
    if (input.fieldLength > 0)
        return true;
    return input.msSinceLastKey >= 0 && input.msSinceLastKey < input.idleMs;
}

function messageText(authState, pamMessage, pamIsError, attempts) {
    if (authState === "checking")
        return qsTr("Checking…");
    if (authState === "failed") {
        const base = pamMessage !== "" ? pamMessage : qsTr("Wrong password");
        if (attempts > 1)
            return qsTr("%1 · %2 attempts").arg(base).arg(attempts);
        return base;
    }
    return pamMessage;
}

function messageIsError(authState, pamMessage, pamIsError) {
    if (authState === "checking")
        return false;
    if (authState === "failed")
        return true;
    return pamMessage !== "" && pamIsError === true;
}

function capsLockAfterKey(current, isCapsKey, isLetter, upper, shiftHeld) {
    if (isCapsKey)
        return !current;
    if (isLetter && !shiftHeld)
        return upper;
    return current;
}

function initial(name) {
    const text = (name || "").trim();
    if (text === "")
        return "?";
    return text.charAt(0).toUpperCase();
}
