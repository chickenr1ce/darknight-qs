pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Release pulse (call pulse() on click) + center-expanding hover underline.
// Fill the host and bind active to the host's hover state.
Item {
    id: root

    // Hover state driving the underline
    property bool active: false

    // Insets matching the host's pill tint, so pulse and underline hug it
    // (ModuleBox insets its pill; Workspaces/Tray pills sit flush).
    property int horizontalInset: 0
    property int verticalInset: 0

    property real peakOpacity: 0.25

    anchors.fill: parent

    function pulse() {
        idReleasePulse.restart();
    }

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
