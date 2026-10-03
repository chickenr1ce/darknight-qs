pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    spacing: Globals.spacing

    function matchesLocation(): bool {
        return SettingsFilter.matches(root.filter, qsTr("City"))
            || SettingsFilter.matches(root.filter, qsTr("Location"));
    }

    RowLayout {
        id: idLocationCityRow

        Layout.fillWidth: true

        visible: SettingsFilter.matches(root.filter, qsTr("City"))
        spacing: Globals.rowSpacing

        Text {
            id: idLocationCityLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("City")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Text {
            id: idLocationCityValue

            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: WeatherService.locationName
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }
    }

    RowLayout {
        id: idLocationSearchRow

        Layout.fillWidth: true

        visible: root.matchesLocation()
        spacing: Globals.rowSpacing

        Rectangle {
            id: idLocationField

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: idLocationInput.implicitHeight + 2 * Globals.fieldPadding
            Layout.alignment: Qt.AlignVCenter

            radius: Globals.pillRadius
            color: Colors.cardSecondary
            border.width: Globals.hairlineHeight
            border.color: idLocationInput.activeFocus ? Colors.accent : Colors.border

            TextInput {
                id: idLocationInput

                anchors.fill: parent
                anchors.margins: Globals.fieldPadding

                clip: true
                color: Colors.text
                selectByMouse: true

                Keys.onReturnPressed: root.runSearch()
                Keys.onEnterPressed: root.runSearch()

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }

                Text {
                    anchors.fill: parent

                    verticalAlignment: Text.AlignVCenter
                    visible: idLocationInput.text === "" && !idLocationInput.activeFocus

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: qsTr("Search city…")
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }
            }
        }

        PillButton {
            id: idLocationSearchButton

            Layout.alignment: Qt.AlignVCenter

            text: qsTr("Search")
            accessibleName: qsTr("Search city")
            onClicked: root.runSearch()
        }
    }

    Text {
        id: idLocationBusy

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.matchesLocation() && WeatherService.searchBusy
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: qsTr("Searching…")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Repeater {
        id: idLocationResults

        model: WeatherService.locationResults

        delegate: RowLayout {
            id: idLocationEntryRow

            Layout.fillWidth: true

            required property var modelData
            required property int index

            visible: root.matchesLocation()
            spacing: Globals.rowSpacing

            Text {
                id: idLocationEntryLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idLocationEntryRow.modelData.label
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }

            PillButton {
                id: idLocationSelectButton

                Layout.alignment: Qt.AlignVCenter

                text: qsTr("Select")
                accessibleName: qsTr("Use this city")
                onClicked: root.selectEntry(idLocationEntryRow.index)
            }
        }
    }

    Text {
        id: idLocationNoMatch

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.matchesLocation() && WeatherService.locationSearched && !WeatherService.searchBusy && WeatherService.locationResults.length === 0
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: qsTr("No match")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    function runSearch(): void {
        WeatherService.searchLocations(idLocationInput.text);
    }

    function selectEntry(index: int): void {
        WeatherService.selectLocation(index);
        idLocationInput.clear();
    }
}
