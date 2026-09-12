pragma Singleton
import QtQuick

// Palette translated from ~/.config/waybar/colors/colors.css
QtObject {
    id: root

    readonly property color background: "#141118"          // rgba(20,17,24,0.95)
    readonly property color backgroundSecondary: "#27222f"
    readonly property color text: "#cac4d4"
    readonly property color textSecondary: "#4f455f"
    // Reading text on notification surfaces (~7:1 on `background`); the old
    // textSecondary value measured ~2.2:1 and is kept for decorative glyphs
    // only (close ✕). Typography-pass verdict, 2026-08-24.
    readonly property color textSubtle: "#9d93ad"
    // Quiet critical treatment for notification surfaces (prototype verdict,
    // ticket 02): red mixed into `background` at ~10% reads as urgent without
    // border effects. Derived pair kept here so tickets 03/04 can reuse it.
    readonly property color criticalCard: "#2a161c"
    readonly property color criticalCardBorder: "#40222b"

    readonly property color purple: "#a980db"
    readonly property color red: "#ff5252"
    readonly property color yellow: "#d7d370"
    readonly property color lavender: "#b4befe"
    readonly property color surface: "#282936"
}
