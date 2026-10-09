import QtQuick
import QtTest

// The wheel path SmoothWheel picks depends on the input source: a mouse wheel
// must take the stepped angleDelta path even when Wayland attaches a small
// pixelDelta, and only a touchpad takes the 1:1 pixel path. That needs
// WheelEvent.device (a PointerDevice) and PointerDevice.TouchPad; if either
// disappeared, every wheel would silently route down the pixel path again.
// This runs offscreen and is wired into scripts/test-app-launcher.sh.
TestCase {
    id: root

    property int wheels: 0
    property int wheelDeviceType: -1
    property bool wheelHasDevice: false

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
                    root.wheelHasDevice = wheel.device !== null;
                    root.wheelDeviceType = wheel.device ? wheel.device.type : -1;
                }
            }
        }
    }

    function test_pointerDeviceTypeExists(): void {
        verify(typeof PointerDevice !== "undefined", "PointerDevice is available");
        compare(PointerDevice.TouchPad === PointerDevice.Mouse, false,
            "TouchPad and Mouse are distinct device types");
    }

    function test_mouseWheelCarriesDevice(): void {
        root.wheels = 0;
        root.wheelDeviceType = -1;
        root.wheelHasDevice = false;
        mouseWheel(idWheelArea, 50, 50, 0, 120);
        wait(50);
        compare(root.wheels, 1, "the wheel event is delivered");
        verify(root.wheelHasDevice, "the wheel event carries a device");
        compare(root.wheelDeviceType, PointerDevice.Mouse,
            "a synthetic mouse wheel reports the Mouse device type");
    }
}
