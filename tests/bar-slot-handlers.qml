import QtQuick
import QtTest
import qs.services
import "../components"

// Drives the real components/BarSlot.qml with the real components/ModuleBox.qml
// as its module: the DragHandler sits on the slot behind the module, and the
// slot's short hold arms the drag from its passive grab. A handler in an overlay
// above the module would take the press and starve the module's MouseArea (seen
// live 2026-10-18: no bar click opened a panel), so this exercises the shipped
// input shape, not a copy of it. The test sets the slot's own holdMs, so the
// shipped hold token is not mirrored here. Wired into scripts/test-bar-layout.sh.
TestCase {
    id: root

    readonly property int holdMs: 60

    // Long enough for the hold to fire plus the event delay qmltestrunner adds.
    readonly property int heldMs: root.holdMs + 150

    // The module binds its own enabled; the slot's armed-span override must
    // restore that binding, not replace it with a stale value.
    property bool moduleEnabled: true

    name: "BarSlotHandlers"
    when: windowShown

    Window {
        width: 300
        height: 120
        visible: true

        BarSlot {
            id: idSlot

            key: "clock"
            holdMs: root.holdMs
            dragGeometry: ({ widths: ({ clock: 100, tray: 100 }), visible: ({}), spacing: 10, width: 300 })

            ModuleBox {
                id: idModule

                property bool ownsTrayMenu: false
                property int leftClicks: 0
                property int rightClicks: 0

                enabled: root.moduleEnabled
                minWidth: 100
                enableMouseArea: true
                enableHover: true

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        idModule.rightClicks = idModule.rightClicks + 1;
                    else
                        idModule.leftClicks = idModule.leftClicks + 1;
                }
            }
        }
    }

    function init(): void {
        idSlot.abandonDrag();
        BarLayoutService.reset();
        TrayMenuService.reset();
        idModule.ownsTrayMenu = false;
        idModule.visible = true;
        idModule.leftClicks = 0;
        idModule.rightClicks = 0;
        root.moduleEnabled = true;
        wait(20);
    }

    function test_releaseTransitionsAllEndThePress(): void {
        compare(idSlot.grabEvent(PointerDevice.GrabPassive), "press");
        compare(idSlot.grabEvent(PointerDevice.GrabExclusive), "other");
        compare(idSlot.grabEvent(PointerDevice.UngrabPassive), "release");
        compare(idSlot.grabEvent(PointerDevice.CancelGrabPassive), "release");
        compare(idSlot.grabEvent(PointerDevice.UngrabExclusive), "release");
        compare(idSlot.grabEvent(PointerDevice.CancelGrabExclusive), "release");
    }

    function test_clickReachesModule(): void {
        mouseClick(idSlot, 50, 14);
        wait(50);
        compare(idModule.leftClicks, 1, "a press under the hold clicks the module");
        compare(BarLayoutService.begins, 0, "a click arms nothing");
        verify(!idSlot.armed);
    }

    function test_rightClickUntouched(): void {
        TrayMenuService.panelState.visible = true;
        mouseClick(idSlot, 50, 14, Qt.RightButton);
        wait(50);
        compare(idModule.rightClicks, 1, "the right click still lands");
        compare(BarLayoutService.begins, 0, "the drag handler ignores the right button");
        compare(TrayMenuService.dismisses, 0, "the slot defers the dismiss to the bar-wide area");
    }

    function test_holdArmsAtPressPoint(): void {
        mousePress(idSlot, 50, 14);
        wait(root.heldMs);
        verify(idSlot.armed, "the hold arms the drag");
        verify(!idModule.enabled, "the armed slot disables the module so its press cannot click");
        compare(BarLayoutService.begins, 1, "the hold begins one drag");
        compare(BarLayoutService.draggedKey, "clock");
        compare(BarLayoutService.pointerX, 40, "the drag starts at the press point inside the slab");

        mouseMove(idSlot, 70, 14);
        mouseMove(idSlot, 90, 14);
        mouseMove(idSlot, 110, 14);
        verify(BarLayoutService.updates >= 3, "the armed drag reports its pointer");
        verify(BarLayoutService.lastUpdateX > 40, "the reported pointer follows the drag");

        mouseRelease(idSlot, 110, 14);
        wait(50);
        compare(BarLayoutService.ends, 1, "the release commits once");
        compare(BarLayoutService.cancels, 0);
        compare(idModule.leftClicks, 0, "the drag fires no click");
        verify(!idSlot.armed, "the release disarms");
        verify(idModule.enabled, "the module is input again after the drag");
    }

    function test_holdReleaseWithoutMoveCommitsWithoutClick(): void {
        mousePress(idSlot, 50, 14);
        wait(root.heldMs);
        verify(idSlot.armed);
        mouseRelease(idSlot, 50, 14);
        wait(50);
        compare(BarLayoutService.begins, 1);
        compare(BarLayoutService.ends, 1, "a hold released in place still ends its drag");
        compare(idModule.leftClicks, 0, "the click that ends a hold is swallowed");
        verify(idModule.enabled, "and the module takes input again");
    }

    function test_quickDragNeverArms(): void {
        mousePress(idSlot, 50, 14);
        mouseMove(idSlot, 70, 14);
        mouseMove(idSlot, 90, 14);
        wait(root.heldMs);
        verify(!idSlot.armed, "a drag threshold crossed before the hold never arms");
        compare(BarLayoutService.begins, 0);
        compare(BarLayoutService.ends, 0, "and the release ends nothing");
        mouseRelease(idSlot, 90, 14);
        wait(50);
        compare(BarLayoutService.begins, 0);
        compare(idModule.leftClicks, 0, "the drag handler took the release from the module");
    }

    function test_trayMenuOpenAtPressDismissesOnRelease(): void {
        TrayMenuService.panelState.visible = true;
        mouseClick(idSlot, 50, 14);
        wait(50);
        compare(TrayMenuService.dismisses, 1, "a press on another module defers the tray dismiss to its release");
        compare(idModule.leftClicks, 1);
    }

    function test_trayModuleKeepsItsMenu(): void {
        TrayMenuService.panelState.visible = true;
        idModule.ownsTrayMenu = true;
        mouseClick(idSlot, 50, 14);
        wait(50);
        compare(TrayMenuService.dismisses, 0, "the module that owns the menu keeps it open");
        compare(idModule.leftClicks, 1);
    }

    function test_holdKeepsDeferredDismiss(): void {
        TrayMenuService.panelState.visible = true;
        mousePress(idSlot, 50, 14);
        wait(root.heldMs);
        verify(idSlot.armed);
        compare(TrayMenuService.dismisses, 0, "an armed press dismisses nothing yet");
        mouseRelease(idSlot, 50, 14);
        wait(50);
        compare(TrayMenuService.dismisses, 1, "the release dismisses the menu it found open");
    }

    function test_moduleEnabledBindingSurvivesDrag(): void {
        verify(idModule.enabled, "the module starts enabled through its own binding");

        mousePress(idSlot, 50, 14);
        wait(root.heldMs);
        verify(idSlot.armed);
        verify(!idModule.enabled, "the armed slot disables the module");

        mouseRelease(idSlot, 50, 14);
        wait(50);
        verify(!idSlot.armed);
        verify(idModule.enabled, "the release restores the module's own enabled binding");

        root.moduleEnabled = false;
        compare(idModule.enabled, false, "the module's own binding is live again after the drag");
        root.moduleEnabled = true;
        verify(idModule.enabled, "and it still follows the module");
    }

    function test_hiddenModuleCancelsDrag(): void {
        mousePress(idSlot, 50, 14);
        wait(root.heldMs);
        verify(idSlot.armed);
        idModule.visible = false;
        wait(50);
        verify(!idSlot.armed, "a module that hides mid-drag disarms");
        compare(BarLayoutService.cancels, 1, "and restores the order");
        compare(BarLayoutService.ends, 0, "without committing");
        mouseRelease(idSlot, 50, 14);
        wait(50);
        compare(BarLayoutService.ends, 0);
        compare(BarLayoutService.cancels, 1, "the release adds nothing");
    }
}
