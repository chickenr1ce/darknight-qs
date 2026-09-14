pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification daemon for org.freedesktop.Notifications; DND records history but suppresses toasts.
// No "pragma ComponentBehavior: Bound": combined with pragma Singleton it crashes qmllint (silent exit 255).
Singleton {
    id: root

    property bool dndEnabled: false

    // A ListModel, not a reassigned JS array: row-level remove keeps delegates alive, so survivors keep decay state and never replay entrances.
    readonly property ListModel activeToasts: ListModel {}

    // The 720px canvas fits six cards; further arrivals expire the oldest instead of clipping off-canvas.
    readonly property int maxVisibleToasts: 6

    readonly property alias trackedNotifications: idDBusServer.trackedNotifications

    // ListModel mirror so views get stable row-level removals instead of snapshot-array reassignment.
    readonly property ListModel historyModel: ListModel {}

    property bool centerVisible: false

    // Press clears the grab before release toggles the bell, so a bell close would reopen without this window.
    property double centerLastOutsideCloseAt: 0

    // Stash: the cursorpos reply arrives after focusApp returns.
    property string pendingFocusAddress: ""

    function toggleCenter() {
        if (!root.centerVisible && Date.now() - root.centerLastOutsideCloseAt < 300)
            return;
        root.centerVisible = !root.centerVisible;
    }

    function closeCenterFromOutside() {
        if (root.centerVisible) {
            root.centerLastOutsideCloseAt = Date.now();
            root.centerVisible = false;
        }
    }

    readonly property int unreadCount: idDBusServer.trackedNotifications.values.length

    signal toastReceived(Notification notification)

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

    // .values is a snapshot copy, so dismissing mid-loop cannot shift indices.
    function dismissAll() {
        const tracked = idDBusServer.trackedNotifications.values;
        for (let i = tracked.length - 1; i >= 0; i--)
            tracked[i].dismiss();
    }

    function dismissGroup(appName: string) {
        const tracked = idDBusServer.trackedNotifications.values;
        for (let i = tracked.length - 1; i >= 0; i--) {
            if (tracked[i].appName === appName)
                tracked[i].dismiss();
        }
    }

    // Click-to-focus for toasts and center cards; same window matching as
    // Tray, so a notification finds its app window by app identity.
    function focusApp(notification: Notification) {
        if (!notification)
            return false;
        const rawTokens = [notification.appName, notification.desktopEntry];
        const keys = [];
        for (let i = 0; i < rawTokens.length; i++) {
            const token = String(rawTokens[i] ?? "").toLowerCase().trim();
            if (!token)
                continue;
            const base = token.split(/[^a-z0-9]+/)[0];
            if (base && !keys.includes(base))
                keys.push(base);
        }
        if (keys.length === 0)
            return false;
        const toplevels = Hyprland.toplevels?.values ?? [];
        // Gather matches first so title overlap beats list order (Steam owns two windows).
        const candidates = [];
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const ipc = toplevel.lastIpcObject ?? {};
            // Classes can be reverse-DNS, so match any segment.
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
            return false;
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
            return false;
        // HyprlandToplevel.address omits the 0x prefix, but the window selector needs it.
        const selectorAddress = rawAddress.startsWith("0x") ? rawAddress : "0x" + rawAddress;
        if (selectorAddress === "0x")
            return false;
        if (idCursorPosProcess.running) {
            // A previous click is still resolving; focus now and skip the restore.
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${selectorAddress}" })`);
        } else {
            root.pendingFocusAddress = selectorAddress;
            idCursorPosProcess.running = true;
        }
        return true;
    }

    // Hyprland warps to the focused window, so snapshot the click position and restore it after.
    Process {
        id: idCursorPosProcess

        command: ["hyprctl", "cursorpos"]
        stdout: idCursorPosCollector
    }

    StdioCollector {
        id: idCursorPosCollector

        onStreamFinished: {
            const match = idCursorPosCollector.text.trim().match(/(-?\d+)\s*,\s*(-?\d+)/);
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${root.pendingFocusAddress}" })`);
            if (match)
                Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
        }
    }

    // No ": void" return type: qmllint crashes (exit 255) on void returns in pragma Singleton files.
    function announceToast(notification: Notification) {
        // Overflow retires the toast visual only; expiring would close server-side and drop center history.
        if (root.activeToasts.count >= root.maxVisibleToasts)
            root.activeToasts.remove(0);
        root.activeToasts.append({ toast: notification });
        root.toastReceived(notification);
    }

    // Identity scan, not indexOf: ListModel.get returns a detached wrapper.
    function retireFrom(model: ListModel, role: string, notification: Notification) {
        for (let i = model.count - 1; i >= 0; i--) {
            if (model.get(i)[role] === notification) {
                model.remove(i);
                return;
            }
        }
    }

    function retireToast(notification: Notification) {
        root.retireFrom(root.activeToasts, "toast", notification);
    }

    function retireHistory(notification: Notification) {
        root.retireFrom(root.historyModel, "notification", notification);
    }

    NotificationServer {
        id: idDBusServer

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true;
            root.historyModel.append({ notification: notification });

            // Skip toasting reload-carried notifications and center-open arrivals (history only, so no backlog pops up on close).
            if (!notification.lastGeneration && !root.dndEnabled && !root.centerVisible)
                root.announceToast(notification);

            notification.closed.connect(() => {
                root.retireToast(notification);
                root.retireHistory(notification);
            });
        }
    }
}
