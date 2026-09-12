pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// No "pragma ComponentBehavior: Bound" here: combined with pragma Singleton
// it crashes qmllint (silent exit 255) in this build. It is a no-op for a
// delegate-free service anyway; mirrors services/MprisPlayers.qml.
//
// Native DBus notification daemon replacing swaync (Phase 6b, ticket 01).
//
// Claims org.freedesktop.Notifications, records every incoming notification
// into the server's tracked history, and announces popup-worthy arrivals to
// listeners via toastReceived(). Do Not Disturb keeps recording history but
// suppresses toast announcements.
Singleton {
    id: root

    // When true, notifications are still tracked in history but no longer
    // announced as transient popups.
    property bool dndEnabled: false

    // Notifications currently eligible for popup display, in arrival order.
    // A ListModel rather than a reassigned JS array: row-level remove keeps
    // Repeater delegates alive across dismissals, so surviving toasts keep
    // their decay state and never replay their entrance animation. (An
    // ObjectModel would also do this but is uncreatable/read-only from QML.)
    readonly property ListModel activeToasts: ListModel {}

    // Popup canvas capacity (review fix): the fixed 720px window reliably
    // shows six toast cards; further arrivals expire the oldest instead of
    // stacking invisibly past the window's clip.
    readonly property int maxVisibleToasts: 6

    // Full history of notifications tracked by the DBus server (newest last).
    readonly property alias trackedNotifications: idDBusServer.trackedNotifications

    // Live rows backing the notification center's accordions (ticket 03).
    // Mirrors trackedNotifications into a ListModel so QML views get stable,
    // row-level removals on close instead of snapshot-array reassignment.
    readonly property ListModel historyModel: ListModel {}

    // Visibility of windows/NotificationCenter.qml; toggled by the bar module.
    property bool centerVisible: false

    // Ticket 04 owns the full module migration; this is the minimal hook the
    // panel needs to be openable at all.
    function toggleCenter() {
        root.centerVisible = !root.centerVisible;
    }

    // Tracked notifications awaiting triage; decrements as they are dismissed.
    readonly property int unreadCount: idDBusServer.trackedNotifications.values.length

    signal toastReceived(Notification notification)

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled;
    }

    // Backwards iteration: trackedNotifications.values is a snapshot copy,
    // so dismissing entries mid-loop cannot shift the indices under us.
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

    // Typed params are fine here, but a ": void" return annotation is not:
    // qmllint crashes (silent exit 255) on void-returning functions in
    // pragma Singleton files, so return types are omitted throughout.
    function announceToast(notification: Notification) {
        // Enforce the visible-stack cap by expiring (not dismissing) the
        // oldest toast, so overflow surfaces as a normal expiry on DBus
        // instead of a card clipped invisibly off-canvas. The row is
        // removed here first; expire() then fires `closed`, whose retire
        // scan simply finds nothing left to do.
        if (root.activeToasts.count >= root.maxVisibleToasts) {
            const oldest = root.activeToasts.get(0).toast;
            root.activeToasts.remove(0);
            oldest.expire();
        }
        root.activeToasts.append({ toast: notification });
        root.toastReceived(notification);
    }

    // Shared identity scan rather than indexOf: ListModel.get returns a
    // detached row wrapper, so compare against the stored object itself.
    // Backwards iteration: `.values` snapshots aside, removing mid-loop from
    // the end cannot shift the indices still under us.
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

            // Reload-carried notifications were already shown before the
            // restart; keep them in history without re-toasting. While the
            // notification center is open it is the notification surface:
            // arrivals go to history only, so no hidden toast backlog pops
            // up when the center closes.
            if (!notification.lastGeneration && !root.dndEnabled && !root.centerVisible)
                root.announceToast(notification);

            notification.closed.connect(() => {
                root.retireToast(notification);
                root.retireHistory(notification);
            });
        }
    }
}
