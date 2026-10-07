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

    visible: BarVisibilityService.isVisible("notifications") && Globals.onPrimaryMonitor(root.monitorName)

    readonly property bool hasUnread: NotificationServer.unreadCount > 0 && !NotificationServer.dndEnabled

    minWidth: 2 * root.horizontalPadding + Math.max(idNotificationsBellEmptyMetrics.advanceWidth, idNotificationsBellUnreadMetrics.advanceWidth, idNotificationsBellDndMetrics.advanceWidth)

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
            NotificationServer.toggleDnd();
        else {
            const centerX = Globals.triggerCenterX(root, root.triggerScreen);
            Panels.toggleAt(NotificationServer.panelState, root.triggerScreen, centerX);
        }
    }

    TextMetrics {
        id: idNotificationsBellEmptyMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: Icons.bell
    }

    TextMetrics {
        id: idNotificationsBellUnreadMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: Icons.bellBadge
    }

    TextMetrics {
        id: idNotificationsBellDndMetrics

        font.family: Globals.iconFontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: Icons.bellOffOutline
    }

    Text {
        id: idNotificationsIcon

        Layout.alignment: Qt.AlignCenter

        text: NotificationServer.dndEnabled ? Icons.bellOffOutline : (root.hasUnread ? Icons.bellBadge : Icons.bell)
        color: NotificationServer.dndEnabled ? Colors.textSecondary : Colors.accent
        font {
            family: Globals.iconFontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }
}
