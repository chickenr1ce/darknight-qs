pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.dev
import qs.services
import "PanelKeyboardLogic.js" as PanelKeyboardLogic


// qmllint disable uncreatable-type
PanelWindow {
    id: root

    property PanelState panel: null
    property bool panelVisible: root.panel ? root.panel.visible : false
    default property alias content: idShellLayout.data

    property ShellScreen anchorScreen: root.panel ? root.panel.anchorScreen : null
    property real anchorCenterX: root.panel ? root.panel.anchorCenterX : 0
    property real panelWidth: Globals.centerWidth
    property real panelMaxHeight: Globals.centerMaxHeight
    property real windowHeight: root.panelMaxHeight
    property bool attachedToBar: false
    property bool instantReveal: false
    property int junctionRadius: 0
    // Extra item whose rect joins the input mask, for content drawn past the
    // card inside the window (the Apps context menu hanging below a short card).
    property Item inputOverlay: null
    // DevGeometry name for the whole card, so scripts/capture.sh can grab it.
    property string geometryName: ""
    // The panel's current slide offset (negative mid-slide, 0 when settled),
    // so a host can measure positions against the settled layout.
    readonly property real slideOffset: idPanel.y

    // Focus mode, keyboard latch and Escape rules: PanelKeyboardLogic.js.
    property bool keyboardTaken: false
    property bool escapeArmed: false
    readonly property var keyboardState: ({ keyboardTaken: root.keyboardTaken, escapeArmed: root.escapeArmed })

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

    anchors {
        top: true
        left: true
    }

    margins {
        top: Globals.barHeight + Globals.barTopMargin + (root.attachedToBar ? -Globals.panelSeamOverlap : Globals.panelTopGap)
        left: root.windowLeft
    }

    implicitWidth: root.windowWidth
    implicitHeight: root.windowHeight
    visible: root.panelVisible || idPanel.reveal > 0

    WlrLayershell.keyboardFocus: root.keyboardFocusFor(PanelKeyboardLogic.focusMode(root.visible, root.panelVisible, root.keyboardTaken))

    Component.onCompleted: {
        PanelGrab.register(root);
        if (root.geometryName !== "")
            DevGeometry.register(root.geometryName, idPanel);
    }
    Component.onDestruction: {
        PanelGrab.unregister(root);
        if (root.geometryName !== "")
            DevGeometry.unregister(root.geometryName);
    }

    onPanelVisibleChanged: root.applyKeyboardStep(PanelKeyboardLogic.panelVisibleChanged(root.panelVisible, idPanel.Window.active))

    onOutsideClicked: {
        if (root.panel)
            root.panel.closeFromOutside();
    }

    Shortcut {
        id: idEscapeShortcut

        enabled: root.panelVisible
        sequence: "Escape"
        onActivated: root.applyKeyboardStep(PanelKeyboardLogic.escapePressed(root.keyboardState))
    }

    mask: Region {
        x: 0
        y: 0
        width: root.visible ? idPanel.width : 0
        // Attached panels take input only on the part slid into view, so a
        // click on the strip not yet covered still reaches the desktop.
        height: root.visible ? Math.round(idPanel.height * (idPanel.slides ? idPanel.reveal : (root.attachedToBar && !root.panelVisible ? 0 : 1))) : 0

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

        Region {
            item: root.inputOverlay
            intersection: Intersection.Combine
        }
    }

    Item {
        id: idPanel

        // 0 = hidden, 1 = shown. Attached panels slide down from behind the
        // bar (the window's top edge clips them) at full opacity; floating
        // panels fade with an 8px drop. Reduced motion keeps the fade only.
        property real reveal: root.panelVisible ? 1 : 0
        readonly property bool slides: root.attachedToBar && !Globals.reducedMotion

        anchors.left: parent.left
        anchors.right: parent.right

        height: Math.min(root.panelMaxHeight, idShellLayout.implicitHeight + 2 * Globals.panelPadding)
        y: {
            if (Globals.reducedMotion)
                return 0;
            return root.attachedToBar ? -idPanel.height * (1 - idPanel.reveal) : -8 * (1 - idPanel.reveal);
        }
        opacity: idPanel.slides ? 1 : idPanel.reveal

        // Composite the fade as one surface: unlayered, the translucent
        // chrome and the cards over it fade separately, so the cards seem
        // to outlive the panel.
        layer.enabled: !idPanel.slides && idPanel.reveal > 0 && idPanel.reveal < 1

        // Default focus, so a key release reaches this item in a panel with
        // no focused field; a field inside still passes its release up here.
        focus: true

        Window.onActiveChanged: root.applyKeyboardStep(PanelKeyboardLogic.windowActiveChanged(root.keyboardState, idPanel.Window.active, root.panelVisible))

        Keys.onReleased: event => root.applyKeyboardStep(PanelKeyboardLogic.keyReleased(root.keyboardState, event.key === Qt.Key_Escape, event.isAutoRepeat), event)

        // Inverted ternaries: the Behavior starts before these bindings
        // refresh (CODING_STANDARDS.md), so they read the previous state.
        Behavior on reveal {
            NumberAnimation {
                duration: {
                    if (root.instantReveal && !root.panelVisible)
                        return 0;
                    if (root.attachedToBar)
                        return root.panelVisible ? Globals.dashboardCloseMs : Globals.dashboardOpenMs;
                    return root.panelVisible ? Globals.centerCloseMs : Globals.centerOpenMs;
                }
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Globals.easeOutCurve
            }
        }

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

    function keyboardFocusFor(mode) {
        if (mode === "exclusive")
            return WlrKeyboardFocus.Exclusive;
        if (mode === "onDemand")
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }

    function applyKeyboardStep(step, event) {
        root.keyboardTaken = step.state.keyboardTaken;
        root.escapeArmed = step.state.escapeArmed;
        if (step.accepted === true)
            event.accepted = true;
        if (step.close)
            root.outsideClicked();
    }
}
