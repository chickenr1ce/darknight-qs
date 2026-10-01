pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    ColumnLayout {
        id: idThemeColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Text {
            id: idThemeCaption

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Theme")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        RowLayout {
            id: idThemeSwatches

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            Repeater {
                id: idThemeSwatchRepeater

                model: [Colors.lavender, Colors.purple, Colors.yellow, Colors.red]

                delegate: Rectangle {
                    id: idThemeSwatch

                    Layout.preferredWidth: Globals.uiDisplaySize
                    Layout.preferredHeight: Globals.uiDisplaySize

                    required property color modelData
                    required property int index

                    radius: width / 2
                    color: idThemeSwatch.modelData
                }
            }
        }

        Text {
            id: idWallpaperCaption

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Wallpaper")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        GridLayout {
            id: idWallpaperGrid

            Layout.fillWidth: true

            columns: 2
            columnSpacing: Globals.rowSpacing
            rowSpacing: Globals.rowSpacing

            Repeater {
                id: idWallpaperRepeater

                model: 4

                delegate: Rectangle {
                    id: idWallpaperTile

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.wallpaperTileHeight

                    required property int index

                    radius: Globals.pillRadius
                    color: Colors.cardSecondary
                    border.width: Globals.hairlineHeight
                    border.color: Colors.border
                }
            }
        }
    }
}
