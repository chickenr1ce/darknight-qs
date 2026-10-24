pragma Singleton

import QtQuick

// The palette slice components/BarSlot.qml reads (the lift outline). The real
// Colors.qml binds the theme service, which has no business loading offscreen.
QtObject {
    id: root

    readonly property color background: "#141118"
    readonly property color backgroundSecondary: "#27222f"
    readonly property color text: "#cac4d4"
    readonly property color accent: "#b4befe"

    function mixInto(base: color, tint: color, amount: real): color {
        return Qt.rgba(base.r + (tint.r - base.r) * amount,
                       base.g + (tint.g - base.g) * amount,
                       base.b + (tint.b - base.b) * amount,
                       1.0);
    }
}
