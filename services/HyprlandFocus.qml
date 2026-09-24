pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property var requestQueue: []
    property var pendingTokens: []
    property int retryLeft: 0
    property string activeAddress: ""
    property bool snapshotPending: false
    property var dispatchImpl: null

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

    function keysFor(rawTokens) {
        const keys = [];
        for (let i = 0; i < rawTokens.length; i++) {
            const token = String(rawTokens[i] ?? "").toLowerCase().trim();
            if (!token)
                continue;
            const base = token.split(/[^a-z0-9]+/)[0];
            if (base && !(keys.includes(base)))
                keys.push(base);
        }
        return keys;
    }

    function addressFor(keys) {
        const toplevels = Hyprland.toplevels?.values ?? [];
        const candidates = [];
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const ipc = toplevel.lastIpcObject ?? {};
            const classSegments = String(ipc["class"] ?? "").toLowerCase().split(/[^a-z0-9]+/);
            const initialSegments = String(ipc["initialClass"] ?? "").toLowerCase().split(/[^a-z0-9]+/);
            for (let k = 0; k < keys.length; k++) {
                if (classSegments.includes(keys[k]) || initialSegments.includes(keys[k])) {
                    candidates.push(toplevel);
                    break;
                }
            }
        }
        if (candidates.length === 0)
            return "";
        let target = candidates[0];
        let foundTitleMatch = false;
        for (let i = 0; i < candidates.length && !foundTitleMatch; i++) {
            const titleIpc = candidates[i].lastIpcObject ?? {};
            const windowTitle = String(titleIpc["title"] ?? "").toLowerCase();
            for (let k = 0; k < keys.length; k++) {
                if (keys[k].length >= 3 && windowTitle.includes(keys[k])) {
                    target = candidates[i];
                    foundTitleMatch = true;
                    break;
                }
            }
        }
        const rawAddress = String(target.address ?? "");
        if (!rawAddress)
            return "";
        const selectorAddress = rawAddress.startsWith("0x") ? rawAddress : "0x" + rawAddress;
        if (selectorAddress === "0x")
            return "";
        return selectorAddress;
    }

    function pumpQueue() {
        if (idCursorPosProcess.running || root.requestQueue.length === 0)
            return;
        root.activeAddress = root.requestQueue[0];
        root.requestQueue = root.requestQueue.slice(1);
        root.snapshotPending = true;
        idFocusWatchdog.restart();
        idCursorPosProcess.running = true;
    }

    function dispatch(payload: string) {
        if (root.dispatchImpl)
            root.dispatchImpl(payload);
        else
            Hyprland.dispatch(payload);
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
            if (!(root.activeAddress === ""))
                root.dispatch(`hl.dsp.focus({ window = "address:${root.activeAddress}" })`);
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
            const match = idCursorPosCollector.text.trim().match(/(-?\d+)\s*,\s*(-?\d+)/);
            root.dispatch(`hl.dsp.focus({ window = "address:${root.activeAddress}" })`);
            root.activeAddress = "";
            if (match)
                root.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
            root.pumpQueue();
        }
    }
}
