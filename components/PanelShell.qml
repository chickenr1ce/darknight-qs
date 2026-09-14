pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

// Floating panel shell: fixed canvas, click-through mask, outside-close grab.
// Content slots into the inner column; owners control visibility via panelVisible.

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property bool panelVisible
    default property alias content: idShellLayout.data

    signal outsideClicked()

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Lets the compositor route keys to fields inside; takes focus on click only, never unprompted.
    focusable: true

    anchors {
        top: true
        right: true
    }

    margins {
        top: Globals.barHeight + Globals.moduleMargin + 8
        right: Globals.horizontalBarMargin + Globals.slabEdgePadding
    }

    implicitWidth: Globals.centerWidth
    implicitHeight: Globals.centerMaxHeight

    // Animation lives on the inner panel (Windows lack opacity/transform); visible holds through close so the fade renders.
    visible: root.panelVisible || idPanel.opacity > 0

    // Click-through everywhere except the panel; emptied while hidden so a faded frame can't swallow input.
    mask: Region {
        x: 0
        y: 0
        width: root.visible ? idPanel.width : 0
        height: root.visible ? idPanel.height : 0
    }

    // Outside click closes the panel; the compositor clears the grab when input lands outside.
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
                duration: root.panelVisible ? Globals.centerOpenMs : Globals.centerCloseMs
                easing.type: Easing.OutCubic
            }
        }

        height: Math.min(Globals.centerMaxHeight, idShellLayout.implicitHeight + 2 * Globals.panelPadding)

        radius: Globals.panelRadius
        color: Colors.panel
        border.width: 1
        border.color: Colors.panelBorder

        ColumnLayout {
            id: idShellLayout

            anchors.fill: parent
            anchors.margins: Globals.panelPadding

            spacing: Globals.spacing
        }
    }
}
