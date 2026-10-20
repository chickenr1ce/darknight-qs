pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// Center-expanding hover underline.
// Fill the host and bind active to the host's hover state.
Item {
    id: root

    // Hover state driving the underline
    property bool active: false

    // Insets matching the host's pill tint, so the underline hugs it
    // (ModuleBox insets its pill; Workspaces/Tray pills sit flush).
    property int horizontalInset: 0
    property int verticalInset: 0

    anchors.fill: parent

    Rectangle {
        id: idHoverUnderline

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.verticalInset
        }

        width: parent.width - 2 * root.horizontalInset
        height: 2
        color: Colors.accent
        opacity: root.active ? 1 : 0

        transform: Scale {
            origin.x: idHoverUnderline.width / 2
            xScale: root.active || Globals.reducedMotion ? 1 : 0

            Behavior on xScale {
                NumberAnimation {
                    duration: Globals.hoverMs
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Globals.easeOutCurve
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.hoverMs
                easing.type: Easing.OutQuad
            }
        }
    }
}
