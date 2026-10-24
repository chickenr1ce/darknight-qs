.pragma library

function copyOrder(order) {
    return { left: order.left.slice(), right: order.right.slice() };
}

function sameList(a, b) {
    if (!(a.length === b.length))
        return false;
    for (let i = 0; i < a.length; i++) {
        if (!(a[i] === b[i]))
            return false;
    }
    return true;
}

function sameOrder(a, b) {
    return sameList(a.left, b.left) && sameList(a.right, b.right);
}

function move(order, key, section, index) {
    const next = copyOrder(order);
    if (!(section === "left") && !(section === "right"))
        return next;
    if (next.left.indexOf(key) < 0 && next.right.indexOf(key) < 0)
        return next;
    const sections = ["left", "right"];
    for (let i = 0; i < sections.length; i++) {
        const at = next[sections[i]].indexOf(key);
        if (at >= 0)
            next[sections[i]].splice(at, 1);
    }
    const target = next[section];
    let at = Math.round(Number(index));
    if (isNaN(at))
        at = 0;
    at = Math.max(0, Math.min(target.length, at));
    target.splice(at, 0, key);
    return next;
}

function widthOf(widths, key) {
    const w = Number(widths[key]);
    return isFinite(w) ? w : 0;
}

function isHidden(visible, key) {
    return visible[key] === false;
}

function visibleKeys(keys, visible) {
    const out = [];
    for (let i = 0; i < keys.length; i++) {
        if (!isHidden(visible, keys[i]))
            out.push(keys[i]);
    }
    return out;
}

function positions(order, widths, visible, spacing, width) {
    const x = {};
    let leftEnd = 0;
    const left = visibleKeys(order.left, visible);
    for (let i = 0; i < left.length; i++) {
        x[left[i]] = Math.round(leftEnd);
        leftEnd += widthOf(widths, left[i]) + spacing;
    }
    const right = visibleKeys(order.right, visible);
    let rightStart = width;
    if (right.length > 0) {
        let span = 0;
        for (let i = 0; i < right.length; i++)
            span += widthOf(widths, right[i]) + spacing;
        rightStart = width - span;
        let cursor = rightStart + spacing;
        for (let i = 0; i < right.length; i++) {
            x[right[i]] = Math.round(cursor);
            cursor += widthOf(widths, right[i]) + spacing;
        }
    }
    return { x: x, leftEnd: Math.round(leftEnd), rightStart: Math.round(rightStart) };
}

function dragX(pointerX, itemWidth, barWidth) {
    const span = Math.max(0, Number(barWidth) - Number(itemWidth));
    const centered = Number(pointerX) - Number(itemWidth) / 2;
    if (!isFinite(centered))
        return 0;
    return Math.max(0, Math.min(span, centered));
}

function shouldCancelRelease(pointerY, barHeight, topMargin) {
    return Number(pointerY) > Number(topMargin) + 2 * Number(barHeight);
}

// --- press lifecycle --------------------------------------------------------
//
// The bar slot holds a passive DragHandler behind its module (ADR 0021), so
// the press belongs to the module and the slot only sees grab transitions. A
// passive grab starts the hold; the hold arms the reorder; an ungrab ends the
// press. BarSlot maps PointerDevice.GrabTransition onto these event names
// (a .pragma library cannot read the Qt enum) and applies the effects this
// returns, which keeps the whole hold policy here instead of in a gate copy.

var PRESS = "press";
var HOLD = "hold";
var DRAG_START = "drag-start";
var DRAG_END = "drag-end";
var RELEASE = "release";
var ABANDON = "abandon";
var OTHER = "other";

var EFFECT_START_HOLD = "start-hold";
var EFFECT_STOP_HOLD = "stop-hold";
var EFFECT_BEGIN_DRAG = "begin-drag";
var EFFECT_END_DRAG = "end-drag";
var EFFECT_CANCEL_DRAG = "cancel-drag";
var EFFECT_DISMISS_TRAY = "dismiss-tray";

