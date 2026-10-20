pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Shared press-squash driver: identical timing/easing on every surface.
// The press is slower and deliberate; the release snaps back.
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
            duration: {
                if (Globals.reducedMotion)
                    return 0;
                return root.pressed ? Globals.pressReleaseMs : Globals.pressMs;
            }
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Globals.easeOutCurve
        }
    }
}
