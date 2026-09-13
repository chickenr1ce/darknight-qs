pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property color background: "#141118"          // rgba(20,17,24,0.95)
    readonly property color backgroundSecondary: "#27222f"
    readonly property color text: "#cac4d4"
    readonly property color textSecondary: "#4f455f"
    // Old textSecondary (~2.2:1) kept for decorative glyphs only; reading text needs ~7:1.
    readonly property color textSubtle: "#9d93ad"
    // Red mixed into background at ~10%: urgent without border effects.
    readonly property color criticalCard: "#2a161c"
    readonly property color criticalCardBorder: "#40222b"

    readonly property color purple: "#a980db"
    readonly property color red: "#ff5252"
    readonly property color yellow: "#d7d370"
    readonly property color lavender: "#b4befe"
    readonly property color surface: "#282936"
}
