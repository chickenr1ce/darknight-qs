pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    property bool dndEnabled: false

    readonly property int maxVisibleToasts: 6

    readonly property ListModel notifications: ListModel {}

    readonly property ListModel toasts: ListModel {}

    readonly property int unreadCount: root.notifications.count

    readonly property var groups: {
        const order = [];
        const byName = {};
        for (let i = 0; i < root.notifications.count; i++) {
            const entry = root.notifications.get(i);
            const notification = entry.notification;
            if (!notification)
                continue;
            if (!(notification.appName in byName)) {
                byName[notification.appName] = [];
                order.push(notification.appName);
            }
            byName[notification.appName].push({ notification: notification, arrivedAt: entry.arrivedAt });
        }
        return order.map(appName => ({ appName: appName, notifications: byName[appName] }));
    }

    readonly property PanelState panelState: idPanelState

    readonly property BarAnchor barAnchor: idBarAnchor

    signal toastReceived(Notification notification)

    onDndEnabledChanged: root.saveNotificationSettings()

    PanelState {
        id: idPanelState

        onVisibleChanged: {
            if (idPanelState.visible)
                root.toasts.clear();
        }
    }

    BarAnchor {
        id: idBarAnchor
    }

    StateFile {
        id: idNotificationState

        name: "notifications"
        createDir: true
        onParsed: text => root.applyNotificationSettings(text)
    }

    IpcHandler {
        target: "notifications"

        function toggle(): string {
            return idBarAnchor.requestToggle() ? "ok" : "error: notifications module is hidden";
        }

        function close(): string {
            idPanelState.closeFromOutside();
            return "ok";
        }
    }

    IpcHandler {
        target: "dnd"

        function toggle(): string {
            root.toggleDnd();
            return root.dndEnabled ? "on" : "off";
        }

        function on(): string {
            root.dndEnabled = true;
            return "on";
        }

        function off(): string {
            root.dndEnabled = false;
            return "off";
        }

        function status(): string {
            return root.dndEnabled ? "on" : "off";
        }
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

    function applyNotificationSettings(jsonText: string): void {
        const parsed = StateParsers.parseNotificationSettings(jsonText);
        if (parsed === null)
            return;
        root.dndEnabled = parsed.dnd;
    }

    function saveNotificationSettings(): void {
        const payload = {};
        payload["dnd"] = root.dndEnabled;
        idNotificationState.saveJson(payload);
    }

    function dismissAll() {
        const list = [];
        for (let i = 0; i < root.notifications.count; i++)
            list.push(root.notifications.get(i).notification);
        for (let i = list.length - 1; i >= 0; i--) {
            if (list[i])
                list[i].dismiss();
        }
    }

    function dismissGroup(appName: string) {
        const list = [];
        for (let i = 0; i < root.notifications.count; i++) {
            const notification = root.notifications.get(i).notification;
            if (notification && notification.appName === appName)
                list.push(notification);
        }
        for (let i = list.length - 1; i >= 0; i--)
            list[i].dismiss();
    }

    function focusApp(notification: Notification) {
        if (!notification)
            return false;
        return HyprlandFocus.focusByTokens([notification.appName, notification.desktopEntry]);
    }

    function isCritical(notification) {
        if (!notification)
            return false;
        return notification.urgency === NotificationUrgency.Critical;
    }

    function invokeAction(notification, action) {
        if (!notification || !action)
            return;
        root.focusApp(notification);
        action.invoke();
    }

    function sendReply(notification, text) {
        const reply = text.trim();
        if (reply === "" || !notification)
            return false;
        const resident = notification.resident;
        notification.sendInlineReply(reply);
        if (resident)
            notification.dismiss();
        return true;
    }

    function announceToast(notification: Notification) {
        if (root.toasts.count >= root.maxVisibleToasts)
            root.toasts.remove(0);
        root.toasts.append({ toast: notification });
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
        root.retireFrom(root.toasts, "toast", notification);
    }

    function retireHistory(notification: Notification) {
        root.retireFrom(root.notifications, "notification", notification);
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
            root.notifications.append({ notification: notification, arrivedAt: Date.now() });

            if (!notification.lastGeneration && !root.dndEnabled && !idPanelState.visible)
                root.announceToast(notification);

            notification.closed.connect(() => {
                root.retireToast(notification);
                root.retireHistory(notification);
            });
        }
    }
}
