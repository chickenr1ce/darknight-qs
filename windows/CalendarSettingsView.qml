pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""
    property bool showZones: true

    readonly property bool zonesRelevant: SettingsFilter.matches(root.filter, qsTr("World clock"))
        || SettingsFilter.matches(root.filter, qsTr("Zones"))
    readonly property bool feedsRelevant: SettingsFilter.matches(root.filter, qsTr("Feeds"))

    spacing: Globals.spacing

    WorldClockEditor {
        id: idZoneEditor

        Layout.fillWidth: true

        visible: root.showZones && root.zonesRelevant
    }

    Rectangle {
        id: idSectionDivider

        Layout.fillWidth: true
        Layout.preferredHeight: Globals.hairlineHeight

        visible: root.showZones && root.zonesRelevant && root.feedsRelevant
        color: Colors.border
    }

    Text {
        id: idSettingsHint

        Layout.fillWidth: true

        visible: root.feedsRelevant
        textFormat: Text.PlainText
        text: qsTr("Unticking a calendar repolls without it.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Column {
        id: idSettingsList

        Layout.fillWidth: true

        visible: root.feedsRelevant
        spacing: Globals.listSpacing

        Repeater {
            model: CalendarService.eventCalendars

            RowLayout {
                required property string modelData

                width: idSettingsList.width

                spacing: Globals.rowSpacing

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: modelData
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                PillButton {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: idToggleMetrics.width + 2 * Globals.pillHPadding

                    highlighted: !CalendarService.hiddenCalendars.includes(modelData)
                    text: !CalendarService.hiddenCalendars.includes(modelData) ? qsTr("Shown") : qsTr("Hidden")
                    onClicked: CalendarService.setCalendarHidden(modelData, !CalendarService.hiddenCalendars.includes(modelData))
                }
            }
        }
    }

    TextMetrics {
        id: idToggleMetrics

        text: qsTr("Hidden")

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiPillSize
            weight: Font.Medium
        }
    }
}
