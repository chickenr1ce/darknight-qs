pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool dndRelevant: SettingsFilter.matches(root.filter, qsTr("Do not disturb"))
        || SettingsFilter.matches(root.filter, qsTr("DND"))

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
