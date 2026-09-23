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

    readonly property string zoneDraft: idZoneInput.text.trim()
    readonly property var zoneMatches: {
        const query = root.zoneDraft.toLowerCase().replace(/_/g, " ");
        const owned = CalendarService.worldZones;
        const all = CalendarService.ianaZones;
        const matches = [];
        for (let i = 0; i < all.length && matches.length < CalendarService.maxZones; i++) {
            const zone = all[i];
            if (owned.includes(zone))
                continue;
            if (query === "") {
                if (CalendarService.commonZones.includes(zone))
                    matches.push(zone);
            } else if (zone.toLowerCase().replace(/_/g, " ").includes(query)) {
                matches.push(zone);
            }
        }
        return matches;
    }
    readonly property bool canAddDraft: root.zoneDraft !== "" && root.zoneMatches.length === 0 && !CalendarService.worldZones.includes(root.zoneDraft) && CalendarService.worldZones.length < CalendarService.maxZones && CalendarService.isValidZoneName(root.zoneDraft)

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
            glyph: "‹"
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
            glyph: "›"
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

        visible: !root.showingSettings
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

    Column {
        id: idCalendarSettings

        Layout.fillWidth: true

        visible: root.showingSettings
        spacing: Globals.spacing

        Text {
            id: idSettingsHint

            width: idCalendarSettings.width

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

            width: idCalendarSettings.width

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
                        if (root.editingZones && idZoneInput.visible)
                            Qt.callLater(() => idZoneInput.forceActiveFocus());
                    }
                }
            }

            Column {
                id: idWorldColumn

                width: idBodyColumn.width

                spacing: Globals.listSpacing

                Repeater {
                    model: CalendarService.worldZones

                    RowLayout {
                        required property string modelData

                        width: idWorldColumn.width

                        spacing: Globals.rowSpacing

                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: CalendarService.zoneTitle(modelData)
                            color: Colors.text

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter

                            textFormat: Text.PlainText
                            text: CalendarService.zoneTime(modelData)
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                                weight: Font.Medium
                            }
                        }

                        IconButton {
                            id: idZoneRemoveButton

                            Layout.alignment: Qt.AlignVCenter

                            visible: root.editingZones
                            accessibleName: qsTr("Remove zone")
                            onClicked: CalendarService.removeZone(modelData)
                        }
                    }
                }
            }

            RowLayout {
                id: idZoneSearchRow

                width: idBodyColumn.width

                visible: root.editingZones && CalendarService.worldZones.length < CalendarService.maxZones
                spacing: Globals.rowSpacing

                Rectangle {
                    id: idZoneField

                    Layout.fillWidth: true
                    Layout.preferredHeight: idZoneInput.implicitHeight + 2 * Globals.fieldPadding

                    radius: Globals.pillRadius
                    color: Colors.cardSecondary
                    border.width: Globals.hairlineHeight
                    border.color: idZoneInput.activeFocus ? Colors.accent : Colors.border

                    TextInput {
                        id: idZoneInput

                        anchors.fill: parent
                        anchors.margins: Globals.fieldPadding

                        clip: true
                        color: Colors.text
                        selectByMouse: true

                        Keys.onReturnPressed: root.addFirstZoneMatch()
                        Keys.onEnterPressed: root.addFirstZoneMatch()

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                        }

                        Text {
                            anchors.fill: parent

                            verticalAlignment: Text.AlignVCenter
                            visible: idZoneInput.text === "" && !idZoneInput.activeFocus

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: qsTr("Search zones…")
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }
                        }
                    }
                }

                PillButton {
                    id: idZoneBestMatch

                    Layout.alignment: Qt.AlignVCenter

                    visible: root.zoneMatches.length > 0
                    text: root.zoneMatches.length > 0 ? CalendarService.zoneLabel(root.zoneMatches[0]) : ""
                    onClicked: root.addFirstZoneMatch()
                }

                PillButton {
                    id: idZoneManualAdd

                    Layout.alignment: Qt.AlignVCenter

                    visible: root.canAddDraft
                    text: qsTr("Add %1").arg(CalendarService.zoneLabel(root.zoneDraft))
                    onClicked: root.addZoneMatch(root.zoneDraft)
                }

                Text {
                    id: idZoneNoMatch

                    Layout.alignment: Qt.AlignVCenter

                    visible: root.zoneDraft !== "" && root.zoneMatches.length === 0 && !root.canAddDraft
                    textFormat: Text.PlainText
                    text: qsTr("No match")
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                    }
                }
            }

            Text {
                id: idZoneFullNote

                width: idBodyColumn.width

                visible: root.editingZones && CalendarService.worldZones.length >= CalendarService.maxZones
                textFormat: Text.PlainText
                text: qsTr("Zone list full (%1)").arg(CalendarService.maxZones)
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }
    }

    Text {
        id: idBodyScrollHint

        Layout.fillWidth: true

        visible: !root.showingSettings && idBodyColumn.implicitHeight > root.bodyScrollMax + Globals.hairlineHeight
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: qsTr("Scroll for more ▾")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    function addZoneMatch(iana: string) {
        CalendarService.addZone(iana);
        idZoneInput.clear();
    }

    function addFirstZoneMatch() {
        if (root.zoneMatches.length > 0)
            root.addZoneMatch(root.zoneMatches[0]);
        else if (root.canAddDraft)
            root.addZoneMatch(root.zoneDraft);
    }
}
