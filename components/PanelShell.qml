pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config


// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property bool panelVisible
    default property alias content: idShellLayout.data

    property ShellScreen anchorScreen: null
    property real anchorCenterX: 0

    signal outsideClicked()

    readonly property int anchorScreenWidth: root.anchorScreen ? root.anchorScreen.width : Globals.centerWidth + 2 * Globals.panelEdgeMargin
    readonly property real anchorPanelWidth: Math.min(Globals.centerWidth, root.anchorScreenWidth - 2 * Globals.panelEdgeMargin)

    readonly property real anchorLeft: {
        const raw = root.anchorCenterX - root.anchorPanelWidth / 2;
        const maxLeft = root.anchorScreenWidth - root.anchorPanelWidth - Globals.panelEdgeMargin;
        return Math.min(Math.max(raw, Globals.panelEdgeMargin), Math.max(maxLeft, Globals.panelEdgeMargin));
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    screen: root.anchorScreen

    focusable: true

    anchors {
        top: true
        left: true
    }

    margins {
        top: Globals.barHeight + Globals.moduleMargin + Globals.panelTopGap
        left: Math.round(root.anchorLeft)
    }

    implicitWidth: root.anchorPanelWidth
    implicitHeight: Globals.centerMaxHeight

    Shortcut {
        id: idEscapeShortcut

        enabled: root.panelVisible
        sequence: "Escape"
        onActivated: root.outsideClicked()
    }

    visible: root.panelVisible || idPanel.opacity > 0

    mask: Region {
        x: 0
        y: 0
        width: root.visible ? idPanel.width : 0
        height: root.visible ? idPanel.height : 0
    }

    HyprlandFocusGrab {
        id: idShellFocusGrab

        active: root.panelVisible
        windows: [root]
        onCleared: root.outsideClicked()
    }

    Rectangle {
        id: idPanel

        anchors.left: parent.left
        anchors.right: parent.right

        y: -8 * (1 - opacity)
        opacity: root.panelVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.panelVisible ? Globals.centerCloseMs : Globals.centerOpenMs
                easing.type: Easing.OutCubic
            }
        }

        height: Math.min(Globals.centerMaxHeight, idShellLayout.implicitHeight + 2 * Globals.panelPadding)

        radius: Globals.panelRadius
        color: Colors.panel
        border.width: Globals.hairlineHeight
        border.color: Colors.panelBorder

        ColumnLayout {
            id: idShellLayout

            anchors.fill: parent
            anchors.margins: Globals.panelPadding

            spacing: Globals.spacing
        }
    }
}
