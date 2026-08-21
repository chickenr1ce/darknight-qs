import QtQuick
import Quickshell.Io
import "../config"
import "../components"

// Power menu — launches the existing rofi powermenu script.
ModuleBox {
    id: root

    Text {
        id: idPowerMenuIcon

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: 13
        text: "󰐥"
    }

    onClicked: openPowerMenu()

    function openPowerMenu(): void {
        idPowerMenuProcess.command = ["/home/alexiz/.config/rofi/powermenu/type-1/powermenu.sh"];
        idPowerMenuProcess.running = true;
    }

    Process {
        id: idPowerMenuProcess
    }
}
