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

    visible: BarVisibilityService.isVisible("power") && Globals.onPrimaryMonitor(root.monitorName)

    onClicked: idPowerMenuTrigger.toggle()

    Text {
        id: idPowerMenuIcon

        Layout.alignment: Qt.AlignCenter

        color: Colors.accent
        font {
            family: Globals.iconFontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
        text: SystemInfo.distroGlyph
    }

    PanelTrigger {
        id: idPowerMenuTrigger

        anchor: PowerService.barAnchor
        panelState: PowerService.panelState
        trigger: root
        triggerScreen: root.triggerScreen
        active: root.visible
    }
}
