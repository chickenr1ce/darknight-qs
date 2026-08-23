pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Shared pill interaction feedback (Phase 6a, D-02/D-03):
//   - lavender release brightness pulse overlay (call pulse() on click)
//   - center-expanding hover underline with opacity fade
// Fill the host via anchors.fill and bind active to the host's hover state.
// The press-scale squash deliberately stays in the host item so its
// Behavior/easing remains local to each surface.
Item {
    id: root

    // Hover state driving the underline
    property bool active: false

    // Insets matching the host's pill tint so pulse & underline hug it:
    // the underline spans exactly the tint's width, lifted off the bottom
    // edge by verticalInset (ModuleBox insets its pill; per-item pills in
    // Workspaces/Tray are flush with their items)
    property int horizontalInset: 0
    property int verticalInset: 0

    // Peak brightness of the release pulse
    property real peakOpacity: 0.25

    anchors.fill: parent

    function pulse() {
        idReleasePulse.restart();
    }

    // Release brightness pulse overlay (D-03); opacity driven by idReleasePulse
    Rectangle {
        id: idPressPulse

        anchors {
            fill: parent
            leftMargin: root.horizontalInset
            rightMargin: root.horizontalInset
            topMargin: root.verticalInset
            bottomMargin: root.verticalInset
        }

        radius: Globals.radius
        color: Colors.lavender
        opacity: 0
    }

    // Hover underline expanding symmetrically from center with opacity fade (D-02)
    Rectangle {
        id: idHoverUnderline

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.verticalInset
        }

        width: root.active ? parent.width - 2 * root.horizontalInset : 0
        height: 2
        color: Colors.lavender
        opacity: root.active ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: Globals.hoverMs
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.hoverMs
            }
        }
    }

    // Release brightness pulse animation on click (D-03)
    SequentialAnimation {
        id: idReleasePulse

        NumberAnimation {
            target: idPressPulse
            property: "opacity"
            to: root.peakOpacity
            duration: Globals.pressMs / 2
        }

        NumberAnimation {
            target: idPressPulse
            property: "opacity"
            to: 0
            duration: Globals.pressMs
        }
    }
}
