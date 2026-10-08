pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property bool outputsRelevant: SettingsFilter.matches(root.filter, qsTr("Audio outputs"))
    readonly property bool osdRelevant: SettingsFilter.matches(root.filter, qsTr("Volume OSD"))

    spacing: Globals.spacing

    SettingsToggleRow {
        id: idVolumeOsdRow

        Layout.fillWidth: true

        visible: root.osdRelevant
        label: qsTr("Volume OSD")
        hint: qsTr("Show the volume level on screen when it changes.")
        value: AudioService.osdEnabled
        onToggled: AudioService.setOsdEnabled(!AudioService.osdEnabled)
    }

    Text {
        id: idAudioHint

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.outputsRelevant
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("Choose the outputs the dashboard and the bar show, and set their order.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Repeater {
        id: idAudioOutputs

        model: AudioService.sinkNodes

        delegate: RowLayout {
            id: idOutputRow

            Layout.fillWidth: true

            required property var modelData
            required property int index

            readonly property string outputLabel: AudioService.rawLabelFor(idOutputRow.modelData)
            readonly property bool outputShown: !AudioService.isHidden(idOutputRow.modelData)

            visible: root.outputsRelevant || SettingsFilter.matches(root.filter, idOutputRow.outputLabel)
            spacing: Globals.rowSpacing

            Text {
                id: idOutputLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idOutputRow.outputLabel
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }

            IconButton {
                id: idOutputMoveUp

                Layout.alignment: Qt.AlignVCenter

                glyph: Icons.chevronUp
                disabled: idOutputRow.index === 0
                accessibleName: qsTr("Move %1 up").arg(idOutputRow.outputLabel)
                onClicked: AudioService.moveOutput(idOutputRow.modelData, -1)
            }

            IconButton {
                id: idOutputMoveDown

                Layout.alignment: Qt.AlignVCenter

                glyph: Icons.chevronDown
                disabled: idOutputRow.index === AudioService.sinkNodes.length - 1
                accessibleName: qsTr("Move %1 down").arg(idOutputRow.outputLabel)
                onClicked: AudioService.moveOutput(idOutputRow.modelData, 1)
            }

            PillButton {
                id: idOutputShownButton

                Layout.alignment: Qt.AlignVCenter

                highlighted: idOutputRow.outputShown
                text: idOutputRow.outputShown ? qsTr("Shown") : qsTr("Hidden")
                accessibleName: qsTr("Show %1 in dashboard").arg(idOutputRow.outputLabel)
                onClicked: AudioService.setHidden(idOutputRow.modelData, idOutputRow.outputShown)
            }
        }
    }

    Text {
        id: idAudioEmpty

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.outputsRelevant && AudioService.sinkNodes.length === 0

        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("No audio outputs detected")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
        }
    }
}
