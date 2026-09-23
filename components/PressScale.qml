pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Shared press-squash driver: identical timing/easing on every surface.
// Release overshoots via OutBack.
Item {
    id: root

    property bool pressed: false

    property real pressedScale: Globals.pressScaleModule

    // Anchors fill keeps this driver out of layout management; a zero-size item
    // would otherwise consume layout spacing via the content alias.
    anchors.fill: parent

    scale: root.pressed ? root.pressedScale : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Globals.reducedMotion ? 0 : Globals.pressMs
            easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
        }
    }
}
