pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "SmoothWheelLogic.js" as SmoothWheelLogic

// Transparent overlay for a Flickable: the scroll path is chosen by the
// event's scroll phase (SmoothWheelLogic.wheelMode). A discrete wheel
// (Qt.NoScrollPhase) glides contentY by Globals.wheelStep over Globals.wheelMs;
// one notch (a 120 angleDelta) is one step, a finer or coarser chunk scales
// proportionally, and rapid notches accumulate into one target. A continuous
// source (a touchpad or momentum scroll, any other phase) scrolls 1:1 on
// pixelDelta. A user drag cancels the glide; keyboard scrolling stops it
// through stop() before positionViewAtIndex.
Item {
    id: root

    property Flickable flickable: null
    property real target: 0

    signal wheelStarted()

    anchors.fill: root.flickable
    visible: root.flickable !== null
    enabled: root.flickable !== null

    function stop(): void {
        idWheelAnimation.stop();
    }

    function jumpTo(value: real): void {
        root.stop();
        if (root.flickable)
            root.flickable.contentY = value;
    }

    function moveTo(value: real): void {
        if (Globals.reducedMotion) {
            root.jumpTo(value);
            return;
        }
        root.target = value;
        idWheelAnimation.restart();
    }

    function isContinuousScroll(event): bool {
        if (!event)
            return false;
        return event.phase !== Qt.NoScrollPhase;
    }

    function handleWheel(event): void {
        if (!root.flickable)
            return;
        const mode = SmoothWheelLogic.wheelMode(event.angleDelta.y, event.pixelDelta.y,
            root.isContinuousScroll(event));
        if (mode === "pixel") {
            const pixelDelta = event.pixelDelta.y;
            const next = SmoothWheelLogic.clampTarget(root.flickable.originY,
                root.flickable.contentHeight, root.flickable.height,
                root.flickable.contentY - pixelDelta);
            if (next === root.flickable.contentY)
                return;
            root.jumpTo(next);
            root.wheelStarted();
            event.accepted = true;
            return;
        }
        if (mode !== "angle")
            return;
        const angleDelta = event.angleDelta.y;
        const max = root.flickable.originY + Math.max(0,
            root.flickable.contentHeight - root.flickable.height);
        const result = SmoothWheelLogic.wheelStep(root.flickable.contentY, root.target,
            idWheelAnimation.running, angleDelta, Globals.wheelStep, root.flickable.originY, max);
        if (!result.moved)
            return;
        root.moveTo(result.target);
        root.wheelStarted();
        event.accepted = true;
    }

    MouseArea {
        id: idWheel

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            wheel.accepted = false;
            root.handleWheel(wheel);
        }
    }

    NumberAnimation {
        id: idWheelAnimation

        target: root.flickable
        property: "contentY"
        to: root.target
        duration: Globals.wheelMs
        easing.type: Easing.OutCubic
    }

    Connections {
        id: idWheelFlickableWatch

        target: root.flickable

        function onMovingChanged(): void {
            if (root.flickable && root.flickable.moving)
                root.stop();
        }
    }
}
