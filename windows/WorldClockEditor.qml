pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Column {
    id: root

    property bool editing: true

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

    spacing: Globals.listSpacing

    Repeater {
        model: CalendarService.worldZones

        RowLayout {
            required property string modelData

            width: root.width

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

                visible: root.editing
                accessibleName: qsTr("Remove zone")
                onClicked: CalendarService.removeZone(modelData)
            }
        }
    }

    RowLayout {
        id: idZoneSearchRow

        width: root.width

        visible: root.editing && CalendarService.worldZones.length < CalendarService.maxZones
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

        width: root.width

        visible: root.editing && CalendarService.worldZones.length >= CalendarService.maxZones
        textFormat: Text.PlainText
        text: qsTr("Zone list full (%1)").arg(CalendarService.maxZones)
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    function focusInput(): void {
        Qt.callLater(() => {
            if (idZoneInput.visible)
                idZoneInput.forceActiveFocus();
        });
    }

    function addZoneMatch(iana: string): void {
        CalendarService.addZone(iana);
        idZoneInput.clear();
    }

    function addFirstZoneMatch(): void {
        if (root.zoneMatches.length > 0)
            root.addZoneMatch(root.zoneMatches[0]);
        else if (root.canAddDraft)
            root.addZoneMatch(root.zoneDraft);
    }
}
