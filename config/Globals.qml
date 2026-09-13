pragma Singleton
import QtQuick

// Shared geometry/layout constants (mirrors waybar config.jsonc + style.css)
QtObject {
    id: root

    readonly property int barHeight: 28
    readonly property int spacing: 10
    readonly property int modulePadding: 12
    readonly property int moduleMargin: 4
    readonly property int horizontalBarMargin: 12
    readonly property int radius: 5
    readonly property int slabRadius: 9
    readonly property int fontPixelSize: 16
    readonly property string fontFamily: "Iosevka"

// Proportional sans for reading surfaces (named scale); Iosevka stays bar-exclusive.
    readonly property string uiFontFamily: "Geist"
    readonly property int uiCaptionSize: 12 // metadata strip (app label)
    readonly property int uiTitleSize: 15   // summary / future panel headings
    readonly property int uiBodySize: 14    // body text
    readonly property int uiPillSize: 13    // action pills

    // Single source so canvas, mask and card stay in lockstep.
    readonly property int toastWidth: 320

    // Panel canvas + open/close motion; the open duration doubles as accordion register.
    readonly property int centerWidth: 380
    readonly property int centerMaxHeight: 540
    readonly property int centerOpenMs: 140
    readonly property int centerCloseMs: 120

    readonly property int hoverMs: 140
    readonly property int pressMs: 120

    // Entrance and reflow share one timing so both moves read alike.
    readonly property int toastMs: 180

    // Module regions squash harder than pills so feedback reads at both sizes.
    readonly property real pressScaleModule: 0.94
    readonly property real pressScalePill: 0.86

    // Inner edge padding clears the 9px corner curve; consumers of (horizontalBarMargin + slabEdgePadding) bind slabInset.
    readonly property int slabInset: horizontalBarMargin + slabEdgePadding
    readonly property int slabEdgePadding: 6
    readonly property int hairlineVerticalInset: 8
}
