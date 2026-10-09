import QtQuick
import QtTest

// The scroll path depends on the event's scroll phase: a discrete wheel
// arrives with Qt.NoScrollPhase and must take the stepped angleDelta path,
// while a continuous source (touchpad, momentum) arrives with ScrollBegin or
// ScrollUpdate and takes the 1:1 pixel path. Qt Wayland reports every seat
// pointer as a "touchpad" device, so the device type cannot make this call.
// This runs offscreen and is wired into scripts/test-app-launcher.sh.
TestCase {
    id: root

    property int wheels: 0
    property int wheelPhase: -1

    name: "AppLauncherWheel"

    Window {
        id: idWheelWindow

        width: 200
        height: 200
        visible: true

        Rectangle {
            anchors.fill: parent
            color: "black"

            MouseArea {
                id: idWheelArea

                anchors.fill: parent
                onWheel: wheel => {
                    root.wheels = root.wheels + 1;
                    root.wheelPhase = wheel.phase;
                }
            }
        }
    }

    function test_scrollPhaseEnum(): void {
        verify(typeof Qt.NoScrollPhase !== "undefined", "Qt.NoScrollPhase is available");
        compare(Qt.NoScrollPhase === Qt.ScrollBegin, false,
            "NoScrollPhase and ScrollBegin are distinct");
        compare(Qt.NoScrollPhase === Qt.ScrollUpdate, false,
            "NoScrollPhase and ScrollUpdate are distinct");
        compare(Qt.NoScrollPhase === Qt.ScrollEnd, false,
            "NoScrollPhase and ScrollEnd are distinct");
        compare(Qt.NoScrollPhase === Qt.ScrollMomentum, false,
            "NoScrollPhase and ScrollMomentum are distinct");
    }

    function test_mouseWheelIsDiscrete(): void {
        root.wheels = 0;
        root.wheelPhase = -1;
        mouseWheel(idWheelArea, 50, 50, 0, 120);
        wait(50);
        compare(root.wheels, 1, "the wheel event is delivered");
        compare(root.wheelPhase, Qt.NoScrollPhase,
            "a synthetic mouse wheel reports NoScrollPhase");
    }
}
