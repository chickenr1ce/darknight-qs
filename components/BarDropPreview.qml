import QtQuick
import qs.config

Item {
    id: root

    property bool active: false
    property bool tracking: false

    visible: root.active

    onActiveChanged: {
        if (root.active)
            Qt.callLater(() => root.tracking = root.active);
        else
            root.tracking = false;
    }

    Rectangle {
        id: idDropSlot

        anchors {
            fill: parent
            leftMargin: Globals.dropSlotInset
            rightMargin: Globals.dropSlotInset
            topMargin: Globals.moduleMargin
            bottomMargin: Globals.moduleMargin
        }

        radius: Globals.radius
        color: Colors.mixInto(Colors.background, Colors.text, 0.05)
        border.width: Globals.hairlineHeight
        border.color: Colors.mixInto(Colors.background, Colors.text, 0.18)
    }

    Behavior on x {
        enabled: root.tracking

        NumberAnimation {
            duration: Globals.reducedMotion ? 0 : Globals.barReorderMs
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Globals.easeInOutCurve
        }
    }
}
