pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    ColumnLayout {
        id: idUsageColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Repeater {
            id: idUsageRepeater

            model: [qsTr("CPU"), qsTr("GPU"), qsTr("RAM")]

            delegate: RowLayout {
                id: idUsageRow

                Layout.fillWidth: true

                required property string modelData
                required property int index

                readonly property real percent: index === 0 ? SystemMonitor.cpuUsagePercent : (index === 1 ? SystemMonitor.gpuUsagePercent : SystemMonitor.ramUsagePercent)
                readonly property real tempC: index === 0 ? SystemMonitor.cpuTempC : (index === 1 ? SystemMonitor.gpuTempC : 0)
                readonly property string detail: index === 2 ? SystemMonitor.ramUsedText : (idUsageRow.tempC > 0 ? Math.round(idUsageRow.tempC) + "°C" : "")

                spacing: Globals.rowSpacing

                Text {
                    id: idUsageLabel

                    Layout.preferredWidth: Globals.agendaTimeWidth
                    Layout.alignment: Qt.AlignVCenter

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: idUsageRow.modelData
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                Rectangle {
                    id: idUsageTrack

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Globals.eventDotSize
                    Layout.alignment: Qt.AlignVCenter

                    radius: Globals.eventDotSize / 2
                    color: Colors.cardSecondary

                    Rectangle {
                        id: idUsageFill

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        width: parent.width * idUsageRow.percent / 100
                        height: parent.height

                        radius: parent.radius
                        color: Colors.accent
                    }
                }

                Text {
                    id: idUsageDetail

                    Layout.preferredWidth: Globals.usageDetailWidth
                    Layout.alignment: Qt.AlignVCenter

                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: idUsageRow.detail
                    color: idUsageRow.tempC >= 85 ? Colors.danger : (idUsageRow.tempC >= 75 ? Colors.warning : Colors.textSubtle)

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        features: ({ "tnum": 1 })
                    }
                }

                Text {
                    id: idUsageValue

                    Layout.preferredWidth: Globals.volumeValueWidth
                    Layout.alignment: Qt.AlignVCenter

                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.PlainText
                    text: Math.round(idUsageRow.percent) + "%"
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                        weight: Font.Medium
                        features: ({ "tnum": 1 })
                    }
                }
            }
        }

        Rectangle {
            id: idUsageDivider

            Layout.fillWidth: true
            Layout.preferredHeight: Globals.hairlineHeight

            color: Colors.border
        }

        RowLayout {
            id: idUsageNetRow

            Layout.fillWidth: true

            spacing: Globals.rowSpacing

            Rectangle {
                id: idUsageNetDot

                Layout.preferredWidth: Globals.eventDotSize
                Layout.preferredHeight: Globals.eventDotSize
                Layout.alignment: Qt.AlignVCenter

                radius: Globals.eventDotSize / 2
                color: Colors.accent
            }

            Text {
                id: idUsageNetLabel

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: qsTr("NET")
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }
            }

            Item {
                id: idUsageNetSpacer

                Layout.fillWidth: true
            }

            Text {
                id: idUsageNetRx

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: "↓ " + SystemMonitor.netRxText
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    features: ({ "tnum": 1 })
                }
            }

            Text {
                id: idUsageNetTx

                Layout.alignment: Qt.AlignVCenter

                textFormat: Text.PlainText
                text: "↑ " + SystemMonitor.netTxText
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    features: ({ "tnum": 1 })
                }
            }
        }
    }
}
