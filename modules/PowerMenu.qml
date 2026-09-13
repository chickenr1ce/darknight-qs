import QtQuick
import Quickshell.Io
import qs.config
import qs.components

ModuleBox {
    id: root

    onClicked: openPowerMenu()

    Text {
        id: idPowerMenuIcon

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: 13
        text: "󰐥"
    }

    Process {
        id: idPowerMenuProcess
    }

    function openPowerMenu(): void {
        idPowerMenuProcess.command = ["/home/alexiz/.config/rofi/powermenu/type-1/powermenu.sh"];
        idPowerMenuProcess.running = true;
    }
}
