pragma Singleton

import QtQuick
import Quickshell
import qs.services
import "PerformanceLogic.js" as PerformanceLogic

Singleton {
    id: root

    readonly property int historySeconds: 300
    readonly property real sampleSeconds: SystemMonitor.pollMs / 1000
    readonly property int capacity: PerformanceLogic.windowSamples(root.historySeconds, root.sampleSeconds)

    property var rings: PerformanceLogic.emptyRings()

    Connections {
        target: SystemMonitor

        function onSampled(): void {
            root.record();
        }
    }

    function record(): void {
        const sample = {};
        sample["cpu"] = SystemMonitor.cpuUsagePercent;
        sample["cpuPeak"] = SystemMonitor.cpuPeakPercent;
        sample["cpuTemp"] = SystemMonitor.cpuTempC;
        sample["gpu"] = SystemMonitor.gpuUsagePercent;
        sample["gpuTemp"] = SystemMonitor.gpuTempC;
        sample["ram"] = SystemMonitor.ramUsagePercent;
        sample["ramUsed"] = SystemMonitor.ramUsedBytes;
        sample["diskRead"] = SystemMonitor.diskReadBytesPerSec;
        sample["diskWrite"] = SystemMonitor.diskWriteBytesPerSec;
        sample["netRx"] = SystemMonitor.netRxBytesPerSec;
        sample["netTx"] = SystemMonitor.netTxBytesPerSec;
        root.rings = PerformanceLogic.appendSample(root.rings, sample, root.capacity);
    }

    function windowSamples(windowSeconds: int): int {
        return PerformanceLogic.windowSamples(windowSeconds, root.sampleSeconds);
    }

    function hasSampleAt(age: int): bool {
        return PerformanceLogic.hasSampleAt(root.rings, age);
    }

    function readingAt(age: int): var {
        return PerformanceLogic.readingAt(root.rings, age);
    }

    function windowPeak(keys, samples: int): real {
        return PerformanceLogic.windowPeak(root.rings, keys, samples);
    }

    function autoScale(peak: real, minScale: real): real {
        return PerformanceLogic.autoScale(peak, minScale);
    }

    function scrubAge(fraction: real, samples: int): int {
        return PerformanceLogic.scrubAge(fraction, samples);
    }

    function agoText(seconds: int): string {
        return PerformanceLogic.agoText(seconds);
    }

    function tempLevel(celsius: real): string {
        return PerformanceLogic.tempLevel(celsius);
    }

    function tempText(celsius: real): string {
        return PerformanceLogic.tempText(celsius);
    }
}
