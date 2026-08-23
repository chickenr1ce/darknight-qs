import QtQuick
import qs.config
import qs.components

ModuleBox {
    id: root

    Text {
        id: idClockLabel

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
