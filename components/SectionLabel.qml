import QtQuick
import qs.config

// Section heading inside a panel: an uppercase caption that sits below the
// panel title (PanelHeader) instead of competing with it. Callers pass the
// text in normal case; the font capitalises it.
Text {
    id: root

    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: Colors.textSubtle

    font {
        family: Globals.uiFontFamily
        pixelSize: Globals.uiCaptionSize
        weight: Font.Medium
        letterSpacing: Globals.uiLetterSpacing
        capitalization: Font.AllUppercase
    }
}
