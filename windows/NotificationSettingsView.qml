pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool filtering: root.filter !== ""
    readonly property bool dndRelevant: !root.filtering
        || qsTr("Do not disturb").toLowerCase().includes(root.filter.toLowerCase())
        || qsTr("DND").toLowerCase().includes(root.filter.toLowerCase())

    spacing: Globals.spacing

    SettingsToggleRow {
        id: idDndRow

        Layout.fillWidth: true

        visible: root.dndRelevant
        label: qsTr("Do not disturb")
        hint: qsTr("Mirrors the notification center; toasts stay quiet while on.")
        value: NotificationServer.dndEnabled
        onToggled: NotificationServer.toggleDnd()
    }
}
