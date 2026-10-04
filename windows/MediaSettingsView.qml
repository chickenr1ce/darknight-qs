pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool appsRelevant: SettingsFilter.matches(root.filter, qsTr("Player"))
        || SettingsFilter.matches(root.filter, qsTr("Apps"))

    spacing: Globals.spacing

    Text {
        id: idMediaHint

        Layout.fillWidth: true

        visible: root.appsRelevant
        textFormat: Text.PlainText
        text: qsTr("Untick an app to keep it out of the dashboard player and the bar.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Repeater {
        id: idMediaApps

        model: MprisPlayers.seenPlayers

        delegate: SettingsToggleRow {
            id: idMediaAppRow

            Layout.fillWidth: true

            required property var modelData

            visible: root.appsRelevant || SettingsFilter.matches(root.filter, modelData.label)
            label: modelData.label !== "" ? modelData.label : modelData.key
            value: modelData.allowed
            onToggled: MprisPlayers.setAllowed(modelData.key, modelData.label, !modelData.allowed)
        }
    }

    Text {
        id: idMediaEmpty

        Layout.fillWidth: true

        visible: root.appsRelevant && MprisPlayers.seenPlayers.length === 0
        textFormat: Text.PlainText
        text: qsTr("No players seen yet. Start a media app and it shows up here.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }
}
