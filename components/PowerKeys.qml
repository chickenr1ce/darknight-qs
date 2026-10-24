pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import qs.services

// The bar power card's keyboard shortcuts. They sit beside the card because
// PanelShell is a layer-shell window that an offscreen qmltestrunner cannot
// host; tests/power-keys.qml drives this component with a recorder service, so
// the key the card draws is proven to reach the action it labels.
Item {
    id: root

    // The card takes keys only while it is on screen. PowerCenter binds this to
    // its panel visibility.
    property bool active: false

    // A non-visual shortcut host must not take layout space in the PanelShell
    // column.
    visible: false

    Instantiator {
        id: idPowerHintKeys

        model: PowerService.actions

        delegate: Shortcut {
            required property var modelData

            enabled: root.active
            sequence: modelData.hint
            onActivated: PowerService.pressKey(modelData.hint)
        }
    }

    Instantiator {
        id: idPowerConfirmKeys

        model: PowerService.confirmKeys

        delegate: Shortcut {
            required property string modelData

            enabled: root.active
            sequence: modelData
            onActivated: PowerService.pressKey(modelData)
        }
    }
}
