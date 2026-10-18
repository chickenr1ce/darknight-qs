import QtQuick
import QtTest

// Mirrors components/BarSlot.qml's input shape: the DragHandler sits on the
// slot behind the module, and a hold timer started from its passive grab arms
// the drag. A handler in an overlay above the module would take the press and
// starve the module's MouseArea (seen live 2026-10-18: no bar click opened a
// panel). Wired into scripts/test-bar-layout.sh.
TestCase {
    id: root

    property bool armed: false
    property real armedX: -1
    property int clicks: 0
    property int rightClicks: 0
    property int drags: 0

    name: "BarSlotHandlers"
    when: windowShown

    Window {
        width: 300
        height: 100
        visible: true

        Item {
            id: idSlot

            width: 100
            height: 40

            DragHandler {
                id: idDrag

                acceptedButtons: Qt.LeftButton
                target: null

                onGrabChanged: (transition, point) => {
                    if (transition === PointerDevice.GrabPassive) {
                        idHold.restart();
                        return;
                    }
                    if (transition === PointerDevice.UngrabPassive || transition === PointerDevice.CancelGrabPassive || transition === PointerDevice.UngrabExclusive || transition === PointerDevice.CancelGrabExclusive)
                        idHold.stop();
                }
                onActiveChanged: {
                    if (idDrag.active && !root.armed)
                        idHold.stop();
                    if (idDrag.active && root.armed)
                        root.drags = root.drags + 1;
                }
            }

            Timer {
                id: idHold

                interval: 300
                onTriggered: {
                    root.armed = true;
                    root.armedX = idDrag.centroid.scenePosition.x;
                }
            }

            Item {
                anchors.fill: parent

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            root.rightClicks = root.rightClicks + 1;
                        else if (!root.armed)
                            root.clicks = root.clicks + 1;
                    }
                }
            }
        }
    }

    function init() {
        root.armed = false;
        root.armedX = -1;
        root.clicks = 0;
        root.rightClicks = 0;
        root.drags = 0;
    }

    function test_clickReachesModule() {
        mouseClick(idSlot, 50, 20);
        wait(400);
        compare(root.clicks, 1);
        verify(!root.armed);
    }

    function test_rightClickUntouched() {
        mouseClick(idSlot, 50, 20, Qt.RightButton);
        compare(root.rightClicks, 1);
        verify(!root.armed);
    }

    function test_holdArmsAtPressPoint() {
        mousePress(idSlot, 50, 20);
        wait(450);
        verify(root.armed);
        compare(root.armedX, 50);
        mouseMove(idSlot, 70, 20);
        mouseMove(idSlot, 90, 20);
        mouseRelease(idSlot, 90, 20);
        compare(root.drags, 1);
        compare(root.clicks, 0);
    }

    function test_quickDragNeverArms() {
        mousePress(idSlot, 50, 20);
        mouseMove(idSlot, 70, 20);
        mouseMove(idSlot, 90, 20);
        wait(450);
        mouseRelease(idSlot, 90, 20);
        verify(!root.armed);
        compare(root.drags, 0);
    }
}
