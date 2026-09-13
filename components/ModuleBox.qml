import QtQuick
import QtQuick.Layouts
import qs.config

// Transparent hit-region: hover tint + underline, press squash/pulse; emits clicked(mouse)/wheelMoved(wheel).
Rectangle {
    id: root

    property int horizontalPadding: Globals.modulePadding
    property int maxWidth: 0
    property int minWidth: 0

    // False for containers (Workspaces, Tray) whose children handle their own input.
    property bool enableMouseArea: true
    property bool enableHover: enableMouseArea

    readonly property bool isHovered: root.enableHover && idModuleBoxHoverHandler.hovered
    readonly property bool isPressed: idModuleBoxMouseArea.pressed

    // Pill effects inset 2px so the tint reads generous while modules stay separated.
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
    // Pill hugging the content while the full region stays the hit area.
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

    // Softer 0.18 peak keeps the larger module region subtler than per-item pills.
    PressFeedback {
        id: idPressFeedback

        active: root.isHovered
        horizontalInset: root.pillInset
        verticalInset: Globals.moduleMargin
        peakOpacity: 0.18
    }

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

    // Disabled for container modules (Workspaces, Tray) where items manage their own hover.
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
