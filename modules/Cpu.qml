import QtQuick
import Quickshell.Io
import "../config"
import "../components"

// CPU usage from /proc/stat, polled every 2 s.
ModuleBox {
    id: root

    property real cpuUsagePercent: 0
    property var previousCpuSample: null

    Text {
        id: idCpuLabel

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: `${Math.round(root.cpuUsagePercent)}% `
    }

    Process {
        id: idCpuProcess

        command: ["bash", "-c", "grep '^cpu ' /proc/stat"]
        running: true

        stdout: StdioCollector {
            id: idCpuCollector
            onStreamFinished: {
                const fields = this.text.trim().split(/\s+/).slice(1).map(Number);
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
    }

    Timer {
        id: idCpuTimer

        interval: 2000
        running: true
        repeat: true
        onTriggered: idCpuProcess.running = true
    }
}
