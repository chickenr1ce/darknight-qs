pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool barVisibilityRelevant: SettingsFilter.matches(root.filter, qsTr("Bar visibility"))

    spacing: Globals.spacing

    Repeater {
        model: BarVisibilityService.modules

        delegate: SettingsToggleRow {
            Layout.fillWidth: true

            required property var modelData

            visible: root.barVisibilityRelevant || SettingsFilter.matches(root.filter, modelData.title)
            label: modelData.title
            value: BarVisibilityService.isVisible(modelData.key)
            onToggled: BarVisibilityService.setVisible(modelData.key, !value)
        }
    }

    Repeater {
        id: idMarginRows

        model: BarMarginService.rows

        delegate: SettingsSliderRow {
            Layout.fillWidth: true

            required property var modelData

            visible: SettingsFilter.matches(root.filter, modelData.label)
            label: modelData.label
            hint: modelData.hint
            from: 0
            to: modelData.max
            stepSize: 1
            value: BarMarginService.valueFor(modelData.key)
            onMoved: newValue => BarMarginService.setMargin(modelData.key, newValue)
        }
    }
}
