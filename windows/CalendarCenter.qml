pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    readonly property string monthLabel: Qt.formatDateTime(new Date(CalendarService.viewYear, CalendarService.viewMonth, 1), "MMMM yyyy")

    readonly property var agendaRows: CalendarService.selectedDayEvents
    readonly property bool agendaHasTimes: root.agendaRows.some(row => row.t && row.t.length > 0)

    readonly property int bodyScrollMax: Math.max(Globals.bodyScrollMin, Globals.centerMaxHeight - 2 * Globals.panelPadding - idCalendarHeader.implicitHeight - idWeekdayRow.implicitHeight - idMonthGrid.implicitHeight - 3 * Globals.spacing)

    property bool editingZones: false
    property bool showingSettings: false

    anchorScreen: CalendarService.anchorScreen
    anchorCenterX: CalendarService.anchorCenterX
    panelVisible: CalendarService.calendarVisible
    onOutsideClicked: CalendarService.closeCalendarFromOutside()

    PanelHeader {
        id: idCalendarHeader

        title: root.showingSettings ? qsTr("Calendars") : root.monthLabel
        showBadge: false

        IconButton {
            id: idPrevButton

            Layout.alignment: Qt.AlignVCenter

            visible: !root.showingSettings
            glyph: Icons.chevronLeft
            accessibleName: qsTr("Previous month")
            onClicked: CalendarService.shiftMonth(-1)
        }

        PillButton {
            id: idTodayButton

            Layout.alignment: Qt.AlignVCenter

            visible: !root.showingSettings
            text: qsTr("Today")
            onClicked: CalendarService.showToday()
        }

        IconButton {
            id: idNextButton

            Layout.alignment: Qt.AlignVCenter

            visible: !root.showingSettings
            glyph: Icons.chevronRight
            accessibleName: qsTr("Next month")
            onClicked: CalendarService.shiftMonth(1)
        }

        PillButton {
            id: idSettingsButton

            Layout.alignment: Qt.AlignVCenter

            visible: CalendarService.eventCalendars.length > 0 || root.showingSettings
            text: root.showingSettings ? qsTr("Done") : qsTr("Calendars")
            onClicked: root.showingSettings = !root.showingSettings
        }
    }

    RowLayout {
        id: idWeekdayRow

        Layout.fillWidth: true

        visible: !root.showingSettings
        spacing: Globals.dayCellGap

        Repeater {
            model: [qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr("Fri"), qsTr("Sat"), qsTr("Sun")]

            Text {
                Layout.fillWidth: true

                required property string modelData

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

        visible: !root.showingSettings
        columns: 7
        columnSpacing: Globals.dayCellGap
        rowSpacing: Globals.dayCellGap

        Repeater {
            model: CalendarService.monthCells

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Globals.dayCellHeight

                required property var modelData

                radius: Globals.pillRadius
                color: modelData.isSelected ? Colors.accent : (idDayMouseArea.containsMouse ? Colors.cardSecondary : "transparent")
                border.width: modelData.isToday ? Globals.hairlineHeight : 0
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

                Rectangle {
                    id: idEventDot

                    width: Globals.eventDotSize
                    height: Globals.eventDotSize
                    radius: Globals.eventDotSize / 2
                    visible: modelData.hasEvents
                    color: modelData.isSelected ? Colors.onAccent : Colors.warning

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: Globals.dayCellGap
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

    CalendarSettingsView {
        id: idCalendarSettings

        Layout.fillWidth: true

        showZones: false
        visible: root.showingSettings
    }

    Flickable {
        id: idBodyFlickable

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(idBodyColumn.implicitHeight, root.bodyScrollMax)
        Layout.maximumHeight: root.bodyScrollMax

        visible: !root.showingSettings

        contentWidth: width
        contentHeight: idBodyColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: idBodyColumn

            width: idBodyFlickable.width

            spacing: Globals.spacing

            Text {
                id: idAgendaTitle

                width: idBodyColumn.width

                textFormat: Text.PlainText
                text: CalendarService.dateLabel(CalendarService.selectedIso).toUpperCase()
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    letterSpacing: Globals.uiLetterSpacing
                }
            }

            Text {
                id: idStaleMarker

                width: idBodyColumn.width

                visible: CalendarService.eventsStale
                textFormat: Text.PlainText
                text: CalendarService.staleLabel().toUpperCase()
                color: Colors.warning

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    letterSpacing: Globals.uiLetterSpacing
                }
            }

            Column {
                id: idAgendaColumn

                width: idBodyColumn.width

                spacing: Globals.listSpacing

                Repeater {
                    model: root.agendaRows

                    RowLayout {
                        required property var modelData

                        width: idAgendaColumn.width

                        spacing: Globals.rowSpacing

                        Text {
                            Layout.preferredWidth: Globals.agendaTimeWidth

                            visible: root.agendaHasTimes
                            textFormat: Text.PlainText
                            text: modelData.t
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: modelData.s
                            color: Colors.text

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }
                        }
                    }
                }

                Text {
                    id: idAgendaEmpty

                    width: idAgendaColumn.width

                    visible: CalendarService.selectedDayEvents.length === 0
                    textFormat: Text.PlainText
                    text: qsTr("No events")
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }
            }

            Rectangle {
                id: idSectionDivider

                width: idBodyColumn.width
                height: Globals.hairlineHeight

                color: Colors.border
            }

            RowLayout {
                id: idWorldHeader

                width: idBodyColumn.width

                spacing: Globals.rowSpacing

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: qsTr("World clock").toUpperCase()
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        weight: Font.Medium
                        letterSpacing: Globals.uiLetterSpacing
                    }
                }

                PillButton {
                    id: idZoneEditButton

                    Layout.alignment: Qt.AlignVCenter

                    text: root.editingZones ? qsTr("Done") : qsTr("Edit")
                    onClicked: {
                        root.editingZones = !root.editingZones;
                        if (root.editingZones)
                            idZoneEditor.focusInput();
                    }
                }
            }

            WorldClockEditor {
                id: idZoneEditor

                width: idBodyColumn.width
                editing: root.editingZones
            }
        }
    }

    RowLayout {
        id: idBodyScrollHint

        Layout.alignment: Qt.AlignHCenter

        visible: !root.showingSettings && idBodyColumn.implicitHeight > root.bodyScrollMax + Globals.hairlineHeight
        spacing: 4

        Text {
            id: idBodyScrollHintLabel

            textFormat: Text.PlainText
            text: qsTr("Scroll for more")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter

            text: Icons.chevronDown
            size: Globals.uiCaptionSize
            color: Colors.textSubtle
        }
    }
}
