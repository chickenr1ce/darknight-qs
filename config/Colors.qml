pragma Singleton
import QtQuick
import qs.services

QtObject {
    id: root

    readonly property string mode: ThemeService.hasPalette ? ThemeService.mode : ""

    readonly property color background: ThemeService.hasPalette ? ThemeService.background : "#141118"
    readonly property color backgroundSecondary: ThemeService.hasPalette ? ThemeService.dark_background : "#27222f"
    readonly property color surface: ThemeService.hasPalette ? ThemeService.lighter_background : "#282936"

    readonly property color text: ThemeService.hasPalette ? ThemeService.foreground : "#cac4d4"
    readonly property color textSecondary: ThemeService.hasPalette ? (ThemeService.mode === "light" ? ThemeService.light_foreground : ThemeService.dark_foreground) : "#4f455f"
    readonly property color textSubtle: ThemeService.hasPalette ? ThemeService.muted : "#9d93ad"

    readonly property color accent: ThemeService.hasPalette ? ThemeService.accent : "#b4befe"
    readonly property color purple: ThemeService.hasPalette ? ThemeService.magenta : "#a980db"
    readonly property color red: ThemeService.hasPalette ? ThemeService.red : "#ff5252"
    readonly property color yellow: ThemeService.hasPalette ? ThemeService.yellow : "#d7d370"

    readonly property color criticalCard: ThemeService.hasPalette ? root.mixInto(root.background, ThemeService.red, 0.10) : "#2a161c"
    readonly property color criticalCardBorder: ThemeService.hasPalette ? root.mixInto(root.background, ThemeService.red, 0.22) : "#40222b"

    readonly property color panel: background
    readonly property color panelBorder: surface
    readonly property color card: background
    readonly property color cardSecondary: backgroundSecondary
    readonly property color border: surface
    readonly property color lavender: accent
    readonly property color accentDim: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
    readonly property color onAccent: background
    readonly property color danger: red
    readonly property color warning: yellow
    readonly property color accentSecondary: purple

    readonly property var themeSwatches: [root.accent, root.purple, root.text, root.surface, root.background]

    function mixInto(base: color, tint: color, amount: real): color {
        return Qt.rgba(
            base.r + (tint.r - base.r) * amount,
            base.g + (tint.g - base.g) * amount,
            base.b + (tint.b - base.b) * amount,
            1.0);
    }

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
