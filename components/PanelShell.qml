pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    property real panelWidth: Globals.centerWidth
    property real panelMaxHeight: Globals.centerMaxHeight
    property bool attachedToBar: false
    property int junctionRadius: 0

    signal outsideClicked()

    readonly property int effectiveJunctionRadius: {
        if (!root.attachedToBar)
            return 0;
        return Math.max(0, Math.min(root.junctionRadius, Globals.junctionRadiusMax));
    }

    readonly property int anchorScreenWidth: root.anchorScreen ? root.anchorScreen.width : root.panelWidth + 2 * Globals.panelEdgeMargin
    readonly property real anchorPanelWidth: Math.min(root.panelWidth, root.anchorScreenWidth - 2 * Globals.panelEdgeMargin)
    readonly property int windowWidth: root.anchorPanelWidth + 2 * root.effectiveJunctionRadius

    readonly property real anchorLeft: root.clampLeft(root.anchorCenterX - root.anchorPanelWidth / 2, root.anchorPanelWidth)

    readonly property int windowLeft: Math.round(root.clampLeft(root.anchorLeft - root.effectiveJunctionRadius, root.windowWidth))

    readonly property string junctionPath: {
        const w = idPanel.width;
        const h = idPanel.height;
        const r = root.effectiveJunctionRadius;
        const b = Globals.panelRadius;
        return `M0,0 L${w},0`
            + ` A${r},${r} 0 0 0 ${w - r},${r}`
            + ` L${w - r},${h - b} A${b},${b} 0 0 1 ${w - r - b},${h}`
            + ` L${r + b},${h} A${b},${b} 0 0 1 ${r},${h - b}`
            + ` L${r},${r} A${r},${r} 0 0 0 0,0 Z`;
    }

    readonly property string junctionBorderPath: {
        const w = idPanel.width;
        const h = idPanel.height;
        const r = root.effectiveJunctionRadius;
        const b = Globals.panelRadius;
        return `M${w},0 A${r},${r} 0 0 0 ${w - r},${r}`
            + ` L${w - r},${h - b} A${b},${b} 0 0 1 ${w - r - b},${h}`
            + ` L${r + b},${h} A${b},${b} 0 0 1 ${r},${h - b}`
            + ` L${r},${r} A${r},${r} 0 0 0 0,0`;
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
        top: Globals.barHeight + Globals.moduleMargin + (root.attachedToBar ? -Globals.panelSeamOverlap : Globals.panelTopGap)
        left: root.windowLeft
    }

    implicitWidth: root.windowWidth
    implicitHeight: root.panelMaxHeight

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

        Region {
            x: 0
            y: root.effectiveJunctionRadius
            width: root.effectiveJunctionRadius
            height: Math.max(0, idPanel.height - root.effectiveJunctionRadius)
            intersection: Intersection.Subtract
        }

        Region {
            x: idPanel.width - root.effectiveJunctionRadius
            y: root.effectiveJunctionRadius
            width: root.effectiveJunctionRadius
            height: Math.max(0, idPanel.height - root.effectiveJunctionRadius)
            intersection: Intersection.Subtract
        }

        Region {
            x: -root.effectiveJunctionRadius
            y: 0
            width: 2 * root.effectiveJunctionRadius
            height: 2 * root.effectiveJunctionRadius
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }

        Region {
            x: idPanel.width - root.effectiveJunctionRadius
            y: 0
            width: 2 * root.effectiveJunctionRadius
            height: 2 * root.effectiveJunctionRadius
            shape: RegionShape.Ellipse
            intersection: Intersection.Subtract
        }
    }

    HyprlandFocusGrab {
        id: idShellFocusGrab

        active: root.panelVisible
        windows: [root]
        onCleared: root.outsideClicked()
    }

    Item {
        id: idPanel

        anchors.left: parent.left
        anchors.right: parent.right

        y: -8 * (1 - opacity)
        opacity: root.panelVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : (root.panelVisible ? Globals.centerCloseMs : Globals.centerOpenMs)
                easing.type: Easing.OutCubic
            }
        }

        height: Math.min(root.panelMaxHeight, idShellLayout.implicitHeight + 2 * Globals.panelPadding)

        Rectangle {
            id: idPanelChrome

            anchors.fill: parent

            visible: root.effectiveJunctionRadius === 0
            radius: Globals.panelRadius
            color: Colors.panel
            border.width: Globals.hairlineHeight
            border.color: Colors.panelBorder
        }

        Shape {
            id: idJunctionChrome

            anchors.fill: parent

            visible: root.effectiveJunctionRadius > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Colors.panel
                strokeWidth: 0
                PathSvg {
                    path: root.junctionPath
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.panelBorder
                strokeWidth: Globals.hairlineHeight
                PathSvg {
                    path: root.junctionBorderPath
                }
            }
        }

        ColumnLayout {
            id: idShellLayout

            anchors {
                fill: parent
                leftMargin: Globals.panelPadding + root.effectiveJunctionRadius
                rightMargin: Globals.panelPadding + root.effectiveJunctionRadius
                topMargin: Globals.panelPadding
                bottomMargin: Globals.panelPadding
            }

            spacing: Globals.spacing
        }
    }

    function clampLeft(raw: real, width: real): real {
        const maxLeft = root.anchorScreenWidth - width - Globals.panelEdgeMargin;
        return Math.min(Math.max(raw, Globals.panelEdgeMargin), Math.max(maxLeft, Globals.panelEdgeMargin));
    }
}
