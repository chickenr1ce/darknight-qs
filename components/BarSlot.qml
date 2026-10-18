import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services

Item {
    id: root

    required property var dragGeometry
    property string key: ""
    property bool armed: false
    property bool trayMenuOpenAtPress: false
    property bool liftOutlineShown: false

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
                    duration: Globals.reducedMotion ? 0 : Globals.hoverMs
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

        onGrabChanged: (transition, point) => {
            if (transition === PointerDevice.GrabPassive) {
                root.trayMenuOpenAtPress = TrayMenuService.panelState.visible;
                idHoldTimer.restart();
                return;
            }
            const released = transition === PointerDevice.UngrabPassive || transition === PointerDevice.CancelGrabPassive || transition === PointerDevice.UngrabExclusive || transition === PointerDevice.CancelGrabExclusive;
            if (!released)
                return;
            idHoldTimer.stop();
            if (root.armed && !idModuleDragHandler.active)
                root.releaseDrag();
            if (!root.armed && root.trayMenuOpenAtPress && !(root.key === "tray"))
                TrayMenuService.dismiss();
            root.trayMenuOpenAtPress = false;
        }
        onCentroidChanged: {
            if (root.armed && BarLayoutService.dragging)
                BarLayoutService.updateDrag(root.dragPointerX, root.dragPointerY, root.dragGeometry);
        }
        onActiveChanged: {
            if (idModuleDragHandler.active && !root.armed)
                idHoldTimer.stop();
            if (!idModuleDragHandler.active && root.armed)
                root.releaseDrag();
        }
    }

    Timer {
        id: idHoldTimer

        interval: Globals.barDragHoldMs
        onTriggered: {
            root.armed = true;
            BarLayoutService.beginDrag(root.key, root.dragPointerX, root.dragPointerY);
        }
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
        }
    }

    Behavior on x {
        enabled: !root.armed && BarLayoutService.reorderMotion
        NumberAnimation {
            duration: Globals.reducedMotion ? 0 : Globals.barReorderMs
        }
    }

    function abandonDrag(): void {
        idHoldTimer.stop();
        if (!root.armed)
            return;
        root.armed = false;
        BarLayoutService.cancelDrag();
    }

    function releaseDrag(): void {
        if (!root.armed)
            return;
        root.armed = false;
        BarLayoutService.endDrag();
    }
}
