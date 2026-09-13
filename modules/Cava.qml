pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Bar visualizer bound to CavaService levels; silence flatlines in place so siblings never shift.
ModuleBox {
    id: root

    readonly property int barWidth: 4
    readonly property int barSpacing: 3
    readonly property int barRadius: 1
    readonly property int barMinHeight: 2
    readonly property int barPeakHeight: 24
    readonly property int rowHeight: 22

    // Display only for v1, so no hover or click surface.
    enableMouseArea: false
    enableHover: false

    RowLayout {
        id: idCavaRow

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: root.rowHeight

        spacing: root.barSpacing

        Repeater {
            id: idCavaRepeater

            model: CavaService.barCount

            delegate: Rectangle {
                id: idCavaBar

                Layout.alignment: Qt.AlignBottom
                Layout.preferredWidth: root.barWidth
                Layout.preferredHeight: root.barMinHeight + ((CavaService.levels[index] ?? 0) * (root.barPeakHeight - root.barMinHeight))

                required property int index

                radius: root.barRadius
                color: Colors.lavender
            }
        }
    }
}
