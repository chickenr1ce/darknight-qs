pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Column {
    id: root

    spacing: Globals.spacing

    Text {
        id: idSettingsHint

        width: root.width

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

        width: root.width

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
