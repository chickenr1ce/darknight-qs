pragma Singleton

import QtQuick

// Records the tray-menu dismiss a bar slot defers to the release.
QtObject {
    id: root

    property int dismisses: 0
    readonly property QtObject panelState: QtObject {
        property bool visible: false
    }

    function dismiss(): void {
        root.dismisses = root.dismisses + 1;
    }

    function reset(): void {
        root.dismisses = 0;
        root.panelState.visible = false;
    }
}
