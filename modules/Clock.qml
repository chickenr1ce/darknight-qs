import QtQuick
import "../config"
import "../components"

ModuleBox {
    id: root

    Text {
        id: idClockLabel

        color: Colors.lavender
        font.family: Globals.fontFamily
        font.pixelSize: Globals.fontPixelSize
        font.weight: Font.DemiBold
        text: Qt.formatDateTime(new Date(), "dd.MM HH:mm")
    }

    Timer {
        id: idClockTimer

        interval: 1000
        running: true
        repeat: true
        onTriggered: idClockLabel.text = Qt.formatDateTime(new Date(), "dd.MM HH:mm")
    }
}
