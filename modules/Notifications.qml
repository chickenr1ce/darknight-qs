import QtQuick
import Quickshell.Io
import qs.config
import qs.components

// swaync toggle, mirroring the waybar custom/notification module.
ModuleBox {
    id: root

    onClicked: toggleNotifications()

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
