import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

ModuleBox {
    id: root

    property string monitorName: ""
    property ShellScreen triggerScreen: null

    visible: Globals.onPrimaryMonitor(root.monitorName)

    readonly property bool hasUnread: NotificationServer.unreadCount > 0 && !NotificationServer.dndEnabled

    minWidth: 2 * root.horizontalPadding + Math.max(idNotificationsBellEmptyMetrics.advanceWidth, idNotificationsBellUnreadMetrics.advanceWidth, idNotificationsBellDndMetrics.advanceWidth)

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
            NotificationServer.toggleDnd();
        else {
            const centerX = Globals.triggerCenterX(root, root.triggerScreen);
            Panels.toggleCenterAt(root.triggerScreen, centerX);
        }
    }

    TextMetrics {
        id: idNotificationsBellEmptyMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: "󰂜"
    }

    TextMetrics {
        id: idNotificationsBellUnreadMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: "󰂚"
    }

    TextMetrics {
        id: idNotificationsBellDndMetrics

        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: "󰪑"
    }

    Text {
        id: idNotificationsIcon

        Layout.alignment: Qt.AlignCenter

        text: NotificationServer.dndEnabled ? "󰪑" : (root.hasUnread ? "󰂚" : "󰂜")
        color: NotificationServer.dndEnabled ? Colors.textSecondary : Colors.lavender
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }
}
