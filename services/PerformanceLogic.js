.pragma library

// Pure history and formatting for PerformanceHistory and the dashboard's
// Performance tab. A window of N seconds holds N / sampleSeconds + 1 samples,
// so its oldest sample sits exactly N seconds behind the newest one.

const RING_KEYS = ["cpu", "cpuPeak", "cpuTemp", "gpu", "gpuTemp", "ram", "ramUsed", "diskRead", "diskWrite", "netRx", "netTx"];

function emptyRings() {
    const rings = {};
    for (const key of RING_KEYS)
        rings[key] = [];
    return rings;
}

// appendSample returns new rings, so a binding on the rings refreshes without a
// separate revision counter.
function appendSample(rings, sample, capacity) {
    const next = {};
    for (const key of RING_KEYS) {
        const ring = rings[key].slice(Math.max(0, rings[key].length + 1 - capacity));
        ring.push(Number(sample[key]) || 0);
        next[key] = ring;
    }
    return next;
}

function windowSamples(windowSeconds, sampleSeconds) {
    return Math.round(windowSeconds / sampleSeconds) + 1;
}

function hasSampleAt(rings, age) {
    return age >= 0 && age < rings.cpu.length;
}

// readingAt returns the values recorded `age` samples ago, zeros when the
// history does not reach that far back.
function readingAt(rings, age) {
    const reading = {};
    for (const key of RING_KEYS) {
        const ring = rings[key];
        reading[key] = hasSampleAt(rings, age) ? ring[ring.length - 1 - age] : 0;
    }
    return reading;
}

function windowPeak(rings, keys, samples) {
    let peak = 0;
    for (const key of keys) {
        const ring = rings[key];
        for (let i = Math.max(0, ring.length - samples); i < ring.length; i++)
            peak = Math.max(peak, ring[i]);
    }
    return peak;
}

function autoScale(peak, minScale) {
    return Math.max(minScale, peak * 1.1);
}

// scrubAge maps a pointer fraction across the plot (0 oldest, 1 newest) to a
// sample age. A negative fraction means no pointer, and answers -1.
function scrubAge(fraction, samples) {
    if (fraction < 0)
        return -1;
    return Math.round((1 - Math.min(1, fraction)) * (samples - 1));
}

function agoText(seconds) {
    if (seconds <= 0)
        return qsTr("now");
    if (seconds < 60)
        return "-" + seconds + "s";
    const minutes = Math.floor(seconds / 60);
    const rest = seconds % 60;
    return rest === 0 ? "-" + minutes + "m" : "-" + minutes + "m " + rest + "s";
}

function tempLevel(celsius) {
    return celsius >= 85 ? "danger" : (celsius >= 75 ? "warning" : "normal");
}

// A theme's danger and warning tokens may be plain greys, so a hot reading says
// so in words too. An unreadable sensor reports 0 and shows nothing.
function tempText(celsius) {
    if (!(celsius > 0))
        return "";
    const rounded = Math.round(celsius);
    const level = tempLevel(celsius);
    if (level === "danger")
        return qsTr("Hot %1°C").arg(rounded);
    if (level === "warning")
        return qsTr("Warm %1°C").arg(rounded);
    return qsTr("%1°C").arg(rounded);
}
