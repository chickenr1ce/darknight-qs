.pragma library

function restartDelayMs(attempts, baseMs, maxMs) {
    let n = Number(attempts);
    if (isNaN(n) || !isFinite(n))
        n = 0;
    n = Math.floor(n);
    if (n < 0)
        n = 0;
    // Cap the exponent so 2^n stays finite; the clamp below then wins.
    if (n > 30)
        n = 30;
    return Math.min(Number(maxMs), Number(baseMs) * Math.pow(2, n));
}
