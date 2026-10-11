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

    onClicked: idClockTrigger.toggle()

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

    PanelTrigger {
        id: idClockTrigger

        anchor: CalendarService.barAnchor
        panelState: CalendarService.panelState
        trigger: root
        triggerScreen: root.triggerScreen
        active: root.anchorActive
    }
}
