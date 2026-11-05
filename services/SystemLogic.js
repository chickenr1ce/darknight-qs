.pragma library

// Pure parsing plus formatting for SystemInfo and SystemMonitor. The services
// import this file and keep the property writes, the FileView and Process
// handling, and the previous-sample bookkeeping; everything that is a plain
// string or number transform lives here so the dashboard-data tests can run it
// under node.

function parseFastfetch(text) {
    const out = { distro: "", compositor: "", kernel: "", packages: 0, uptimeMs: 0 };
    let parsed = null;
    try
    {
        parsed = JSON.parse(text);
    }
    catch (e)
    {
        return out;
    }
    if (!parsed || !Array.isArray(parsed))
        return out;
    for (let i = 0; i < parsed.length; i++) {
        const entry = parsed[i];
        if (!entry || !entry.result)
            continue;
        if (entry.type === "OS")
            out.distro = entry.result.prettyName || entry.result.name || "";
        else if (entry.type === "WM")
            out.compositor = entry.result.prettyName || entry.result.processName || "";
        else if (entry.type === "Kernel")
            out.kernel = entry.result.release || "";
        else if (entry.type === "Packages")
            out.packages = Number(entry.result.all) || 0;
        else if (entry.type === "Uptime")
            out.uptimeMs = Number(entry.result.uptime) || 0;
    }
    return out;
}

function formatKernel(release) {
    if (release === "")
        return "";
    const suffix = release.indexOf("-");
    return suffix >= 0 ? release.substring(0, suffix) : release;
}

function formatShell(path) {
    if (path === "")
        return "";
    const slash = path.lastIndexOf("/");
    return slash >= 0 ? path.substring(slash + 1) : path;
}

function formatPackages(count) {
    if (count <= 0)
        return "";
    if (count < 1000)
        return `${count}`;
    return (count / 1000).toFixed(1) + "k";
}

function formatUptime(ms) {
    const totalMinutes = Math.floor((Number(ms) || 0) / 60000);
    if (totalMinutes <= 0)
        return "";
    const days = Math.floor(totalMinutes / 1440);
    const hours = Math.floor((totalMinutes % 1440) / 60);
    const minutes = totalMinutes % 60;
    if (days > 0)
        return `${days}d ${hours}h`;
    if (hours > 0)
        return `${hours}h ${minutes}m`;
    return `${minutes}m`;
}

function parseCpuSample(text) {
    const lines = String(text).split("\n");
    if (lines.length === 0)
        return null;
    const fields = lines[0].trim().split(/\s+/).slice(1).map(Number);
    if (fields.length < 4)
        return null;
    let total = 0;
    for (let i = 0; i < fields.length; i++) {
        if (!isNaN(fields[i]))
            total += fields[i];
    }
    const idle = fields[3] + (isNaN(fields[4]) ? 0 : fields[4]);
    const sample = {};
    sample["total"] = total;
    sample["idle"] = idle;
    return sample;
}

// cpuPercent returns the usage between two samples, or null when there is no
// previous sample or the counters did not advance. The caller keeps the
// previous-total/idle bookkeeping.
function cpuPercent(prevTotal, prevIdle, sample) {
    if (sample === null || !(prevTotal >= 0))
        return null;
    const deltaTotal = sample.total - prevTotal;
    if (!(deltaTotal > 0))
        return null;
    const deltaIdle = sample.idle - prevIdle;
    return Math.max(0, Math.min(100, (1 - deltaIdle / deltaTotal) * 100));
}

// parseThreadSamples reads the per-thread cpuN lines of /proc/stat, keyed by
// name so a thread that goes offline between samples is simply skipped.
function parseThreadSamples(text) {
    const samples = {};
    const lines = String(text).split("\n");
    for (let i = 0; i < lines.length; i++) {
        if (!/^cpu\d+\s/.test(lines[i]))
            continue;
        const name = lines[i].slice(0, lines[i].indexOf(" "));
        const sample = parseCpuSample(lines[i]);
        if (sample !== null)
            samples[name] = sample;
    }
    return samples;
}

// peakThreadPercent returns the busiest thread's usage between two samples, or
// null when no thread has a usable previous sample.
function peakThreadPercent(previous, samples) {
    let peak = null;
    for (const name in samples) {
        const before = previous[name];
        if (before === undefined)
            continue;
        const percent = cpuPercent(before.total, before.idle, samples[name]);
        if (percent !== null && (peak === null || percent > peak))
            peak = percent;
    }
    return peak;
}

