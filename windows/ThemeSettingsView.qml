pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    spacing: Globals.spacing

    Repeater {
        id: idThemeList

        model: ThemeService.catalog

        delegate: NavItem {
            id: idThemeRow

            Layout.fillWidth: true

            required property var modelData

            readonly property string themeName: modelData ? modelData.name : ""
            readonly property string themeLabel: modelData ? modelData.displayName : ""
            readonly property var themeSwatches: modelData ? modelData.swatches : []

            visible: SettingsFilter.matches(root.filter, idThemeRow.themeLabel) || SettingsFilter.matches(root.filter, idThemeRow.themeName)
            text: idThemeRow.themeLabel
            trailingWidth: idThemeSwatches.width
            active: idThemeRow.themeName === ThemeService.activeTheme
            onClicked: ThemeService.selectTheme(idThemeRow.themeName)

            Row {
                id: idThemeSwatches

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Globals.cardHPadding
                }

                spacing: Globals.fieldPadding
                visible: idThemeRow.themeSwatches.length > 0

                Repeater {
                    id: idThemeSwatchRepeater

                    model: idThemeRow.themeSwatches

                    delegate: Rectangle {
                        id: idThemeSwatch

                        required property color modelData

                        width: Globals.themeSwatchChipSize
                        height: Globals.themeSwatchChipSize
                        radius: Globals.pillRadius
                        color: idThemeSwatch.modelData
                        border.width: Globals.hairlineHeight
                        border.color: Colors.border
                    }
                }
            }
        }
    }
}
