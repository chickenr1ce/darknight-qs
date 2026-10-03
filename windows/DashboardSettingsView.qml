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

    SettingsSliderRow {
        id: idJunctionRadiusRow

        Layout.fillWidth: true

        visible: SettingsFilter.matches(root.filter, qsTr("Seam radius"))
        label: qsTr("Seam radius")
        hint: qsTr("Softens the inside corners where the dashboard meets the bar; 0 leaves them sharp.")
        from: 0
        to: Globals.junctionRadiusMax
        stepSize: 1
        value: DashboardService.junctionRadius
        onMoved: newValue => DashboardService.setJunctionRadius(newValue)
    }
}
