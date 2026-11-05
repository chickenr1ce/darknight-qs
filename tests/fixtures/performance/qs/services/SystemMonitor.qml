pragma Singleton

import QtQuick
import "../../../../../services/SystemLogic.js" as SystemLogic

// The reading surface PerformanceHistory records from, driven by the test. The
// real service polls /proc; its parsers run under node in scripts/test-performance.sh.
QtObject {
    id: root

    readonly property int pollMs: 2000
    property real cpuUsagePercent: 0
    property real cpuPeakPercent: 0
    property real cpuTempC: 0
    property real gpuUsagePercent: 0
    property real gpuTempC: 0
    property real ramUsagePercent: 0
    property real ramUsedBytes: 0
    readonly property real ramTotalBytes: 34359738368
    property real diskReadBytesPerSec: 0
    property real diskWriteBytesPerSec: 0
    property real netRxBytesPerSec: 0
    property real netTxBytesPerSec: 0

    signal sampled()

    function formatGib(bytes: real): string {
        return SystemLogic.formatGib(bytes);
    }

    function formatRate(bytesPerSec: real): string {
        return SystemLogic.formatRate(bytesPerSec);
    }
}
