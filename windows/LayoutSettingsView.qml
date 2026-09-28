pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool filtering: !(root.filter === "")
    readonly property bool barVisibilityRelevant: root.matches(qsTr("Bar visibility"))

    spacing: Globals.spacing

    function matches(label: string): bool {
        return !root.filtering || label.toLowerCase().includes(root.filter.toLowerCase());
    }

    Repeater {
        model: BarVisibilityService.modules

        delegate: SettingsToggleRow {
            Layout.fillWidth: true

            required property var modelData

            visible: root.barVisibilityRelevant || root.matches(modelData.title)
            label: modelData.title
            value: BarVisibilityService.isVisible(modelData.key)
            onToggled: BarVisibilityService.setVisible(modelData.key, !value)
        }
    }
}
