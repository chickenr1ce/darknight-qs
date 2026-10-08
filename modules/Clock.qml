import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

ModuleBox {
    id: root

    property string monitorName: ""
    property ShellScreen triggerScreen: null

    readonly property bool anchorActive: root.visible && Globals.onPrimaryMonitor(root.monitorName)

    visible: BarVisibilityService.isVisible("clock")

    onClicked: root.toggleAtBar()
    onAnchorActiveChanged: root.syncAnchor()
    Component.onCompleted: root.syncAnchor()
    Component.onDestruction: CalendarService.barAnchor.unregister(root)

    Text {
        id: idClockLabel

        Layout.alignment: Qt.AlignCenter

        color: Colors.accent
        text: Qt.formatDateTime(new Date(), "dd.MM HH:mm")
        font {
            family: Globals.fontFamily
            pixelSize: Globals.fontPixelSize
            weight: Font.DemiBold
        }
    }

    Timer {
        id: idClockTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: idClockLabel.text = Qt.formatDateTime(new Date(), "dd.MM HH:mm")
    }

    Connections {
        target: CalendarService.barAnchor

        function onToggleRequested() {
            if (root.anchorActive)
                root.toggleAtBar();
        }
    }

    function toggleAtBar() {
        Panels.toggleAt(CalendarService.panelState, root.triggerScreen, Globals.triggerCenterX(root, root.triggerScreen));
    }

    function syncAnchor() {
        if (root.anchorActive)
            CalendarService.barAnchor.register(root);
        else
            CalendarService.barAnchor.unregister(root);
    }
}