function parseRamPercent(text) {
    let total = 0;
    let available = -1;
    const lines = String(text).split("\n");
    for (let i = 0; i < lines.length; i++) {
        const parts = lines[i].split(":");
        if (parts.length < 2)
            continue;
        const key = parts[0].trim();
        const value = parseInt(parts[1].trim(), 10);
        if (isNaN(value))
            continue;
        if (key === "MemTotal")
            total = value;
        else if (key === "MemAvailable")
            available = value;
    }
    if (!(total > 0) || available < 0)
        return 0;
    return Math.max(0, Math.min(100, (total - available) / total * 100));
}

function parseRamSample(text) {
    let total = 0;
    let available = -1;
    const lines = String(text).split("\n");
    for (let i = 0; i < lines.length; i++) {
        const parts = lines[i].split(":");
        if (parts.length < 2)
            continue;
        const key = parts[0].trim();
        const value = parseInt(parts[1].trim(), 10);
        if (isNaN(value))
            continue;
        if (key === "MemTotal")
            total = value;
        else if (key === "MemAvailable")
            available = value;
    }
    if (!(total > 0) || available < 0)
        return { usedBytes: 0, totalBytes: 0 };
    return { usedBytes: (total - available) * 1024, totalBytes: total * 1024 };
}

function parseTemp(text) {
    const value = parseFloat(String(text).trim());
    if (isNaN(value) || value <= 0)
        return 0;
    return value / 1000;
}

function parsePercent(text) {
    const value = parseFloat(String(text).trim());
    if (isNaN(value))
        return 0;
    return Math.max(0, Math.min(100, value));
}

function parseNetSample(text) {
    let rx = 0;
    let tx = 0;
    const lines = String(text).split("\n");
    for (let i = 0; i < lines.length; i++) {
        const colon = lines[i].indexOf(":");
        if (colon < 0)
            continue;
        const iface = lines[i].slice(0, colon).trim();
        if (iface === "" || iface === "lo")
            continue;
        const fields = lines[i].slice(colon + 1).trim().split(/\s+/);
        if (fields.length < 9)
            continue;
        rx += Number(fields[0]) || 0;
        tx += Number(fields[8]) || 0;
    }
    return { rx: rx, tx: tx };
}

// netRates returns the per-second byte rates between two samples, or null when
// there is no previous sample. The caller keeps the previous-rx/tx bookkeeping.
function netRates(prevRx, prevTx, sample, seconds) {
    if (!(prevRx >= 0))
        return null;
    return {
        rx: Math.max(0, (sample.rx - prevRx) / seconds),
        tx: Math.max(0, (sample.tx - prevTx) / seconds)
    };
}

// parseDiskSample sums the read and written bytes of whole disks in
// /proc/diskstats. Partitions, loop devices, and device-mapper volumes repeat
// bytes a whole disk already counts, so they are skipped.
function parseDiskSample(text) {
    let read = 0;
    let written = 0;
    const lines = String(text).split("\n");
    for (let i = 0; i < lines.length; i++) {
        const fields = lines[i].trim().split(/\s+/);
        if (fields.length < 10 || !/^(nvme\d+n\d+|mmcblk\d+|xvd[a-z]+|[shv]d[a-z]+)$/.test(fields[2]))
            continue;
        read += (Number(fields[5]) || 0) * 512;
        written += (Number(fields[9]) || 0) * 512;
    }
    return { read: read, written: written };
}

// byteRate returns the per-second rate between two counter readings, or null
// when there is no previous reading. A counter that went backwards reads as 0.
function byteRate(previous, current, seconds) {
    if (!(previous >= 0))
        return null;
    return Math.max(0, (current - previous) / seconds);
}

function formatGib(bytes) {
    const gib = (Number(bytes) || 0) / (1024 * 1024 * 1024);
    return gib >= 10 ? Math.round(gib).toString() : gib.toFixed(1);
}

function formatRate(bytesPerSec) {
    const value = Number(bytesPerSec) || 0;
    if (value >= 1024 * 1024)
        return (value / (1024 * 1024)).toFixed(1) + " MB/s";
    if (value >= 1024)
        return Math.round(value / 1024) + " KB/s";
    return Math.round(value) + " B/s";
}
