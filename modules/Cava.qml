pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.components
import qs.services

ModuleBox {
    id: root

    property string monitorName: ""
    property ShellScreen triggerScreen: null

    readonly property int barWidth: 4
    readonly property int barSpacing: 3
    readonly property int barRadius: 1
    readonly property int barMinHeight: 2
    readonly property int barBaselineLift: 2
    readonly property int centerOpticalNudge: 1
    readonly property int rowHeight: CavaService.maxMaxHeight + 2 * root.barBaselineLift
    readonly property int contentWidth: CavaService.barCount * (root.barWidth + root.barSpacing) - root.barSpacing
    readonly property string wavePath: root.buildWavePath()
    readonly property string ribbonPath: root.buildRibbonPath()

    property Component barsComponent: Component {
        RowLayout {
            id: idCavaBarsRow

            anchors.fill: parent
            spacing: root.barSpacing

            Repeater {
                id: idCavaBarsRepeater

                model: CavaService.barCount

                delegate: Rectangle {
                    id: idCavaBarsBar

                    Layout.alignment: Qt.AlignBottom
                    Layout.preferredWidth: root.barWidth
                    Layout.preferredHeight: root.barMinHeight + ((CavaService.levels[index] ?? 0) * (CavaService.maxHeight - root.barMinHeight))
                    Layout.bottomMargin: root.barBaselineLift

                    required property int index

                    radius: root.barRadius
                    color: Colors.lavender
                }
            }
        }
    }

    property Component mirroredComponent: Component {
        RowLayout {
            id: idCavaMirroredRow

            anchors.fill: parent
            anchors.topMargin: root.centerOpticalNudge
            spacing: root.barSpacing

            Repeater {
                id: idCavaMirroredRepeater

                model: CavaService.barCount

                delegate: Rectangle {
                    id: idCavaMirroredBar

                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.barWidth
                    Layout.preferredHeight: root.barMinHeight + ((CavaService.levels[index] ?? 0) * (CavaService.maxHeight - root.barMinHeight))

                    required property int index

                    radius: root.barRadius
                    color: Colors.lavender
                }
            }
        }
    }

    property Component waveComponent: Component {
        Shape {
            id: idCavaWaveShape

            anchors.fill: parent

            ShapePath {
                fillColor: Colors.lavender
                strokeColor: Colors.lavender
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: root.wavePath
                }
            }
        }
    }

    property Component ribbonComponent: Component {
        Shape {
            id: idCavaRibbonShape

            anchors.fill: parent

            ShapePath {
                fillColor: Colors.lavender
                strokeColor: Colors.lavender
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: root.ribbonPath
                }
            }
        }
    }

    property Component waveBlocksComponent: Component {
        RowLayout {
            id: idCavaWaveBlocksRow

            anchors.fill: parent
            spacing: 0

            Repeater {
                id: idCavaWaveBlocksRepeater

                model: CavaService.barCount

                delegate: Rectangle {
                    id: idCavaWaveBlocksBar

                    Layout.alignment: Qt.AlignBottom
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.barMinHeight + ((CavaService.levels[index] ?? 0) * (CavaService.maxHeight - root.barMinHeight))
                    Layout.bottomMargin: root.barBaselineLift

                    required property int index

                    radius: 0
                    color: Colors.lavender
                }
            }
        }
    }

    property Component ribbonBlocksComponent: Component {
        RowLayout {
            id: idCavaRibbonBlocksRow

            anchors.fill: parent
            anchors.topMargin: root.centerOpticalNudge
            spacing: 0

            Repeater {
                id: idCavaRibbonBlocksRepeater

                model: CavaService.barCount

                delegate: Rectangle {
                    id: idCavaRibbonBlocksBar

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: root.barMinHeight + ((CavaService.levels[index] ?? 0) * (CavaService.maxHeight - root.barMinHeight))

                    required property int index

                    radius: 0
                    color: Colors.lavender
                }
            }
        }
    }

    onWheelMoved: wheel => {
        if (wheel.angleDelta.y > 0)
            CavaService.cycleStyle(1);
        else if (wheel.angleDelta.y < 0)
            CavaService.cycleStyle(-1);
        else if (wheel.angleDelta.x > 0)
            CavaService.cycleStyle(1);
        else if (wheel.angleDelta.x < 0)
            CavaService.cycleStyle(-1);
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            const centerX = Globals.triggerCenterX(root, root.triggerScreen);
            CalendarService.calendarVisible = false;
            NotificationServer.centerVisible = false;
            CavaService.toggleCavaAt(root.triggerScreen, centerX);
        }
    }

    Loader {
        id: idCavaStyleLoader

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: root.contentWidth
        Layout.preferredHeight: root.rowHeight

        active: true
        sourceComponent: CavaService.styleMode === 0 ? root.barsComponent : CavaService.styleMode === 1 ? root.mirroredComponent : CavaService.styleMode === 2 ? root.waveComponent : CavaService.styleMode === 3 ? root.waveBlocksComponent : CavaService.styleMode === 4 ? root.ribbonComponent : root.ribbonBlocksComponent
    }

    function barLevel(i: int): real {
        const v = CavaService.levels[i];
        if (!(typeof v === "number"))
            return 0;
        return Math.max(0, Math.min(1, v));
    }

    function barDrawHeight(i: int): real {
        return root.barMinHeight + (root.barLevel(i) * (CavaService.maxHeight - root.barMinHeight));
    }

    function curveSegments(pts: var): string {
        let d = "";
        const n = pts.length;
        for (let i = 0; i < n - 1; i++) {
            const p0 = pts[Math.max(0, i - 1)];
            const p1 = pts[i];
            const p2 = pts[i + 1];
            const p3 = pts[Math.min(n - 1, i + 2)];
            const c1x = p1[0] + (p2[0] - p0[0]) / 6;
            const c1y = p1[1] + (p2[1] - p0[1]) / 6;
            const c2x = p2[0] - (p3[0] - p1[0]) / 6;
            const c2y = p2[1] - (p3[1] - p1[1]) / 6;
            d += " C " + c1x.toFixed(2) + " " + c1y.toFixed(2) + " " + c2x.toFixed(2) + " " + c2y.toFixed(2) + " " + p2[0].toFixed(2) + " " + p2[1].toFixed(2);
        }
        return d;
    }

    function buildWavePath(): string {
        const n = CavaService.barCount;
        const w = root.contentWidth;
        const base = root.rowHeight - root.barBaselineLift;
        if (n <= 0)
            return "";
        const step = n > 1 ? w / (n - 1) : 0;
        const tops = [];
        for (let i = 0; i < n; i++)
            tops.push([i * step, base - root.barDrawHeight(i)]);
        return "M 0 " + base + " L " + tops[0][0].toFixed(2) + " " + tops[0][1].toFixed(2) + root.curveSegments(tops) + " L " + w + " " + base + " Z";
    }

    function buildRibbonPath(): string {
        const n = CavaService.barCount;
        const w = root.contentWidth;
        const mid = root.rowHeight / 2;
        if (n <= 0)
            return "";
        const step = n > 1 ? w / (n - 1) : 0;
        const tops = [];
        const bots = [];
        for (let i = 0; i < n; i++) {
            const half = root.barDrawHeight(i) / 2;
            tops.push([i * step, mid - half]);
            bots.push([i * step, mid + half]);
        }
        bots.reverse();
        return "M " + tops[0][0].toFixed(2) + " " + tops[0][1].toFixed(2) + root.curveSegments(tops) + " L " + bots[0][0].toFixed(2) + " " + bots[0][1].toFixed(2) + root.curveSegments(bots) + " Z";
    }
}
