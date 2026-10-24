import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import "../services/BarLayoutLogic.js" as BarLayoutLogic

Item {
    id: root

    required property var dragGeometry
    property string key: ""
    // Overridable so the offscreen test does not have to sleep the shipped
    // hold; the default reads the one token.
    property int holdMs: Globals.barDragHoldMs
    property bool liftOutlineShown: false

    // The press lifecycle: a passive grab starts the hold, the hold arms the
    // drag, an ungrab ends it. BarLayoutLogic.pressTransition owns every
    // decision; this item owns the effects and their state.
    property bool pressHeld: false
    property bool armed: false
    property bool trayMenuOpenAtPress: false

    default property alias content: root.data

    readonly property Item module: {
        for (let i = 0; i < root.children.length; i++) {
            const child = root.children[i];
            if (!(child === idModuleLiftOutline))
                return child;
        }
        return null;
    }
    readonly property bool shown: root.module !== null && root.module.visible
    // The module that owns the tray menu declares this, so no one else has to
    // spell its key: a press on it must not dismiss its own menu.
    readonly property bool moduleOwnsTrayMenu: root.module !== null && root.module.ownsTrayMenu === true
    readonly property real dragPointerX: idModuleDragHandler.centroid.scenePosition.x - Globals.slabInset
    readonly property real dragPointerY: idModuleDragHandler.centroid.scenePosition.y

    implicitWidth: root.module !== null ? root.module.implicitWidth : 0
    implicitHeight: Globals.barHeight
    width: root.implicitWidth
    height: root.implicitHeight
    z: root.armed ? 1 : 0
    scale: root.armed ? Globals.barDragLiftScale : 1.0

    Component.onDestruction: root.abandonDrag()
    onShownChanged: {
        if (!root.shown)
            root.abandonDrag();
    }

    // The outline only exists while a drag is armed or fading out: a hidden
    // Shape per slot still costs its creation and re-tessellates on resize.
    Loader {
        id: idModuleLiftOutline

        anchors {
            fill: parent
            leftMargin: Globals.dropSlotInset
            rightMargin: Globals.dropSlotInset
            topMargin: Globals.moduleMargin
            bottomMargin: Globals.moduleMargin
        }
        z: 1

        active: root.armed || root.liftOutlineShown

        sourceComponent: Shape {
            id: idLiftShape

            opacity: 0
            visible: opacity > 0

            Component.onCompleted: idLiftShape.opacity = Qt.binding(() => root.armed ? 1 : 0)
            onOpacityChanged: root.liftOutlineShown = idLiftShape.opacity > 0

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.mixInto(Colors.background, Colors.text, 0.32)
                strokeWidth: Globals.hairlineHeight
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin

                PathRectangle {
                    x: Globals.hairlineHeight / 2
                    y: Globals.hairlineHeight / 2
                    width: idLiftShape.width - Globals.hairlineHeight
                    height: idLiftShape.height - Globals.hairlineHeight
                    radius: Globals.radius
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

    HoverHandler {
        id: idDragCursorHandler

        enabled: root.armed
        cursorShape: Qt.ClosedHandCursor
    }

    DragHandler {
        id: idModuleDragHandler

        enabled: root.shown
        acceptedButtons: Qt.LeftButton
        target: null

        onGrabChanged: (transition, point) => root.applyPressEvent(root.grabEvent(transition))
        onCentroidChanged: {
            if (root.armed && BarLayoutService.dragging)
                BarLayoutService.updateDrag(root.dragPointerX, root.dragPointerY, root.dragGeometry);
        }
        onActiveChanged: root.applyPressEvent(idModuleDragHandler.active ? BarLayoutLogic.DRAG_START : BarLayoutLogic.DRAG_END)
    }

    Timer {
        id: idHoldTimer

        interval: root.holdMs
        onTriggered: root.applyPressEvent(BarLayoutLogic.HOLD)
    }

    // A press that armed the drag must not click the module on release. An
    // overlay would take the press and starve the module (ADR 0021), so the
    // slot disables the module for the armed span instead: disabling an item
    // delivers a cancel to its MouseArea (and its children's), which no module
    // has to know about. A HoverHandler stays hovered through the disable; a
    // MouseArea's containsMouse drops until the pointer next moves, so a
    // MouseArea hover tint clears for the armed span. The override runs only
    // for that span: when `armed` goes false Qt 6 restores the module's own
    // enabled binding (or plain value), so a module that binds `enabled` keeps
    // owning it. restoreMode is spelled out for that guarantee.
    Binding {
        target: root.module
        property: "enabled"
        value: false
        when: root.module !== null && root.armed
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root.module
        property: "width"
        value: root.width
        when: root.module !== null
    }

    Binding {
        target: root.module
        property: "height"
        value: root.height
        when: root.module !== null
    }

    Behavior on scale {
        NumberAnimation {
            duration: Globals.reducedMotion ? 0 : Globals.hoverMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Globals.easeOutCurve
        }
    }

    Behavior on x {
        enabled: !root.armed && BarLayoutService.reorderMotion
        NumberAnimation {
            duration: Globals.reducedMotion ? 0 : Globals.barReorderMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Globals.easeInOutCurve
        }
    }

    function abandonDrag(): void {
        root.applyPressEvent(BarLayoutLogic.ABANDON);
    }

    // The one place the Qt grab enum is read: a .pragma library cannot see it.
    // Everything else about the transition lives in BarLayoutLogic.
    function grabEvent(transition): string {
        if (transition === PointerDevice.GrabPassive)
            return BarLayoutLogic.PRESS;
        if (transition === PointerDevice.UngrabPassive || transition === PointerDevice.CancelGrabPassive || transition === PointerDevice.UngrabExclusive || transition === PointerDevice.CancelGrabExclusive)
            return BarLayoutLogic.RELEASE;
        return BarLayoutLogic.OTHER;
    }

    function applyPressEvent(event): void {
        const state = { pressed: root.pressHeld, armed: root.armed, trayMenuOpenAtPress: root.trayMenuOpenAtPress };
        const result = BarLayoutLogic.pressTransition(state, event, {
            handlerActive: idModuleDragHandler.active,
            ownsTrayMenu: root.moduleOwnsTrayMenu,
            // Only a press snapshots the menu; shutdown must not touch services.
            trayMenuVisible: event === BarLayoutLogic.PRESS && TrayMenuService.panelState.visible
        });
        root.pressHeld = result.state.pressed;
        root.armed = result.state.armed;
        root.trayMenuOpenAtPress = result.state.trayMenuOpenAtPress;
        for (let i = 0; i < result.effects.length; i++)
            root.applyEffect(result.effects[i]);
    }

    function applyEffect(effect): void {
        switch (effect) {
        case BarLayoutLogic.EFFECT_START_HOLD:
            idHoldTimer.restart();
            break;
        case BarLayoutLogic.EFFECT_STOP_HOLD:
            idHoldTimer.stop();
            break;
        case BarLayoutLogic.EFFECT_BEGIN_DRAG:
            BarLayoutService.beginDrag(root.key, root.dragPointerX, root.dragPointerY);
            break;
        case BarLayoutLogic.EFFECT_END_DRAG:
            BarLayoutService.endDrag();
            break;
        case BarLayoutLogic.EFFECT_CANCEL_DRAG:
            BarLayoutService.cancelDrag();
            break;
        case BarLayoutLogic.EFFECT_DISMISS_TRAY:
            TrayMenuService.dismiss();
            break;
        }
    }
}