function pressState() {
    return { pressed: false, armed: false, trayMenuOpenAtPress: false };
}

// UngrabPassive, CancelGrabPassive, UngrabExclusive and CancelGrabExclusive
// all end the press; BarSlot maps each of them onto RELEASE.
function isRelease(event) {
    return event === RELEASE;
}

// pressTransition(state, event, context) -> { state, effects }
//
// context carries what the state cannot: handlerActive (the DragHandler holds
// an exclusive grab, so the drag ends on DRAG_END rather than at the release),
// ownsTrayMenu (this module owns the tray menu, so its press must not dismiss
// it) and trayMenuVisible (snapshotted at the press).
function pressTransition(state, event, context) {
    const ctx = context || {};
    const next = {
        pressed: state.pressed === true,
        armed: state.armed === true,
        trayMenuOpenAtPress: state.trayMenuOpenAtPress === true
    };
    const effects = [];

    if (event === PRESS) {
        if (next.pressed)
            return { state: next, effects: effects };
        next.pressed = true;
        next.armed = false;
        next.trayMenuOpenAtPress = ctx.trayMenuVisible === true;
        effects.push(EFFECT_START_HOLD);
        return { state: next, effects: effects };
    }

    if (event === HOLD) {
        if (next.pressed && !next.armed) {
            next.armed = true;
            effects.push(EFFECT_BEGIN_DRAG);
        }
        return { state: next, effects: effects };
    }

    if (event === DRAG_START) {
        // The drag threshold was crossed before the hold elapsed: a twitchy
        // click, not a reorder, and the pending hold must not arm later.
        if (!next.armed)
            effects.push(EFFECT_STOP_HOLD);
        return { state: next, effects: effects };
    }

    if (event === DRAG_END) {
        if (next.armed) {
            next.armed = false;
            effects.push(EFFECT_END_DRAG);
        }
        return { state: next, effects: effects };
    }

    if (event === ABANDON) {
        effects.push(EFFECT_STOP_HOLD);
        if (next.armed) {
            next.armed = false;
            effects.push(EFFECT_CANCEL_DRAG);
        }
        next.pressed = false;
        next.trayMenuOpenAtPress = false;
        return { state: next, effects: effects };
    }

    if (isRelease(event)) {
        effects.push(EFFECT_STOP_HOLD);
        if (next.armed && ctx.handlerActive !== true) {
            next.armed = false;
            effects.push(EFFECT_END_DRAG);
        }
        // The bar-wide dismiss area defers its tray-menu dismiss to this
        // release; the tray's own module keeps its menu.
        if (!next.armed && next.trayMenuOpenAtPress && ctx.ownsTrayMenu !== true)
            effects.push(EFFECT_DISMISS_TRAY);
        next.pressed = false;
        next.trayMenuOpenAtPress = false;
        return { state: next, effects: effects };
    }

    return { state: next, effects: effects };
}

function dropTarget(order, widths, visible, spacing, width, draggedKey, pointerX) {
    const section = pointerX < width / 2 ? "left" : "right";
    const keys = order[section];
    let index = 0;
    if (section === "left") {
        let cursor = 0;
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            if (isHidden(visible, key)) {
                if (!(key === draggedKey) && pointerX > cursor)
                    index += 1;
                continue;
            }
            if (!(key === draggedKey) && pointerX > cursor + widthOf(widths, key) / 2)
                index += 1;
            cursor += widthOf(widths, key) + spacing;
        }
    } else {
        let span = 0;
        for (let i = 0; i < keys.length; i++) {
            if (!isHidden(visible, keys[i]))
                span += widthOf(widths, keys[i]) + spacing;
        }
        let cursor = width - span + spacing;
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            if (isHidden(visible, key)) {
                if (!(key === draggedKey) && pointerX > cursor)
                    index += 1;
                continue;
            }
            if (!(key === draggedKey) && pointerX > cursor + widthOf(widths, key) / 2)
                index += 1;
            cursor += widthOf(widths, key) + spacing;
        }
    }
    return { section: section, index: index };
}
