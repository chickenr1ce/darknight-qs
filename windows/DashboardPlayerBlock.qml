pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    ColumnLayout {
        id: idPlayerColumn

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Rectangle {
            id: idPlayerArt

            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96

            radius: width / 2
            color: Colors.cardSecondary
            border.width: Globals.hairlineHeight
            border.color: Colors.border
        }

        Text {
            id: idPlayerTrack

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            text: qsTr("Bad Apple!! feat. no...")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        Text {
            id: idPlayerArtist

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            text: qsTr("Alstroemeria Records")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }

        RowLayout {
            id: idPlayerTransport

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            PillButton {
                id: idPlayerPrev

                Layout.alignment: Qt.AlignVCenter

                disabled: true
                text: qsTr("Prev")
            }

            PillButton {
                id: idPlayerPlay

                Layout.alignment: Qt.AlignVCenter

                disabled: true
                highlighted: false
                text: qsTr("Play")
            }

            PillButton {
                id: idPlayerNext

                Layout.alignment: Qt.AlignVCenter

                disabled: true
                text: qsTr("Next")
            }
        }

        Rectangle {
            id: idPlayerDivider

            Layout.fillWidth: true
            Layout.preferredHeight: Globals.hairlineHeight

            color: Colors.border
        }

        Repeater {
            id: idPlayerDevicesRepeater

            model: [qsTr("Phone"), qsTr("PC")]

            delegate: Text {
                required property string modelData

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: modelData
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }
        }
    }
}
