.pragma library

// Pure rules for the power menu, the shell's most destructive path: the action
// table, the per-context rows the two cards draw, the key routing, the arm
// state machine, and the card strings. PowerService and LockService keep the
// Process and the panel state, and delegate every decision here, so the gate
// runs this file under node instead of grepping a service for command strings.
// The argv values are data: nothing in this file starts a process.

// table() rebuilds the descriptors on each call because the labels go through
// qsTr, which a .pragma library resolves at call time rather than at load.
// glyph is an Icons.qml property name; the service maps it through Icons, since
// a pure module cannot import the singleton.
function table() {
    return [
        { id: "lock", label: qsTr("Lock"), dangerous: false, lock: true, argv: null, glyph: "lock" },
        { id: "suspend", label: qsTr("Suspend"), dangerous: false, argv: ["sh", "-c", "playerctl pause -a 2>/dev/null; mpc -q pause 2>/dev/null; systemctl suspend"], glyph: "powerSleep" },
        { id: "logout", label: qsTr("Logout"), dangerous: false, argv: ["hyprctl", "dispatch", "exit"], glyph: "logout" },
        { id: "reboot", label: qsTr("Reboot"), dangerous: true, argv: ["systemctl", "reboot"], glyph: "restart" },
        { id: "shutdown", label: qsTr("Shutdown"), dangerous: true, argv: ["systemctl", "poweroff"], glyph: "power" },
        { id: "winboot", label: qsTr("Reboot to Windows"), dangerous: true, argv: ["sh", "-c", "pkexec efibootmgr -n 0000 && systemctl reboot"], glyph: "windows" }
    ];
}

// No row means every action. The lock card draws the safe subset from ADR 0022
// and derives its own 1..3 hints from the row order.
const CONTEXTS = {
    bar: [],
    lock: ["suspend", "reboot", "shutdown"]
};

const CONFIRM_KEYS = ["Return", "Enter"];

// rows() is the card's model: hint is the row's position in its context, so the
// drawn hint and the routed key come from the same number.
function rows(context) {
    if (!Object.prototype.hasOwnProperty.call(CONTEXTS, context))
        return [];
    const only = CONTEXTS[context];
    const entries = table();
    const out = [];
    for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        if (only.length > 0 && only.indexOf(entry.id) === -1)
            continue;
        out.push({
            id: entry.id,
            label: entry.label,
            dangerous: entry.dangerous === true,
            argv: entry.argv,
            glyph: entry.glyph,
            hint: String(out.length + 1)
        });
    }
    return out;
}

function confirmKeys() {
    return CONFIRM_KEYS.slice();
}

function route(context, armed, key) {
    if (key === "Escape")
        return armed === "" ? { kind: "close" } : { kind: "disarm" };
    if (CONFIRM_KEYS.indexOf(key) !== -1)
        return armed === "" ? { kind: "none" } : { kind: "confirm" };
    const entries = rows(context);
    for (let i = 0; i < entries.length; i++) {
        if (entries[i].hint === key)
            return { kind: "arm", id: entries[i].id };
    }
    return { kind: "none" };
}

function header(host, uptime) {
    const hostName = host || "";
    const up = uptime || "";
    if (hostName !== "" && up !== "")
        return qsTr("%1 · up %2").arg(hostName).arg(up);
    return hostName !== "" ? hostName : up;
}

function question(armed) {
    if (armed === "")
        return qsTr("Pick an action.");
    return qsTr("%1? Confirm to run.").arg(label(armed));
}

function find(id) {
    const entries = table();
    for (let i = 0; i < entries.length; i++) {
        if (entries[i].id === id)
            return entries[i];
    }
    return null;
}

function label(id) {
    const entry = find(id);
    return entry ? entry.label : "";
}

function dangerous(id) {
    const entry = find(id);
    return entry ? entry.dangerous === true : false;
}

function argv(id) {
    const entry = find(id);
    return entry ? entry.argv : null;
}

// The armed action is the whole state; the service keeps everything else.
function isArmed(state, id) {
    return state.armed === id;
}

// Lock asks the shell's lock service to lock and never arms, clearing any other
// armed action. Every other id arms; pressing the armed id again leaves it
// armed (confirmation is a distinct gesture through confirm()), and pressing a
// different id re-arms. run is the argv to start now, or null; lock is true
// when the caller should lock the session instead.
function press(state, id) {
    if (id === "lock")
        return { state: { armed: "" }, run: null, lock: true };
    return { state: { armed: id }, run: null };
}

// Confirm runs the armed action's argv and disarms. With nothing armed it is
// inert; an unknown armed id has no argv to run, so it stays armed untouched.
function confirm(state) {
    if (state.armed === "")
        return { state: { armed: "" }, run: null };
    const command = argv(state.armed);
    if (command === null)
        return { state: { armed: state.armed }, run: null };
    return { state: { armed: "" }, run: command };
}

function cancel(state) {
    return { armed: "" };
}
