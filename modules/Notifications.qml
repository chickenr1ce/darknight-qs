import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// swaync toggle, mirroring the waybar custom/notification module.
// Ticket 03: left-click now toggles the native notification center; the
// swaync process call remains until ticket 04 completes the migration.
ModuleBox {
    id: root

    onClicked: NotificationServer.toggleCenter()

    Text {
        id: idNotificationsIcon

        color: Colors.lavender
        text: ""
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }

    Process {
        id: idNotificationsProcess
    }

    function toggleNotifications(): void {
        idNotificationsProcess.command = ["swaync-client", "-t", "-sw"];
        idNotificationsProcess.running = true;
    }
}
