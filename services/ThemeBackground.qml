import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "ThemeParsers.js" as ThemeParsers

QtObject {
    id: root

    property string theme: ""
    property string dir: ""
    property string memoryJson: "{}"

    readonly property var list: ThemeParsers.parseBackgroundList(root.listText, root.listDir)
    readonly property string currentName: ThemeParsers.currentBackgroundName(root.list, ThemeParsers.rememberedBackground(root.memoryJson, root.theme))
    readonly property string currentPath: {
        const entry = root.backgroundEntry(root.currentName);
        return entry !== null ? entry.path : "";
    }

    property string appliedPath: ""
    readonly property string scriptPath: Quickshell.shellDir + "/scripts/theme-backgrounds-scan.sh"
    property string listText: ""
    property string listDir: ""
    property string scanDir: ""

    property Process backgroundScanProcess: Process {
        id: idBackgroundScanProcess

        stdout: StdioCollector {
            id: idBackgroundScanCollector

            onStreamFinished: root.applyBackgroundScan(idBackgroundScanCollector.text)
        }
        onExited: code => idBackgroundScanRun.finished(code === 0)
    }

    property CoalescedRun backgroundScanRun: CoalescedRun {
        id: idBackgroundScanRun

        process: idBackgroundScanProcess

        starter: dir => root.startBackgroundScan(dir)
    }

    property Process backgroundApplyProcess: Process {
        id: idBackgroundApplyProcess

        onExited: code => root.backgroundApplyExited(code === 0)
    }

    property CoalescedRun backgroundApplyRun: CoalescedRun {
        id: idBackgroundApplyRun

        process: idBackgroundApplyProcess

        // HEAD held one 5-retry budget across picks until the next
        // refresh reset it; each new pick here requests afresh,
        // so it starts on a clean budget of 5.
        maxRetries: 5
        starter: root.startBackgroundApply
        onRetry: idBackgroundRetryTimer.restart()
    }

    property Timer backgroundRetryTimer: Timer {
        id: idBackgroundRetryTimer

        interval: 2000
        repeat: false
        onTriggered: idBackgroundApplyRun.release()
    }

    function refresh(dir: string): void {
        root.listText = "";
        root.listDir = "";
        idBackgroundApplyRun.resetAttempts();
        if (dir === "")
            return;
        idBackgroundScanRun.request(dir);
    }

    function applyCurrent(): void {
        root.apply(root.currentPath);
    }

    function select(file: string): string {
        const selection = ThemeParsers.selectBackground(root.memoryJson, root.theme, file, root.list);
        root.memoryJson = selection.memoryJson;
        root.apply(selection.path);
        return selection.message;
    }

    function backgroundEntry(name: string): var {
        return ThemeParsers.backgroundEntry(root.list, name);
    }

    function startBackgroundScan(dir: string): void {
        root.listText = "";
        root.listDir = "";
        root.scanDir = dir;
        idBackgroundScanProcess.exec(["sh", root.scriptPath, dir, String(ThemeParsers.backgroundMaxBytes())]);
    }

    function applyBackgroundScan(output: string): void {
        if (!ThemeParsers.backgroundScanCurrent(root.scanDir, root.dir))
            return;
        root.listDir = root.scanDir;
        root.listText = output;
        root.applyCurrent();
    }

    function apply(path: string): void {
        if (path === "")
            return;
        idBackgroundApplyRun.request(path);
    }

    function startBackgroundApply(path: string): bool {
        // Same pick again (a retry replay, or a drain of a queued no-op):
        // declaring no launch closes the run instead of leaving it
        // phantom-running.
        if (!ThemeParsers.backgroundApplyNeeded(path, root.appliedPath))
            return false;
        root.appliedPath = path;
        idBackgroundApplyProcess.exec(["awww", "img", path]);
        return true;
    }

    function backgroundApplyExited(ok: bool): void {
        // A success, or a failure with no background list to retry: close the
        // run ok so it does not arm futile retries.
        if (!ThemeParsers.backgroundApplyRetries(ok, root.currentPath)) {
            idBackgroundApplyRun.finished(true);
            return;
        }
        root.appliedPath = "";
        idBackgroundApplyRun.finished(false);
    }
}
