pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property bool disabled: false
    property string accessibleName: ""

    signal moved(real value)

    readonly property real ratio: {
        const span = root.to - root.from;
        if (span <= 0)
            return 0;
        return Math.max(0, Math.min(1, (root.value - root.from) / span));
    }
    readonly property int trackHeight: 4
    readonly property int handleSize: 12
    readonly property int handleRadius: 6

    implicitWidth: 120
    implicitHeight: 18
    opacity: root.disabled ? 0.45 : 1
    activeFocusOnTab: !root.disabled

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName

    Keys.onLeftPressed: root.stepBy(-1)
    Keys.onDownPressed: root.stepBy(-1)
    Keys.onRightPressed: root.stepBy(1)
    Keys.onUpPressed: root.stepBy(1)

    Rectangle {
        id: idSliderTrack

        anchors.verticalCenter: parent.verticalCenter
        x: root.handleRadius
        width: parent.width - 2 * root.handleRadius
        height: root.trackHeight

        radius: root.trackHeight / 2
        color: Colors.cardSecondary
    }

    Rectangle {
        id: idSliderFill

        anchors.verticalCenter: parent.verticalCenter
        x: root.handleRadius
        width: Math.max(0, (parent.width - 2 * root.handleRadius) * root.ratio)
        height: root.trackHeight

        radius: root.trackHeight / 2
        color: Colors.accent
    }

    Rectangle {
        id: idSliderHandle

        anchors.verticalCenter: parent.verticalCenter
        x: root.handleRadius + (parent.width - 2 * root.handleRadius) * root.ratio - root.handleRadius
        width: root.handleSize
        height: root.handleSize

        radius: root.handleRadius
        color: Colors.text
        border.width: root.activeFocus ? 1 : 0
        border.color: Colors.accent
    }

    MouseArea {
        id: idSliderMouseArea

        anchors.fill: parent
        enabled: !root.disabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => root.setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.setFromX(mouse.x);
        }
    }

    function setFromX(px: real): void {
        const span = root.to - root.from;
        if (span <= 0)
            return;
        const trackW = root.width - 2 * root.handleRadius;
        if (trackW <= 0)
            return;
        const r = Math.max(0, Math.min(1, (px - root.handleRadius) / trackW));
        const raw = root.from + r * span;
        const snapped = Math.round(raw / root.stepSize) * root.stepSize;
        const clamped = Math.max(root.from, Math.min(root.to, snapped));
        if (!(clamped === root.value))
            root.moved(clamped);
    }

    function stepBy(dir: int): void {
        if (root.disabled)
            return;
        const next = Math.max(root.from, Math.min(root.to, root.value + dir * root.stepSize));
        if (!(next === root.value))
            root.moved(next);
    }
}
