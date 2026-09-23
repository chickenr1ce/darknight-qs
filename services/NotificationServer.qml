pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dndEnabled: false

    readonly property ListModel activeToasts: ListModel {}

    readonly property int maxVisibleToasts: 6

    readonly property alias trackedNotifications: idDBusServer.trackedNotifications

    readonly property ListModel historyModel: ListModel {}

    property alias centerVisible: idPanelState.visible

    property alias centerLastOutsideCloseAt: idPanelState.lastOutsideCloseAt

    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

    property string pendingFocusAddress: ""

    function toggleCenter() {
        idPanelState.toggle()
    }

    function toggleCenterAt(screen, centerX: real) {
        idPanelState.toggleAt(screen, centerX)
    }

    function closeCenterFromOutside() {
        idPanelState.closeFromOutside()
    }

    readonly property int unreadCount: idDBusServer.trackedNotifications.values.length

    signal toastReceived(Notification notification)

    PanelState {
        id: idPanelState
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

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
        const selectorAddress = rawAddress.startsWith("0x") ? rawAddress : "0x" + rawAddress;
        if (selectorAddress === "0x")
            return false;
        if (idCursorPosProcess.running) {
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${selectorAddress}" })`);
        } else {
            root.pendingFocusAddress = selectorAddress;
            idCursorPosProcess.running = true;
        }
        return true;
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
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${root.pendingFocusAddress}" })`);
            if (match)
                Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
        }
    }

    function announceToast(notification: Notification) {
        if (root.activeToasts.count >= root.maxVisibleToasts)
            root.activeToasts.remove(0);
        root.activeToasts.append({ toast: notification });
        root.toastReceived(notification);
    }

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

            if (!notification.lastGeneration && !root.dndEnabled && !root.centerVisible)
                root.announceToast(notification);

            notification.closed.connect(() => {
                root.retireToast(notification);
                root.retireHistory(notification);
            });
        }
    }
}
