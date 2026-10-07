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

    onClicked: root.toggleAtBar()
    onVisibleChanged: root.syncAnchor()
    Component.onCompleted: root.syncAnchor()
    Component.onDestruction: PowerService.unregisterBarAnchor(root)

    Text {
        id: idPowerMenuIcon

        Layout.alignment: Qt.AlignCenter

        color: Colors.accent
        font {
            family: Globals.iconFontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
        text: Icons.distro
    }

    Connections {
        target: PowerService

        function onBarAnchorToggleRequested() {
            if (root.visible)
                root.toggleAtBar();
        }
    }

    function toggleAtBar() {
        Panels.toggleAt(PowerService.panelState, root.triggerScreen, Globals.triggerCenterX(root, root.triggerScreen));
    }

    function syncAnchor() {
        if (root.visible)
            PowerService.registerBarAnchor(root);
        else
            PowerService.unregisterBarAnchor(root);
    }
}
