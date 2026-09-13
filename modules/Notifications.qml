import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Bell swaps outline for solid when history is unread; left-click toggles the center, right/middle-click DND.
ModuleBox {
    id: root

    readonly property bool hasUnread: NotificationServer.unreadCount > 0 && !NotificationServer.dndEnabled

    // Bell glyphs differ in advance width; reserve the widest so state swaps never reflow the bar (conventions §3).
    minWidth: 2 * root.horizontalPadding + Math.max(idNotificationsBellEmptyMetrics.advanceWidth, idNotificationsBellUnreadMetrics.advanceWidth, idNotificationsBellDndMetrics.advanceWidth)

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
            NotificationServer.toggleDnd();
        else
            NotificationServer.toggleCenter();
    }

    // Non-visual measurers (layouts ignore non-Items).
    TextMetrics {
        id: idNotificationsBellEmptyMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: ""
    }

    TextMetrics {
        id: idNotificationsBellUnreadMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: ""
    }

    TextMetrics {
        id: idNotificationsBellDndMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: ""
    }

    Text {
        id: idNotificationsIcon

        Layout.alignment: Qt.AlignVCenter

        text: NotificationServer.dndEnabled ? "" : (root.hasUnread ? "" : "")
        color: NotificationServer.dndEnabled ? Colors.textSecondary : Colors.lavender
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }
}
