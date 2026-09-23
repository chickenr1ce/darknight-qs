import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components

ModuleBox {
    id: root

    property string monitorName: ""
    visible: Globals.onPrimaryMonitor(root.monitorName)

    onClicked: openPowerMenu()

    Text {
        id: idPowerMenuIcon

        Layout.alignment: Qt.AlignCenter

        color: Colors.lavender
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
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
