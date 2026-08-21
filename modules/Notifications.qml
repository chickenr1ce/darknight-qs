import QtQuick
import Quickshell.Io
import "../config"
import "../components"

// swaync toggle, mirroring the waybar custom/notification module.
ModuleBox {
    id: root

    Text {
        id: idNotificationsIcon

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: ""
    }

    onClicked: toggleNotifications()

    function toggleNotifications(): void {
        idNotificationsProcess.command = ["swaync-client", "-t", "-sw"];
        idNotificationsProcess.running = true;
    }

    Process {
        id: idNotificationsProcess
    }
}
