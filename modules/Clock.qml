import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ModuleBox {
    id: root

    // Shared corner with the notification center; never stack both panels.
    onClicked: {
        NotificationServer.centerVisible = false;
        CalendarService.toggleCalendar();
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
