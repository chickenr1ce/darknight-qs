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
