pragma Singleton
import QtQuick

// Shared geometry/layout constants (mirrors waybar config.jsonc + style.css)
QtObject {
    readonly property int barHeight: 28
    readonly property int spacing: 4
    readonly property int modulePadding: 12
    readonly property int moduleMargin: 4
    readonly property int horizontalBarMargin: 15
    readonly property int radius: 5
    readonly property int fontPixelSize: 14
    readonly property string fontFamily: "Iosevka"

    readonly property color backgroundColor: "#141118" // rgba(20,17,24,0.95)
}
