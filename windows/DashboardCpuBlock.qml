pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    ColumnLayout {
        id: idCpuColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Repeater {
            id: idCpuRepeater

            model: [
                { label: qsTr("CPU"), fill: 0.35 },
                { label: qsTr("RAM"), fill: 0.55 }
            ]

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

                Text {
                    id: idMeterLabel

                    Layout.preferredWidth: Globals.agendaTimeWidth
                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: modelData ? modelData.label : ""
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                Rectangle {
                    id: idMeterTrack

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Globals.eventDotSize
                    Layout.alignment: Qt.AlignVCenter

                    radius: Globals.eventDotSize / 2
                    color: Colors.cardSecondary

                    Rectangle {
                        id: idMeterFill

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: parent.width * (modelData ? modelData.fill : 0)
                        height: parent.height

                        radius: parent.radius
                        color: Colors.accent
                    }
                }

                Text {
                    id: idMeterValue

                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    text: modelData ? Math.round(modelData.fill * 100) + "%" : ""
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        weight: Font.Medium
                    }
                }
            }
        }
    }
}
