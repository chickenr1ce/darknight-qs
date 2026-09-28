pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int pollMs: 2000
    readonly property string gpuBusyPath: "/sys/class/drm/card1/device/gpu_busy_percent"
    readonly property string cpuTempPath: "/sys/class/hwmon/hwmon2/temp1_input"
    readonly property string gpuTempPath: "/sys/class/hwmon/hwmon1/temp1_input"

    property real cpuUsagePercent: 0
    property real ramUsagePercent: 0
    property real ramUsedBytes: 0
    property real ramTotalBytes: 0
    property real gpuUsagePercent: 0
    property real cpuTempC: 0
    property real gpuTempC: 0
    property real netRxBytesPerSec: 0
    property real netTxBytesPerSec: 0
    property real previousTotal: -1
    property real previousIdle: 0
    property real previousRxBytes: -1
    property real previousTxBytes: -1

    readonly property string ramUsedText: root.formatGib(root.ramUsedBytes) + "/" + root.formatGib(root.ramTotalBytes) + "G"
    readonly property string netRxText: root.formatRate(root.netRxBytesPerSec)
    readonly property string netTxText: root.formatRate(root.netTxBytesPerSec)

    FileView {
        id: idCpuStatFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: root.applyCpuSample(root.parseCpuSample(idCpuStatFile.text()))
    }

    FileView {
        id: idRamInfoFile

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.applyRamSample(idRamInfoFile.text())
    }

    FileView {
        id: idGpuBusyFile

        path: root.gpuBusyPath
        printErrors: false
        onLoaded: root.gpuUsagePercent = root.parsePercent(idGpuBusyFile.text())
    }

    FileView {
        id: idNetDevFile

        path: "/proc/net/dev"
        printErrors: false
        onLoaded: root.applyNetSample(root.parseNetSample(idNetDevFile.text()))
    }

    FileView {
        id: idCpuTempFile

        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTempC = root.parseTemp(idCpuTempFile.text())
    }

    FileView {
        id: idGpuTempFile

        path: root.gpuTempPath
        printErrors: false
        onLoaded: root.gpuTempC = root.parseTemp(idGpuTempFile.text())
    }

    Timer {
        id: idMonitorTimer

        interval: root.pollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            idCpuStatFile.reload();
            idRamInfoFile.reload();
            idGpuBusyFile.reload();
            idNetDevFile.reload();
            idCpuTempFile.reload();
            idGpuTempFile.reload();
        }
    }

    function parseCpuSample(text: string): var {
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

    function applyCpuSample(sample): void {
        if (sample === null)
            return;
        if (root.previousTotal >= 0) {
            const deltaTotal = sample.total - root.previousTotal;
            const deltaIdle = sample.idle - root.previousIdle;
            if (deltaTotal > 0)
                root.cpuUsagePercent = Math.max(0, Math.min(100, (1 - deltaIdle / deltaTotal) * 100));
        }
        root.previousTotal = sample.total;
        root.previousIdle = sample.idle;
    }

    function parseRamPercent(text: string): real {
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

    function parseRamSample(text: string): var {
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

    function applyRamSample(text: string): void {
        const sample = root.parseRamSample(text);
        root.ramUsedBytes = sample.usedBytes;
        root.ramTotalBytes = sample.totalBytes;
        root.ramUsagePercent = root.parseRamPercent(text);
    }

    function parseTemp(text: string): real {
        const value = parseFloat(String(text).trim());
        if (isNaN(value) || value <= 0)
            return 0;
        return value / 1000;
    }

    function parsePercent(text: string): real {
        const value = parseFloat(String(text).trim());
        if (isNaN(value))
            return 0;
        return Math.max(0, Math.min(100, value));
    }

    function parseNetSample(text: string): var {
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

    function applyNetSample(sample): void {
        const seconds = root.pollMs / 1000;
        if (root.previousRxBytes >= 0) {
            root.netRxBytesPerSec = Math.max(0, (sample.rx - root.previousRxBytes) / seconds);
            root.netTxBytesPerSec = Math.max(0, (sample.tx - root.previousTxBytes) / seconds);
        }
        root.previousRxBytes = sample.rx;
        root.previousTxBytes = sample.tx;
    }

    function formatGib(bytes: real): string {
        const gib = (Number(bytes) || 0) / (1024 * 1024 * 1024);
        return gib >= 10 ? Math.round(gib).toString() : gib.toFixed(1);
    }

    function formatRate(bytesPerSec: real): string {
        const value = Number(bytesPerSec) || 0;
        if (value >= 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(1) + " MB/s";
        if (value >= 1024)
            return Math.round(value / 1024) + " KB/s";
        return Math.round(value) + " B/s";
    }
}
