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

    // Semantic roles for panels and plugins; aliases so theme changes touch values above only.
    readonly property color panel: background
    readonly property color panelBorder: surface
    readonly property color card: background
    readonly property color cardSecondary: backgroundSecondary
    readonly property color border: surface
    readonly property color accent: lavender
    readonly property color onAccent: background
    readonly property color danger: red
    readonly property color warning: yellow
    readonly property color accentSecondary: purple

    function appColor(appName: string): color {
        const key = (appName || "").trim().toLowerCase();
        if (key === "")
            return root.accent;
        let hash = 5381;
        for (let i = 0; i < key.length; i++)
            hash = (((hash * 33) + key.charCodeAt(i)) >>> 0);
        return Qt.hsla((((hash % 11) + 1) * 30) / 360, 0.65, 0.72, 1.0);
    }
}
