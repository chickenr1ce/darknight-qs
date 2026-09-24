pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Singleton {
    id: root

    property bool dndEnabled: false

    readonly property ListModel activeToasts: ListModel {}

    readonly property int maxVisibleToasts: 6

    readonly property alias trackedNotifications: idDBusServer.trackedNotifications

    readonly property ListModel historyModel: ListModel {}

    property alias centerVisible: idPanelState.visible

    property alias centerLastOutsideCloseAt: idPanelState.lastOutsideCloseAt

    onCenterVisibleChanged: {
        if (root.centerVisible)
            root.activeToasts.clear();
    }

    property alias anchorScreen: idPanelState.anchorScreen
    property alias anchorCenterX: idPanelState.anchorCenterX

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
        return HyprlandFocus.focusByTokens([notification.appName, notification.desktopEntry]);
    }

    function isCriticalUrgency(urgency) {
        return urgency === NotificationUrgency.Critical;
    }

    function invokeAction(notification, action) {
        if (!notification || !action)
            return;
        root.focusApp(notification);
        action.invoke();
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
            root.historyModel.append({ notification: notification, arrivedAt: Date.now() });

            if (!notification.lastGeneration && !root.dndEnabled && !root.centerVisible)
                root.announceToast(notification);

            notification.closed.connect(() => {
                root.retireToast(notification);
                root.retireHistory(notification);
            });
        }
    }
}
