pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Focus-and-restore for Hyprland windows: match a window from caller tokens,
// snapshot the cursor, focus, then restore the cursor. Concurrent clicks
// queue behind the in-flight cursorpos read instead of skipping the restore.
// Override dispatchImpl in a harness to record calls instead of hitting IPC.
Singleton {
    id: root

    property var requestQueue: []
    property string activeAddress: ""
    property var dispatchImpl: null

    function focusByTokens(rawTokens): bool {
        const keys = root.keysFor(rawTokens);
        if (keys.length === 0)
            return false;
        const selectorAddress = root.addressFor(keys);
        if (selectorAddress === "")
            return false;
        root.requestQueue = root.requestQueue.concat([selectorAddress]);
        root.pumpQueue();
        return true;
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

    StdioCollector {
        id: idCursorPosCollector

        onStreamFinished: {
            const match = idCursorPosCollector.text.trim().match(/(-?\d+)\s*,\s*(-?\d+)/);
            root.dispatch(`hl.dsp.focus({ window = "address:${root.activeAddress}" })`);
            if (match)
                root.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
            root.pumpQueue();
        }
    }
}
