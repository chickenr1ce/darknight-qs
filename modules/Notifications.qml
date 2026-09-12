import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Bell + unread badge; left-click toggles the center, right/middle-click DND.
ModuleBox {
    id: root

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
            NotificationServer.toggleDnd();
        else
            NotificationServer.toggleCenter();
    }

    Text {
        id: idNotificationsIcon

        Layout.alignment: Qt.AlignVCenter

        text: NotificationServer.dndEnabled ? "" : ""
        color: NotificationServer.dndEnabled ? Colors.textSecondary : Colors.lavender
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }

    Rectangle {
        id: idNotificationsBadge

        Layout.alignment: Qt.AlignVCenter

        Layout.preferredWidth: Math.max(idNotificationsBadgeLabel.implicitWidth + 12, 18)
        Layout.preferredHeight: idNotificationsBadgeLabel.implicitHeight + 4

        visible: NotificationServer.unreadCount > 0 && !NotificationServer.dndEnabled
        radius: height / 2
        color: Colors.lavender

        Text {
            id: idNotificationsBadgeLabel

            anchors.centerIn: parent

            textFormat: Text.PlainText
            text: NotificationServer.unreadCount
            color: Colors.background

            font {
                family: Globals.fontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.DemiBold
            }
        }
    }
}
