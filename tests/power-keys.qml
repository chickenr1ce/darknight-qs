import QtQuick
import QtTest
import qs.services
import "../components"

// Drives the real components/PowerKeys.qml with a recorder PowerService whose
// routing is the shipped PowerLogic.route: every hint the power card draws must
// arm the row it labels, and Return/Enter must confirm the armed row. The bar
// card itself is a PanelShell (a layer-shell window an offscreen runner cannot
// host), so PowerCenter takes these shortcuts from this component. Wired into
// scripts/test-panel-logic.sh.
TestCase {
    id: root

    name: "PowerKeys"
    when: windowShown

    PowerKeys {
        id: idPowerKeys

        active: true
    }

    // The shipped card's Escape belongs to PanelShell, which closes the panel
    // and leaves the service to disarm. This stands in for that window-level key
    // so the same route runs under the offscreen window.
    Shortcut {
        id: idEscapeKey

        sequence: "Escape"
        onActivated: PowerService.pressKey("Escape")
    }

    function init(): void {
        PowerService.reset();
        idPowerKeys.active = true;
        wait(20);
    }

    function test_everyDrawnHintRoutesToItsRow(): void {
        const rows = PowerService.actions;
        verify(rows.length > 0, "the card draws rows");
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            keyClick(row.hint);
            if (row.id === "lock") {
                compare(PowerService.locks, 1, "the Lock row locks the session instead of arming");
                compare(PowerService.armedAction, "", "Lock leaves nothing armed");
            } else {
                compare(PowerService.armedAction, row.id, "the key drawn on the " + row.label + " row arms that action");
            }
            PowerService.reset();
            wait(10);
        }
    }

    function test_returnAndEnterConfirmTheArmedRow(): void {
        keyClick("4");
        compare(PowerService.armedAction, PowerService.actions[3].id, "4 arms the fourth drawn row");
        keyClick(Qt.Key_Return);
        compare(PowerService.confirms, 1, "Return confirms the armed row");
        compare(PowerService.confirmed, PowerService.actions[3].id);
        compare(PowerService.armedAction, "", "a confirm disarms");

        keyClick("2");
        keyClick(Qt.Key_Enter);
        compare(PowerService.confirms, 2, "Enter confirms too");
        compare(PowerService.confirmed, PowerService.actions[1].id);
    }

    function test_escapeDisarmsThenCloses(): void {
        keyClick("6");
        compare(PowerService.armedAction, PowerService.actions[5].id);
        keyClick(Qt.Key_Escape);
        compare(PowerService.disarms, 1, "Escape disarms an armed row");
        compare(PowerService.armedAction, "");
        compare(PowerService.panelState.visible, true, "a disarm leaves the card open");

        keyClick(Qt.Key_Escape);
        compare(PowerService.disarms, 1, "nothing is left to disarm");
        compare(PowerService.closes, 1, "an unarmed Escape closes the card");
        compare(PowerService.panelState.visible, false);
    }

    function test_hiddenCardTakesNoKeys(): void {
        idPowerKeys.active = false;
        keyClick("4");
        compare(PowerService.presses, 0, "a card that is not on screen routes nothing");
        compare(PowerService.armedAction, "");
    }
}
