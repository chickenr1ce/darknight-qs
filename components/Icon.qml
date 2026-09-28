pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Icon-font glyph (qs.config Icons). Draws in the shared icon family so no
// glyph falls back to a foreign font; size and color are caller-controlled.
Text {
    id: root

    property int size: Globals.uiBodySize

    textFormat: Text.PlainText
    color: Colors.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    font {
        family: Globals.iconFontFamily
        pixelSize: root.size
    }
}
