pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Transient OSD popup layer (ticket 02): stacks incoming notification
// toasts in the top-right corner of the primary screen, just below the
// unified slab bar. Hidden entirely while no toasts are active so it never
// intercepts input, and excluded from layer-shell exclusive zones so its
// anchors cannot shift the bar.
//
// No explicit screen binding: PanelWindow defaults to the primary screen.

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: Globals.barHeight + Globals.moduleMargin + 8
        right: Globals.horizontalBarMargin
    }

    // Hidden while no toasts are active OR while the notification center is
    // open (ticket 03): the two surfaces share this corner and the center
    // must be readable. Toasts suppressed this way keep decaying; whatever
    // has not expired by the time the center closes reappears.
    visible: NotificationServer.activeToasts.count > 0 && !NotificationServer.centerVisible

    // Fixed visual canvas: binding the window height to contentHeight made
    // the viewport collapse during the displaced transition (contentHeight
    // tracks ANIMATED positions, so the window shrank mid-animation and
    // ListView destroyed the delegates that fell outside it). The input
    // mask keeps click-through everywhere except real toast area.
    implicitWidth: Globals.toastWidth
    implicitHeight: 720

    mask: Region {
        x: 0
        y: 0
        width: Globals.toastWidth
        height: idToastView.contentHeight
    }

    // ListView (not Column+Repeater): its displaced transition is the
    // supported way to animate survivors when a row is removed — Column
    // repositioning bypasses Behavior on y (verified empirically, y moves
    // in a single step).
    ListView {
        id: idToastView

        anchors.fill: parent

        interactive: false
        spacing: 10
        clip: true

        model: NotificationServer.activeToasts

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Globals.toastMs
                easing.type: Easing.OutCubic
            }
        }

        // The toast role fills NotificationToast's `required property
        // Notification toast` automatically.
        delegate: NotificationToast {}
    }
}
