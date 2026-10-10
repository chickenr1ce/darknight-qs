pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property var hiddenApps: AppService.hiddenEntries

    readonly property bool appsRelevant: SettingsFilter.matches(root.filter, qsTr("Hidden"))
        || SettingsFilter.matches(root.filter, qsTr("Launcher"))

    readonly property bool terminalRelevant: SettingsFilter.matches(root.filter, qsTr("Terminal"))
        || SettingsFilter.matches(root.filter, qsTr("Launcher"))

    spacing: Globals.spacing

    SettingsTextRow {
        id: idTerminalRow

        Layout.fillWidth: true

        label: qsTr("Terminal")
        hint: qsTr("Command the launcher opens Terminal apps and Run queries with, for example kitty -e.")
        value: AppService.terminalCommand
        visible: root.terminalRelevant
        onEdited: text => AppService.setTerminal(text)
    }

    Text {
        id: idAppsHint

        Layout.fillWidth: true

        visible: root.appsRelevant && root.hiddenApps.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("Hidden apps stay out of the Apps tab. Unhide one to bring it back.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Repeater {
        id: idHiddenApps

        model: root.hiddenApps

        delegate: RowLayout {
            id: idHiddenAppRow

            Layout.fillWidth: true

            required property var modelData

            visible: root.appsRelevant || SettingsFilter.matches(root.filter, idHiddenAppRow.modelData.name)
            spacing: Globals.rowSpacing

            AppIcon {
                id: idHiddenAppIcon

                Layout.preferredWidth: Globals.appIconSize
                Layout.preferredHeight: Globals.appIconSize
                Layout.alignment: Qt.AlignVCenter

                source: idHiddenAppRow.modelData.source
                name: idHiddenAppRow.modelData.name
            }

            Text {
                id: idHiddenAppName

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idHiddenAppRow.modelData.name
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }

            PillButton {
                id: idUnhideButton

                Layout.alignment: Qt.AlignVCenter

                text: qsTr("Unhide")
                accessibleName: qsTr("Unhide %1").arg(idHiddenAppRow.modelData.name)
                onClicked: AppService.unhide(idHiddenAppRow.modelData.id)
            }
        }
    }

    Text {
        id: idAppsEmpty

        Layout.fillWidth: true

        visible: root.appsRelevant && root.hiddenApps.length === 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("No hidden apps. Right-click an app in the Apps tab to hide it.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }
}
