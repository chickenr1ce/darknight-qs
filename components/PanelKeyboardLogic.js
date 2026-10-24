.pragma library

// The panel keyboard policy: which keyboard focus mode the layer asks for, when
// the keyboard latch takes, and when an Escape closes the panel. PanelShell owns
// the window, the Shortcut, and the two properties; every decision below is a
// pure function of what it passes in, so scripts/test-panel-logic.sh runs this
// file under node. The bug history is docs/dev/CODING_STANDARDS.md ("Hand the
// keyboard back once, with no key held, after the surface unmaps").

function copyState(state) {
    return {
        keyboardTaken: state.keyboardTaken === true,
        escapeArmed: state.escapeArmed === true
    };
}

// Hyprland won't hand an on-demand layer the keyboard on map while a pointer
// constraint is active (a fullscreen game locking the cursor), so the panel
// opens Exclusive to take it, then drops to on-demand: an exclusive layer gets
// all pointer input, deadening the bar and outside clicks. The focus grab keeps
// the keyboard on the panel after the drop.
//
// The closing slide keeps the keyboard too: handed back before the surface
// unmaps, it re-arms a game's pointer lock while the pointer still sits on the
// panel, and Hyprland, locked, never hit-tests it back to the game, so mouse
// look stays dead until a workspace switch. So a mapped panel is on-demand
// until it first takes the keyboard, exclusive while it holds it, and on-demand
// again through the closing slide; only an unmapped one is none.
function focusMode(visible, panelVisible, keyboardTaken) {
    if (!visible)
        return "none";
    if (!panelVisible || keyboardTaken)
        return "onDemand";
    return "exclusive";
}

// keyboardTaken latches once the panel first holds the keyboard after opening,
// so a later focus loss (a modal dialog) can't make it grab Exclusive again.
function windowActiveChanged(state, active, panelVisible) {
    const next = copyState(state);
    if (active && panelVisible)
        next.keyboardTaken = true;
    // The release went elsewhere; close rather than strand an armed panel.
    return { state: next, close: !active && next.escapeArmed };
}

// A reopen mid-slide may still hold the keyboard, and no active change would
// follow to drop the Exclusive grab, so the latch is rebuilt from the window
// state here. The arm never survives a visibility change.
function panelVisibleChanged(panelVisible, windowActive) {
    return {
        state: {
            keyboardTaken: panelVisible && windowActive,
            escapeArmed: false
        },
        close: false
    };
}

// An Escape press the panel itself takes only arms the close.
function escapePressed(state) {
    const next = copyState(state);
    next.escapeArmed = true;
    return { state: next, close: false };
}

// Closing on the press hands the keyboard back with Escape still held, and the
// enter event lists held keys: gamescope replays it as a fresh press, so CS2
// opens its pause menu. The press arms the close; this release fires it. An
// autorepeat release is not the release, and a release with nothing armed is
// somebody else's key: neither is accepted.
function keyReleased(state, isEscape, isAutoRepeat) {
    const next = copyState(state);
    if (!isEscape || isAutoRepeat || !next.escapeArmed)
        return { state: next, close: false };
    return { state: next, close: true, accepted: true };
}
