pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Shared press-squash driver (Phase 6a, D-03). Bind the host item's scale
// to the driver's scale; pressing animates down to pressedScale (OutQuad)
// and releasing animates back to 1.0 with a slight overshoot (OutBack).
// One component so every clickable surface shares identical timing/easing.
Item {
    id: root

    // The host's pressed state driving the squash
    property bool pressed: false

    // Squashed scale at full press: Globals.pressScaleModule for module
    // regions, Globals.pressScalePill for small per-item pills
    property real pressedScale: Globals.pressScaleModule

    // Parity with PressFeedback: filling via anchors keeps this driver out
    // of layout management when hosted through ModuleBox's content alias
    // (a plain zero-size item would otherwise consume layout spacing).
    anchors.fill: parent

    scale: root.pressed ? root.pressedScale : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Globals.pressMs
            easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
        }
    }
}
