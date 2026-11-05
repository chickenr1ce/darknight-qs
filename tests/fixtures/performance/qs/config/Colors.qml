pragma Singleton

import QtQuick

// The palette slice the Performance tab and its components read. The real
// Colors.qml binds the theme service, which has no business loading offscreen.
QtObject {
    id: root

    readonly property color accent: "#b4befe"
    readonly property color accentDim: "#3a3a5a"
    readonly property color border: "#2a2a35"
    readonly property color card: "#141118"
    readonly property color cardSecondary: "#27222f"
    readonly property color criticalCard: "#301418"
    readonly property color criticalCardBorder: "#501418"
    readonly property color danger: "#f38ba8"
    readonly property color onAccent: root.card
    readonly property color text: "#cac4d4"
    readonly property color textSubtle: "#8a8494"
    readonly property color warning: "#f9e2af"
}
