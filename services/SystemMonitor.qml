pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "SystemLogic.js" as SystemLogic

Singleton {
    id: root

    readonly property int pollMs: 2000
    readonly property string gpuBusyPath: "/sys/class/drm/card1/device/gpu_busy_percent"
    readonly property string cpuTempPath: "/sys/class/hwmon/hwmon2/temp1_input"
    readonly property string gpuTempPath: "/sys/class/hwmon/hwmon1/temp1_input"

    property real cpuUsagePercent: 0
    property real cpuPeakPercent: 0
    property real ramUsagePercent: 0
    property real ramUsedBytes: 0
    property real ramTotalBytes: 0
    property real gpuUsagePercent: 0
    property real cpuTempC: 0
    property real gpuTempC: 0
    property real netRxBytesPerSec: 0
    property real netTxBytesPerSec: 0
    property real diskReadBytesPerSec: 0
    property real diskWriteBytesPerSec: 0
    property real previousTotal: -1
    property real previousIdle: 0
    property var previousThreads: ({})
    property real previousRxBytes: -1
    property real previousTxBytes: -1
    property real previousDiskRead: -1
    property real previousDiskWritten: -1

    readonly property string ramUsedText: root.formatGib(root.ramUsedBytes) + "/" + root.formatGib(root.ramTotalBytes) + "G"
    readonly property string netRxText: root.formatRate(root.netRxBytesPerSec)
    readonly property string netTxText: root.formatRate(root.netTxBytesPerSec)

    signal sampled()

    FileView {
        id: idCpuStatFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const text = idCpuStatFile.text();
            root.applyThreadSamples(SystemLogic.parseThreadSamples(text));
            root.applyCpuSample(root.parseCpuSample(text));
        }
    }

    FileView {
        id: idDiskStatsFile

        path: "/proc/diskstats"
        printErrors: false
        onLoaded: root.applyDiskSample(SystemLogic.parseDiskSample(idDiskStatsFile.text()))
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
            idDiskStatsFile.reload();
            idRamInfoFile.reload();
            idGpuBusyFile.reload();
            idNetDevFile.reload();
            idCpuTempFile.reload();
            idGpuTempFile.reload();
        }
    }

    function parseCpuSample(text: string): var {
        return SystemLogic.parseCpuSample(text);
    }

    function applyCpuSample(sample): void {
        if (sample === null)
            return;
        const percent = SystemLogic.cpuPercent(root.previousTotal, root.previousIdle, sample);
        if (percent !== null)
            root.cpuUsagePercent = percent;
        root.previousTotal = sample.total;
        root.previousIdle = sample.idle;
        if (percent !== null)
            root.sampled();
    }

    function applyThreadSamples(samples): void {
        const peak = SystemLogic.peakThreadPercent(root.previousThreads, samples);
        if (peak !== null)
            root.cpuPeakPercent = peak;
        root.previousThreads = samples;
    }

    function applyDiskSample(sample): void {
        const seconds = root.pollMs / 1000;
        const read = SystemLogic.byteRate(root.previousDiskRead, sample.read, seconds);
        const written = SystemLogic.byteRate(root.previousDiskWritten, sample.written, seconds);
        if (read !== null)
            root.diskReadBytesPerSec = read;
        if (written !== null)
            root.diskWriteBytesPerSec = written;
        root.previousDiskRead = sample.read;
        root.previousDiskWritten = sample.written;
    }

    function parseRamPercent(text: string): real {
        return SystemLogic.parseRamPercent(text);
    }

    function parseRamSample(text: string): var {
        return SystemLogic.parseRamSample(text);
    }

    function applyRamSample(text: string): void {
        const sample = root.parseRamSample(text);
        root.ramUsedBytes = sample.usedBytes;
        root.ramTotalBytes = sample.totalBytes;
        root.ramUsagePercent = root.parseRamPercent(text);
    }

    function parseTemp(text: string): real {
        return SystemLogic.parseTemp(text);
    }

    function parsePercent(text: string): real {
        return SystemLogic.parsePercent(text);
    }

    function parseNetSample(text: string): var {
        return SystemLogic.parseNetSample(text);
    }

    function applyNetSample(sample): void {
        const rates = SystemLogic.netRates(root.previousRxBytes, root.previousTxBytes, sample, root.pollMs / 1000);
        if (rates !== null) {
            root.netRxBytesPerSec = rates.rx;
            root.netTxBytesPerSec = rates.tx;
        }
        root.previousRxBytes = sample.rx;
        root.previousTxBytes = sample.tx;
    }

    function formatGib(bytes: real): string {
        return SystemLogic.formatGib(bytes);
    }

    function formatRate(bytesPerSec: real): string {
        return SystemLogic.formatRate(bytesPerSec);
    }
}
