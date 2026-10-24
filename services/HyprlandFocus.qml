pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services
import "AppLogic.js" as AppLogic

Singleton {
    id: root

    property var requestQueue: []
    property var pendingTokens: []
    property int retryLeft: 0
    property string activeAddress: ""
    property bool snapshotPending: false

    function focusByTokens(rawTokens): bool {
        const keys = root.keysFor(rawTokens);
        if (keys.length === 0) {
            console.warn("HyprlandFocus: no keys in notification tokens, cannot focus");
            return false;
        }
        const selectorAddress = root.addressFor(keys);
        if (!(selectorAddress === "")) {
            root.requestQueue = root.requestQueue.concat([selectorAddress]);
            root.pumpQueue();
            return true;
        }
        if ((Hyprland.toplevels?.values ?? []).length > 0) {
            console.warn("HyprlandFocus: no window matches keys " + JSON.stringify(keys));
            return false;
        }
        // Toplevels populate asynchronously after load; wait for them instead
        // of dropping the request while the window list is still empty.
        root.pendingTokens = root.pendingTokens.concat([rawTokens]);
        root.retryLeft = Globals.focusRetryTicks;
        idFocusRetryTimer.restart();
        return true;
    }

    function focusAddress(rawAddress): bool {
        const address = HyprlandDispatch.selector(rawAddress);
        if (address === "")
            return false;
        root.requestQueue = root.requestQueue.concat([address]);
        root.pumpQueue();
        return true;
    }

    function flushPending() {
        const pending = root.pendingTokens;
        root.pendingTokens = [];
        for (let i = 0; i < pending.length; i++) {
            const keys = root.keysFor(pending[i]);
            const selectorAddress = root.addressFor(keys);
            if (selectorAddress === "") {
                console.warn("HyprlandFocus: no window matches keys " + JSON.stringify(keys));
                continue;
            }
            root.requestQueue = root.requestQueue.concat([selectorAddress]);
        }
        root.pumpQueue();
    }

    function normalizeUnique(rawValues) {
        const values = [];
        for (let i = 0; i < rawValues.length; i++) {
            const value = String(rawValues[i] ?? "").toLowerCase().trim();
            if (value !== "" && !(values.includes(value)))
                values.push(value);
        }
        return values;
    }

    function keysFor(rawTokens) {
        return root.normalizeUnique(rawTokens);
    }

    function classSources(toplevel) {
        const ipc = toplevel.lastIpcObject ?? {};
        const appId = toplevel.wayland ? toplevel.wayland.appId : "";
        return root.normalizeUnique([ipc["class"], ipc["initialClass"], appId]);
    }

    function classMatches(source, key) {
        return AppLogic.classMatches(source, key);
    }

    function addressFor(keys) {
        const toplevels = Hyprland.toplevels?.values ?? [];
        const candidates = [];
        for (let i = 0; i < toplevels.length; i++) {
            const sources = root.classSources(toplevels[i]);
            for (let k = 0; k < keys.length; k++) {
                let matched = false;
                for (let s = 0; s < sources.length && !matched; s++)
                    matched = root.classMatches(sources[s], keys[k]);
                if (matched) {
                    candidates.push(toplevels[i]);
                    break;
                }
            }
        }
        if (candidates.length === 0)
            return "";
        let target = candidates[0];
        let foundTitleMatch = false;
        for (let i = 0; i < candidates.length && !foundTitleMatch; i++) {
            const ipc = candidates[i].lastIpcObject ?? {};
            const ipcTitle = String(ipc["title"] ?? "");
            const windowTitle = (ipcTitle !== "" ? ipcTitle : String(candidates[i].title ?? "")).toLowerCase();
            for (let k = 0; k < keys.length; k++) {
                if (keys[k].length >= 3 && windowTitle.includes(keys[k])) {
                    target = candidates[i];
                    foundTitleMatch = true;
                    break;
                }
            }
        }
        return HyprlandDispatch.selector(target.address);
    }

    function pumpQueue() {
        if (idCursorPosProcess.running || root.requestQueue.length === 0) {
            idPanelSettleTimer.stop();
            return;
        }
        if (PanelGrab.closing) {
            idPanelSettleTimer.restart();
            return;
        }
        idPanelSettleTimer.stop();
        root.activeAddress = root.requestQueue[0];
        root.requestQueue = root.requestQueue.slice(1);
        root.snapshotPending = true;
        idFocusWatchdog.restart();
        idCursorPosProcess.running = true;
    }

    Process {
        id: idCursorPosProcess

        command: ["hyprctl", "cursorpos"]
        stdout: idCursorPosCollector
    }

    Timer {
        id: idFocusRetryTimer

        interval: Globals.focusRetryMs
        repeat: true
        onTriggered: {
            if ((Hyprland.toplevels?.values ?? []).length === 0 && root.retryLeft > 0) {
                root.retryLeft -= 1;
                return;
            }
            idFocusRetryTimer.stop();
            root.flushPending();
        }
    }

    Timer {
        id: idPanelSettleTimer

        interval: Globals.panelSettleMs
        repeat: true
        onTriggered: root.pumpQueue()
    }

    // If the cursor snapshot never completes, focus anyway without the
    // restore instead of dropping the request silently.
    Timer {
        id: idFocusWatchdog

        interval: Globals.focusWatchdogMs
        repeat: false
        onTriggered: {
            if (!root.snapshotPending)
                return;
            root.snapshotPending = false;
            console.warn("HyprlandFocus: cursor snapshot timed out, focusing without restore");
            idCursorPosProcess.running = false;
            HyprlandDispatch.focusWindow(root.activeAddress);
            root.activeAddress = "";
            root.pumpQueue();
        }
    }

    StdioCollector {
        id: idCursorPosCollector

        onStreamFinished: {
            idFocusWatchdog.stop();
            if (!root.snapshotPending)
                return;
            root.snapshotPending = false;
            const point = HyprlandDispatch.parseCursorPos(idCursorPosCollector.text);
            HyprlandDispatch.focusWindow(root.activeAddress);
            root.activeAddress = "";
            if (point)
                HyprlandDispatch.moveCursor(point.x, point.y);
            root.pumpQueue();
        }
    }
}
