pragma Singleton

import QtQuick
import "../../../../../services/PowerLogic.js" as PowerLogic

// Records what components/PowerKeys.qml asks of the power service. Routing runs
// the shipped PowerLogic.route, so the offscreen test covers the same decision
// the real PowerService makes; only the process, panel and lock adapters are
// stubs here.
QtObject {
    id: root

    property string armedAction: ""
    property int presses: 0
    property int confirms: 0
    property string confirmed: ""
    property int disarms: 0
    property int closes: 0
    property int locks: 0

    readonly property var actions: PowerLogic.rows("bar")
    readonly property var confirmKeys: PowerLogic.confirmKeys()
    readonly property QtObject panelState: QtObject {
        property bool visible: true
    }

    function pressKey(key: string): void {
        root.presses = root.presses + 1;
        const route = PowerLogic.route("bar", root.armedAction, key);
        if (route.kind === "arm")
            root.arm(route.id);
        else if (route.kind === "confirm")
            root.confirmArmed();
        else if (route.kind === "disarm")
            root.cancel();
        else if (route.kind === "close") {
            root.closes = root.closes + 1;
            root.panelState.visible = false;
        }
    }

    // The shipped arm path: Lock locks the session and closes the card, every
    // other row arms.
    function arm(actionId: string): void {
        const armed = root.armedAction;
        const result = PowerLogic.press({ armed: armed }, actionId);
        root.armedAction = result.state.armed;
        if (result.lock === true) {
            root.locks = root.locks + 1;
            root.panelState.visible = false;
        }
    }

    function confirmArmed(): void {
        const armed = root.armedAction;
        const result = PowerLogic.confirm({ armed: armed });
        root.armedAction = result.state.armed;
        if (result.run === null)
            return;
        root.confirms = root.confirms + 1;
        root.confirmed = armed;
        root.panelState.visible = false;
    }

    function cancel(): void {
        root.armedAction = "";
        root.disarms = root.disarms + 1;
    }

    function reset(): void {
        root.armedAction = "";
        root.presses = 0;
        root.confirms = 0;
        root.confirmed = "";
        root.disarms = 0;
        root.closes = 0;
        root.locks = 0;
        root.panelState.visible = true;
    }
}
