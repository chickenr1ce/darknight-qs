.pragma library

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

const POWER_HINTS = { suspend: "1", reboot: "2", shutdown: "3" };

function powerActions(table) {
    const out = [];
    for (let i = 0; i < table.length; i++) {
        const entry = table[i];
        if (POWER_HINTS[entry.id] === undefined)
            continue;
        out.push({
            id: entry.id,
            label: entry.label,
            dangerous: entry.dangerous === true,
            argv: entry.argv,
            hint: POWER_HINTS[entry.id]
        });
    }
    return out;
}

function powerActionFor(actions, key) {
    for (let i = 0; i < actions.length; i++) {
        if (actions[i].hint === key)
            return actions[i].id;
    }
    return "";
}

function powerRoute(actions, armed, key) {
    if (key === "Escape")
        return armed === "" ? { kind: "close" } : { kind: "disarm" };
    if (key === "Return" || key === "Enter")
        return armed === "" ? { kind: "none" } : { kind: "confirm" };
    const id = powerActionFor(actions, key);
    return id === "" ? { kind: "none" } : { kind: "arm", id: id };
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
