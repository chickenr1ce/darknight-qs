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
        id: idThemedAppRows

        model: ThemeService.themeTargets

        delegate: SettingsToggleRow {
            Layout.fillWidth: true

            required property var modelData

            visible: SettingsFilter.matches(root.filter, modelData.title)
            label: modelData.title
            value: ThemeService.isThemeTargetEnabled(modelData.key)
            onToggled: ThemeService.setThemeTargetEnabled(modelData.key, !value)
        }
    }
}
