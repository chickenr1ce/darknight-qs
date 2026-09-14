pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Transient popup layer: excluded from exclusive zones so its anchors can't shift the bar; hidden while idle so it never intercepts input.
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

    // Hidden while either panel is open (shared corner); suppressed toasts keep decaying and survivors reappear on close.
    visible: NotificationServer.activeToasts.count > 0 && !NotificationServer.centerVisible && !CalendarService.calendarVisible

    // Never bind window height to contentHeight: it tracks animated positions and collapses the viewport mid-transition.
    // The mask keeps click-through everywhere except the real toast area.
    implicitWidth: Globals.toastWidth
    implicitHeight: 720

    mask: Region {
        x: 0
        y: 0
        width: Globals.toastWidth
        height: idToastView.contentHeight
    }

    // ListView displaced animates reflow; Column repositioning bypasses Behavior (conventions §4).
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

        // The toast role fills NotificationToast's required toast property automatically.
        delegate: NotificationToast {}
    }
}
