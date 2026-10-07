pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "SystemLogic.js" as SystemLogic

Singleton {
    id: root

    property string distro: ""
    property string compositor: ""
    property string kernel: ""
    property int packages: 0
    property real uptimeMs: 0

    readonly property string kernelText: root.formatKernel(root.kernel)
    readonly property string shellText: root.formatShell(Quickshell.env("SHELL"))
    readonly property string packagesText: root.formatPackages(root.packages)
    readonly property string uptimeText: root.formatUptime(root.uptimeMs)

    Process {
        id: idSystemInfoProcess

        command: ["fastfetch", "-s", "OS:WM:Kernel:Packages:Uptime", "--logo", "none", "--format", "json"]
        stdout: idSystemInfoCollector
    }

    StdioCollector {
        id: idSystemInfoCollector

        onStreamFinished: root.applyFastfetch(idSystemInfoCollector.text)
    }

    function refresh(): void {
        if (idSystemInfoProcess.running)
            return;
        idSystemInfoProcess.running = true;
    }

    function applyFastfetch(text: string): void {
        const parsed = root.parseFastfetch(text);
        root.distro = parsed.distro;
        root.compositor = parsed.compositor;
        root.kernel = parsed.kernel;
        root.packages = parsed.packages;
        root.uptimeMs = parsed.uptimeMs;
    }

    function parseFastfetch(text: string): var {
        return SystemLogic.parseFastfetch(text);
    }

    function formatKernel(release: string): string {
        return SystemLogic.formatKernel(release);
    }

    function formatShell(path: string): string {
        return SystemLogic.formatShell(path);
    }

    function formatPackages(count: int): string {
        return SystemLogic.formatPackages(count);
    }

    function formatUptime(ms: real): string {
        return SystemLogic.formatUptime(ms);
    }
}
