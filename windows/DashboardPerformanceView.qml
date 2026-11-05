pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    readonly property real diskMinScale: 1048576
    readonly property real netMinScale: 102400
    readonly property bool live: root.visible && DashboardService.dashboardVisible
    property int windowSeconds: PerformanceHistory.historySeconds
    readonly property int windowSamples: PerformanceHistory.windowSamples(root.windowSeconds)
    readonly property var rings: PerformanceHistory.rings
    readonly property int scrubAge: PerformanceHistory.scrubAge(idScrub.containsMouse ? idScrub.mouseX / idScrub.width : -1, root.windowSamples)
    readonly property bool scrubbing: root.scrubAge >= 0 && PerformanceHistory.hasSampleAt(root.scrubAge)
    readonly property var reading: PerformanceHistory.readingAt(root.scrubbing ? root.scrubAge : 0)
    readonly property real diskPeak: PerformanceHistory.windowPeak(["diskRead", "diskWrite"], root.windowSamples)
    readonly property real netPeak: PerformanceHistory.windowPeak(["netRx", "netTx"], root.windowSamples)

    function tempColor(celsius: real): color {
        const level = PerformanceHistory.tempLevel(celsius);
        return level === "danger" ? Colors.danger : (level === "warning" ? Colors.warning : Colors.textSubtle);
    }

    RowLayout {
        id: idPerformanceHeader

        Layout.fillWidth: true

        spacing: Globals.fieldPadding

        SectionLabel {
            id: idPerformanceTitle

            Layout.fillWidth: true

            text: root.scrubbing
                ? PerformanceHistory.agoText(root.scrubAge * PerformanceHistory.sampleSeconds)
                : (root.windowSeconds === PerformanceHistory.historySeconds ? qsTr("Last 5 minutes") : qsTr("Last minute"))
            font.features: ({ "tnum": 1 })
        }

        PillButton {
            id: idPerformanceRangeMinute

            text: qsTr("1m")
            accessibleName: qsTr("Show the last minute")
            quiet: true
            highlighted: root.windowSeconds === 60
            onClicked: root.windowSeconds = 60
        }

        PillButton {
            id: idPerformanceRangeFive

            text: qsTr("5m")
            accessibleName: qsTr("Show the last 5 minutes")
            quiet: true
            highlighted: root.windowSeconds === PerformanceHistory.historySeconds
            onClicked: root.windowSeconds = PerformanceHistory.historySeconds
        }
    }

    Item {
        id: idPerformanceLanesHost

        Layout.fillWidth: true

        implicitHeight: idPerformanceLanes.implicitHeight

        ColumnLayout {
            id: idPerformanceLanes

            anchors {
                left: parent.left
                right: parent.right
            }

            spacing: Globals.fieldPadding

            PerformanceLane {
                id: idPerformanceLaneCpu

                Layout.fillWidth: true

                label: qsTr("CPU")
                primaryText: Math.round(root.reading.cpu) + "%"
                secondaryText: PerformanceHistory.tempText(root.reading.cpuTemp)
                secondaryColor: root.tempColor(root.reading.cpuTemp)
                extraText: qsTr("busiest %1%").arg(Math.round(root.reading.cpuPeak))
                extraMarked: true
                values: root.rings.cpu
                valuesOver: root.rings.cpuPeak
                windowSamples: root.windowSamples
                live: root.live
            }

            PerformanceLane {
                id: idPerformanceLaneGpu

                Layout.fillWidth: true

                label: qsTr("GPU")
                primaryText: Math.round(root.reading.gpu) + "%"
                secondaryText: PerformanceHistory.tempText(root.reading.gpuTemp)
                secondaryColor: root.tempColor(root.reading.gpuTemp)
                values: root.rings.gpu
                windowSamples: root.windowSamples
                live: root.live
            }

            PerformanceLane {
                id: idPerformanceLaneRam

                Layout.fillWidth: true

                label: qsTr("RAM")
                primaryText: Math.round(root.reading.ram) + "%"
                secondaryText: SystemMonitor.formatGib(root.reading.ramUsed) + "/" + SystemMonitor.formatGib(SystemMonitor.ramTotalBytes) + "G"
                values: root.rings.ram
                windowSamples: root.windowSamples
                live: root.live
            }

            PerformanceLane {
                id: idPerformanceLaneDisk

                Layout.fillWidth: true

                label: qsTr("DISK")
                primaryText: qsTr("R %1").arg(SystemMonitor.formatRate(root.reading.diskRead))
                secondaryText: qsTr("W %1").arg(SystemMonitor.formatRate(root.reading.diskWrite))
                extraText: qsTr("peak %1").arg(SystemMonitor.formatRate(root.diskPeak))
                values: root.rings.diskRead
                valuesBelow: root.rings.diskWrite
                maxValue: PerformanceHistory.autoScale(root.diskPeak, root.diskMinScale)
                windowSamples: root.windowSamples
                live: root.live
            }

            PerformanceLane {
                id: idPerformanceLaneNet

                Layout.fillWidth: true

                label: qsTr("NET")
                primaryText: "↓ " + SystemMonitor.formatRate(root.reading.netRx)
                secondaryText: "↑ " + SystemMonitor.formatRate(root.reading.netTx)
                extraText: qsTr("peak %1").arg(SystemMonitor.formatRate(root.netPeak))
                values: root.rings.netRx
                valuesBelow: root.rings.netTx
                maxValue: PerformanceHistory.autoScale(root.netPeak, root.netMinScale)
                windowSamples: root.windowSamples
                live: root.live
            }
        }

        MouseArea {
            id: idScrub

            anchors {
                fill: idPerformanceLanes
                leftMargin: Globals.performanceGutterWidth + Globals.rowSpacing
            }

            acceptedButtons: Qt.NoButton
            hoverEnabled: true
        }

        Rectangle {
            id: idScrubLine

            x: idScrub.x + idScrub.width * (1 - root.scrubAge / (root.windowSamples - 1))
            width: Globals.hairlineHeight
            height: idPerformanceLanes.height

            visible: root.scrubbing
            color: Colors.text
        }
    }

    Item {
        id: idPerformanceAxis

        Layout.fillWidth: true
        Layout.leftMargin: Globals.performanceGutterWidth + Globals.rowSpacing

        implicitHeight: idPerformanceAxisNow.implicitHeight

        Repeater {
            id: idPerformanceAxisTicks

            model: Globals.performanceGridDivisions

            delegate: Text {
                id: idPerformanceAxisTick

                required property int index

                x: idPerformanceAxis.width * idPerformanceAxisTick.index / Globals.performanceGridDivisions

                textFormat: Text.PlainText
                text: PerformanceHistory.agoText(root.windowSeconds * (Globals.performanceGridDivisions - idPerformanceAxisTick.index) / Globals.performanceGridDivisions)
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }
        }

        Text {
            id: idPerformanceAxisNow

            anchors.right: parent.right

            textFormat: Text.PlainText
            text: PerformanceHistory.agoText(0)
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }
    }
}
