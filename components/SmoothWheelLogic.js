.pragma library

function clampTarget(originY, contentHeight, height, target) {
    const min = originY;
    const max = originY + Math.max(0, contentHeight - height);
    const value = Number(target);
    if (!isFinite(value))
        return min;
    return Math.min(Math.max(value, min), max);
}

function wheelTarget(current, angleDeltaY, step) {
    const direction = angleDeltaY > 0 ? -1 : 1;
    const from = Number(current);
    return (isFinite(from) ? from : 0) + direction * step;
}

function wheelStep(currentY, target, running, delta, step, minY, maxY) {
    const base = running ? Number(target) : Number(currentY);
    const from = isFinite(base) ? base : minY;
    const scaled = Number(step) * Math.abs(Number(delta)) / 120;
    const next = Math.min(Math.max(wheelTarget(from, delta, scaled), minY), maxY);
    return { target: next, moved: next !== from };
}

// Pick the scroll path by input source, not by whether a pixelDelta is
// present: Hyprland and Qt Wayland attach a small pixelDelta to ordinary
// mouse-wheel events too, and the old pixel-first rule threw away the
// stepped angleDelta (a mouse notch moved 15 px and coalesced notches were
// lost). A touchpad takes the 1:1 pixel path; anything else takes the
// stepped angle path whenever there is an angle to step, and only falls
// back to pixels when the angle is zero. "none" means the event carries no
// usable delta.
function wheelMode(angleDelta, pixelDelta, isTouchpad) {
    const angle = Number(angleDelta);
    const pixel = Number(pixelDelta);
    const hasAngle = isFinite(angle) && angle !== 0;
    const hasPixel = isFinite(pixel) && pixel !== 0;
    if (isTouchpad === true)
        return hasPixel ? "pixel" : (hasAngle ? "angle" : "none");
    if (hasAngle)
        return "angle";
    if (hasPixel)
        return "pixel";
    return "none";
}
