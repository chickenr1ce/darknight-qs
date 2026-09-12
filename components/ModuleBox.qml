import QtQuick
import QtQuick.Layouts
import qs.config

// Transparent hit-region on the shared slab (Phase 6a, D-01).
// Draws nothing at rest; hover paints a pill-shaped background-secondary
// tint plus a 2px lavender underline expanding from center (D-02),
// press squashes via PressScale and release pulses it (D-03).
// Emits clicked(mouse)/wheelMoved(wheel) so modules don't need their own MouseArea.
Rectangle {
    id: root

    property int horizontalPadding: Globals.modulePadding
    property int maxWidth: 0
    property int minWidth: 0

    // When true (default) the whole box is one click & hover target.
    // Set false for containers with their own interactive children
    // like Workspaces and Tray where each button/icon handles its own hover/clicks.
    property bool enableMouseArea: true
    property bool enableHover: enableMouseArea

    readonly property bool isHovered: root.enableHover && idModuleBoxHoverHandler.hovered
    readonly property bool isPressed: idModuleBoxMouseArea.pressed

    // Pill effects inset from the region edge: 2px breathing room so the
    // tint reads generous around content while keeping separation between modules
    readonly property int pillInset: 2

    default property alias content: idModuleBoxLayout.data

    signal clicked(var mouse)
    signal wheelMoved(var wheel)

    implicitHeight: Globals.barHeight
    implicitWidth: {
        let w = idModuleBoxLayout.implicitWidth + 2 * root.horizontalPadding;
        if (root.minWidth !== 0)
            w = Math.max(w, root.minWidth);
        if (root.maxWidth !== 0)
            w = Math.min(w, root.maxWidth);
        return w;
    }

    color: "transparent"
    scale: idPressScale.scale
    // Hover tint — pill hugging the content (D-02), matching the bar's
    // pill vocabulary (workspace/tray pills). The full region stays the
    // hit area; only the paint is pill-shaped.
    Rectangle {
        id: idHoverTint

        anchors {
            fill: parent
            leftMargin: root.pillInset
            rightMargin: root.pillInset
            topMargin: Globals.moduleMargin
            bottomMargin: Globals.moduleMargin
        }

        radius: Globals.radius
        color: Colors.backgroundSecondary
        opacity: root.isHovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.hoverMs
            }
        }
    }

    // Shared pill feedback — release pulse + hover underline. The softer
    // 0.18 peak keeps the larger module region subtler than per-item pills.
    PressFeedback {
        id: idPressFeedback

        active: root.isHovered
        horizontalInset: root.pillInset
        verticalInset: Globals.moduleMargin
        peakOpacity: 0.18
    }

    // Press squash (D-03), magnitude shared via Globals.pressScaleModule
    PressScale {
        id: idPressScale

        pressed: root.isPressed
    }

    RowLayout {
        id: idModuleBoxLayout

        spacing: Globals.spacing

        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
    }

    // Module-level hover handler. Disabled for container modules (Workspaces, Tray)
    // where individual items manage their own hover and press feedback.
    HoverHandler {
        id: idModuleBoxHoverHandler
        enabled: root.enableHover
    }

    MouseArea {
        id: idModuleBoxMouseArea

        // MiddleButton: DND shortcut (Notifications module)
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        anchors.fill: parent
        enabled: root.enableMouseArea
        z: 1

        onClicked: mouse => {
            idPressFeedback.pulse();
            root.clicked(mouse);
        }
        onWheel: wheel => root.wheelMoved(wheel)
    }
}
