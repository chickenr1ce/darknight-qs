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

    onClicked: {
        const centerX = Globals.triggerCenterX(root, root.triggerScreen);
        Panels.togglePowerAt(root.triggerScreen, centerX);
    }

    Text {
        id: idPowerMenuIcon

        Layout.alignment: Qt.AlignCenter

        color: Colors.lavender
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
        text: ""
    }
}
