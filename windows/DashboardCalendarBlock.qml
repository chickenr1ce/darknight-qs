pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config

Card {
    id: root

    readonly property var dayCells: ["26", "27", "28", "29", "30", "31", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "1", "2", "3", "4", "5", "6"]

    RowLayout {
        id: idCalendarRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        ColumnLayout {
            id: idCalendarDateColumn

            Layout.alignment: Qt.AlignVCenter

            spacing: 0

            Text {
                id: idCalendarDay

                Layout.alignment: Qt.AlignHCenter

                textFormat: Text.PlainText
                text: qsTr("21")
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiTitleSize
                    weight: Font.DemiBold
                }
            }

            Text {
                id: idCalendarMonth

                Layout.alignment: Qt.AlignHCenter

                textFormat: Text.PlainText
                text: qsTr("06")
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiTitleSize
                    weight: Font.DemiBold
                }
            }

            Text {
                id: idCalendarWeekday

                Layout.alignment: Qt.AlignHCenter

                textFormat: Text.PlainText
                text: qsTr("Sat, 7")
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }

        ColumnLayout {
            id: idCalendarGridColumn

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            spacing: Globals.dayCellGap

            RowLayout {
                id: idCalendarWeekRow

                Layout.fillWidth: true

                spacing: Globals.dayCellGap

                Repeater {
                    id: idCalendarWeekRepeater

                    model: [qsTr("Mon"), qsTr("Tue"), qsTr("Wed"), qsTr("Thu"), qsTr("Fri"), qsTr("Sat"), qsTr("Sun")]

                    delegate: Text {
                        required property string modelData

                        Layout.fillWidth: true

                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
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
                id: idCalendarGrid

                Layout.fillWidth: true

                columns: 7
                columnSpacing: Globals.dayCellGap
                rowSpacing: Globals.dayCellGap

                Repeater {
                    id: idCalendarDayRepeater

                    model: root.dayCells

                    delegate: Rectangle {
                        id: idDayCell

                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: Globals.dayCellHeight

                        radius: Globals.pillRadius
                        color: idDayCell.modelData === "7" && idDayCell.index === 13 ? Colors.accent : "transparent"

                        Text {
                            anchors.centerIn: parent

                            textFormat: Text.PlainText
                            text: idDayCell.modelData
                            color: idDayCell.modelData === "7" && idDayCell.index === 13 ? Colors.onAccent : Colors.text

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }
                    }
                }
            }
        }
    }
}
