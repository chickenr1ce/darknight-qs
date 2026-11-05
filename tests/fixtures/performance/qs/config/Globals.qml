pragma Singleton

import QtQuick

// The tokens the Performance tab and its components read. The layout-relevant
// ones are pinned to the shipped values so the test's pointer maths holds.
QtObject {
    id: root

    readonly property int performanceLaneHeight: 54
    readonly property int performanceGutterWidth: 128
    readonly property int performanceGridDivisions: 5
    readonly property real performanceLineWidth: 1.5
    readonly property real performanceOverLineWidth: 1
    readonly property int rowSpacing: 8
    readonly property int fieldPadding: 5
    readonly property int hairlineHeight: 1
    readonly property int panelPadding: 12
    readonly property int cardHPadding: 12
    readonly property int cardPadding: 12
    readonly property int cardRadius: 8
    readonly property int listSpacing: 6
    readonly property int pillHPadding: 10
    readonly property int pillVPadding: 4
    readonly property int pillRadius: 8
    readonly property int quietButtonHPadding: 6
    readonly property int quietButtonVPadding: 2
    readonly property int pressMs: 160
    readonly property int pressReleaseMs: 100
    readonly property real pressScalePill: 0.96
    readonly property int uiBodySize: 14
    readonly property int uiCaptionSize: 12
    readonly property int uiPillSize: 13
    readonly property real uiLetterSpacing: 0.6
    readonly property string uiFontFamily: "sans"
    readonly property string iconFontFamily: "sans"
    readonly property bool reducedMotion: true
    readonly property var easeOutCurve: [0.2, 0, 0, 1, 1, 1]
}
