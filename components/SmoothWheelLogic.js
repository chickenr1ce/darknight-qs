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
