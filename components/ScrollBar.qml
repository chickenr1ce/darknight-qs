pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.config

// Thin themed vertical bar for a Flickable, attached with
// `Controls.ScrollBar.vertical: ScrollBar {}`. It shows only when the content
// overflows, drags through the QtQuick.Controls handle, and the track pages.
Controls.ScrollBar {
    id: root

    orientation: Qt.Vertical
    interactive: true
    hoverEnabled: true
    padding: 0
    stepSize: root.size
    implicitWidth: Globals.scrollbarWidth
    visible: root.size < 1

    background: Rectangle {
        id: idScrollbarTrack

        implicitWidth: Globals.scrollbarWidth
        radius: Globals.scrollbarRadius
        color: Colors.border

        MouseArea {
            id: idScrollbarPageUp

            x: 0
            y: 0
            width: parent.width
            height: Math.max(0, idScrollbarHandle.y)
            acceptedButtons: Qt.LeftButton
            onClicked: root.decrease()
        }

        MouseArea {
            id: idScrollbarPageDown

            x: 0
            y: idScrollbarHandle.y + idScrollbarHandle.height
            width: parent.width
            height: Math.max(0, parent.height - y)
            acceptedButtons: Qt.LeftButton
            onClicked: root.increase()
        }
    }

    contentItem: Rectangle {
        id: idScrollbarHandle

        implicitWidth: Globals.scrollbarWidth
        radius: Globals.scrollbarRadius
        color: root.pressed || root.hovered ? Colors.accent : Colors.textSubtle
    }
}
