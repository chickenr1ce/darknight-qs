pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool filtering: root.filter !== ""
    readonly property bool motionRelevant: !root.filtering
        || qsTr("Reduced motion").toLowerCase().includes(root.filter.toLowerCase())
        || qsTr("Animation").toLowerCase().includes(root.filter.toLowerCase())

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
