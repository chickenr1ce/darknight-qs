pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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

    function formatKernel(release: string): string {
        if (release === "")
            return "";
        const suffix = release.indexOf("-");
        return suffix >= 0 ? release.substring(0, suffix) : release;
    }

    function formatShell(path: string): string {
        if (path === "")
            return "";
        const slash = path.lastIndexOf("/");
        return slash >= 0 ? path.substring(slash + 1) : path;
    }

    function formatPackages(count: int): string {
        if (count <= 0)
            return "";
        if (count < 1000)
            return `${count}`;
        return (count / 1000).toFixed(1) + "k";
    }

    function formatUptime(ms: real): string {
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
}
