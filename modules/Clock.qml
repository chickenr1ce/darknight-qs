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

    onClicked: {
        const centerX = Globals.triggerCenterX(root, root.triggerScreen);
        NotificationServer.centerVisible = false;
        CavaService.cavaVisible = false;
        CalendarService.toggleCalendarAt(root.triggerScreen, centerX);
    }

    Text {
        id: idClockLabel

        Layout.alignment: Qt.AlignCenter

        color: Colors.lavender
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
}
