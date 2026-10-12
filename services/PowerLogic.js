.pragma library

// Pure rules for the power menu, the shell's most destructive path: the action
// table (id → label, dangerous, argv) and the arm/confirm state machine.
// PowerService keeps the Process and the panel visibility, and delegates every
// decision here, so the gate can run this file under node instead of grepping
// the service for command strings. The argv values are data: nothing in this
// file starts a process.

// table() rebuilds the descriptors on each call because the labels go through
// qsTr, which a .pragma library resolves at call time rather than at load.
function table() {
    return [
        { id: "lock", label: qsTr("Lock"), dangerous: false, argv: ["sh", "-c", "command -v hyprlock >/dev/null 2>&1 && exec hyprlock || { command -v betterlockscreen >/dev/null 2>&1 && exec betterlockscreen -l || exec i3lock; }"] },
        { id: "suspend", label: qsTr("Suspend"), dangerous: false, argv: ["sh", "-c", "playerctl pause -a 2>/dev/null; mpc -q pause 2>/dev/null; systemctl suspend"] },
        { id: "logout", label: qsTr("Logout"), dangerous: false, argv: ["hyprctl", "dispatch", "exit"] },
        { id: "reboot", label: qsTr("Reboot"), dangerous: true, argv: ["systemctl", "reboot"] },
        { id: "shutdown", label: qsTr("Shutdown"), dangerous: true, argv: ["systemctl", "poweroff"] },
        { id: "winboot", label: qsTr("Reboot to Windows"), dangerous: true, argv: ["sh", "-c", "pkexec efibootmgr -n 0000 && systemctl reboot"] }
    ];
}

function actions() {
    return table();
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

// Lock runs at once and never arms, clearing any other armed action. Every
// other id arms; pressing the armed id again leaves it armed (confirmation is
// a distinct gesture through confirm()), and pressing a different id re-arms.
// run is the argv to start now, or null.
function press(state, id) {
    if (id === "lock")
        return { state: { armed: "" }, run: argv("lock") };
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
