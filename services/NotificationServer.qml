pragma Singleton

import QtQuick
import Quickshell
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

    // No ": void" return type: qmllint crashes (exit 255) on void returns in pragma Singleton files.
    function announceToast(notification: Notification) {
        // Cap by expiring (not dismissing) the oldest, so overflow surfaces as normal DBus expiry; the row goes first so the closed scan no-ops.
        if (root.activeToasts.count >= root.maxVisibleToasts) {
            const oldest = root.activeToasts.get(0).toast;
            root.activeToasts.remove(0);
            oldest.expire();
        }
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
