pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

// Calendar plus world clock inside the shared panel shell; date-only, no event backend yet.
PanelShell {
    id: root

    property date now: new Date()

    readonly property string monthLabel: Qt.formatDateTime(new Date(CalendarService.viewYear, CalendarService.viewMonth, 1), "MMMM yyyy")

    panelVisible: CalendarService.calendarVisible
    onOutsideClicked: CalendarService.closeCalendarFromOutside()

    Timer {
        id: idCalendarTimer

        interval: 1000
        running: CalendarService.calendarVisible
        repeat: true
        onTriggered: {
            root.now = new Date();
            const now = new Date();
            const iso = CalendarService.isoFor(now.getFullYear(), now.getMonth(), now.getDate());
            if (iso !== CalendarService.todayIso)
                CalendarService.todayIso = iso;
        }
    }

    PanelHeader {
        id: idCalendarHeader

        title: root.monthLabel
        showBadge: false

        IconButton {
            id: idPrevButton

            Layout.alignment: Qt.AlignVCenter

            glyph: "‹"
            accessibleName: qsTr("Previous month")
            onClicked: CalendarService.shiftMonth(-1)
        }

        PillButton {
            id: idTodayButton

            Layout.alignment: Qt.AlignVCenter

            text: qsTr("Today")
            onClicked: CalendarService.showToday()
        }

        IconButton {
            id: idNextButton

            Layout.alignment: Qt.AlignVCenter

            glyph: "›"
            accessibleName: qsTr("Next month")
            onClicked: CalendarService.shiftMonth(1)
        }
    }

    RowLayout {
        id: idWeekdayRow

        Layout.fillWidth: true

        spacing: Globals.dayCellGap

        Repeater {
            model: [qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr("Fri"), qsTr("Sat"), qsTr("Sun")]

            Text {
                required property string modelData

                Layout.fillWidth: true

                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: modelData
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                }
            }
        }
    }

    GridLayout {
        id: idMonthGrid

        Layout.fillWidth: true

        columns: 7
        columnSpacing: Globals.dayCellGap
        rowSpacing: Globals.dayCellGap

        Repeater {
            model: CalendarService.monthCells

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Globals.dayCellHeight

                radius: Globals.pillRadius
                color: modelData.isSelected ? Colors.accent : (idDayMouseArea.containsMouse ? Colors.cardSecondary : "transparent")
                border.width: modelData.isToday ? 1 : 0
                border.color: Colors.accent

                Text {
                    anchors.centerIn: parent

                    textFormat: Text.PlainText
                    text: modelData.day
                    color: modelData.isSelected ? Colors.onAccent : (modelData.inMonth ? Colors.text : Colors.textSecondary)

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                        weight: modelData.isToday ? Font.DemiBold : Font.Normal
                    }
                }

                MouseArea {
                    id: idDayMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CalendarService.selectDay(modelData.iso)
                }
            }
        }
    }

    Rectangle {
        id: idSectionDivider

        Layout.fillWidth: true
        Layout.preferredHeight: 1

        color: Colors.border
    }

    Text {
        id: idWorldTitle

        Layout.fillWidth: true

        textFormat: Text.PlainText
        text: qsTr("World clock").toUpperCase()
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
            weight: Font.Medium
            letterSpacing: 0.6
        }
    }

    Column {
        id: idWorldColumn

        Layout.fillWidth: true

        spacing: 6

        Repeater {
            model: CalendarService.worldZones

            RowLayout {
                required property string modelData

                width: idWorldColumn.width

                spacing: 8

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: CalendarService.zoneLabel(modelData)
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    text: root.zoneTime(modelData)
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                        weight: Font.Medium
                    }
                }
            }
        }
    }

    function zoneTime(iana: string): string {
        try {
            return root.now.toLocaleString(Qt.locale().name, {
                hour: "2-digit",
                minute: "2-digit",
                timeZone: iana
            });
        } catch (e) {
            return "";
        }
    }
}
