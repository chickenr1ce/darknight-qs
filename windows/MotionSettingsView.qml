pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool motionRelevant: SettingsFilter.matches(root.filter, qsTr("Reduced motion"))
        || SettingsFilter.matches(root.filter, qsTr("Animation"))

    spacing: Globals.spacing

    SettingsToggleRow {
        id: idMotionRow

        Layout.fillWidth: true

        visible: root.motionRelevant
        label: qsTr("Reduced motion")
        hint: qsTr("Dashboard and panel motion become instant.")
        value: Globals.reducedMotion
        onToggled: Globals.reducedMotion = !Globals.reducedMotion
    }
}
