import QtQuick
import Quickshell.Io
import qs.config
import qs.components

// CPU usage from /proc/stat, polled every 2 s.
ModuleBox {
    id: root

    property real cpuUsagePercent: 0
    property var previousCpuSample: null

    minWidth: 62 //sized for 2 digits + icon + padding

    Text {
        id: idCpuLabel

        color: Colors.lavender
        text: `${Math.round(root.cpuUsagePercent)}% `
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }

    // In-process read of /proc/stat (no shell spawned per poll).
    // procfs has no inotify support, so watchChanges cannot detect
    // updates; idCpuTimer drives reload() instead. preload must stay
    // enabled (default): with preload disabled nothing is ever loaded,
    // and reload() only re-reads an already-loaded file.
    FileView {
        id: idCpuStatFile

        path: "/proc/stat"

        onLoaded: root.updateCpuUsage(idCpuStatFile.text())
    }

    Timer {
        id: idCpuTimer

        interval: 2000
        running: true
        repeat: true
        onTriggered: idCpuStatFile.reload()
    }

    function updateCpuUsage(text: string): void {
        const fields = text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const idleTime = fields[3];
        const totalTime = fields.reduce((sum, value) => sum + value, 0);

        if (root.previousCpuSample !== null) {
            const deltaTotal = totalTime - root.previousCpuSample.totalTime;
            const deltaIdle = idleTime - root.previousCpuSample.idleTime;
            const usage = deltaTotal > 0 ? (1 - deltaIdle / deltaTotal) * 100 : 0;
            root.cpuUsagePercent = Math.max(0, Math.min(100, usage));
        }
        root.previousCpuSample = {
            totalTime: totalTime,
            idleTime: idleTime
        };
    }
}
