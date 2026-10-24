pragma Singleton

import QtQuick

// The tokens components/BarSlot.qml and the real ModuleBox it hosts read, for
// the offscreen handler test. Only what those files touch lives here; the test
// sets the slot's own holdMs, so the shipped hold token cannot go stale.
QtObject {
    id: root

    readonly property int barHeight: 28
    readonly property int barDragHoldMs: 300
    readonly property real barDragLiftScale: 1.05
    readonly property int spacing: 10
    readonly property int modulePadding: 12
    readonly property int pressMs: 160
    readonly property int pressReleaseMs: 100
    readonly property real pressScaleModule: 0.96
    readonly property int barReorderMs: 160
    readonly property int slabInset: 10
    readonly property int dropSlotInset: 2
    readonly property int moduleMargin: 4
    readonly property int radius: 5
    readonly property int hairlineHeight: 1
    readonly property int hoverMs: 140
    readonly property bool reducedMotion: true
    readonly property var easeOutCurve: [0.23, 1, 0.32, 1, 1, 1]
    readonly property var easeInOutCurve: [0.77, 0, 0.175, 1, 1, 1]
}
