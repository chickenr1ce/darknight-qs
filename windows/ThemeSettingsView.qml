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
            Layout.fillWidth: true

            required property var modelData

            visible: SettingsFilter.matches(root.filter, modelData.displayName) || SettingsFilter.matches(root.filter, modelData.name)
            text: modelData.displayName
            active: modelData.name === ThemeService.activeTheme
            onClicked: ThemeService.selectTheme(modelData.name)
        }
    }
}
