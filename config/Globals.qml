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

    // Phase 6a motion tokens (D-08, tuned to 140ms snappy register)
    readonly property int hoverMs: 140
    readonly property int pressMs: 120

    // Phase 6a press-squash magnitudes (D-03): module regions squash harder
    // than small per-item pills so the feedback reads at both sizes.
    readonly property real pressScaleModule: 0.94
    readonly property real pressScalePill: 0.86

    // Phase 6a slab geometry: inner edge padding keeps edge modules clear of
    // the 9px corner curve (D-01/D-06); hairlines inset symmetrically top/bottom.
    // slabInset is the total panel inset between window edge and module content;
    // every consumer of (horizontalBarMargin + slabEdgePadding) binds to this.
    readonly property int slabInset: horizontalBarMargin + slabEdgePadding
    readonly property int slabEdgePadding: 6
    readonly property int hairlineVerticalInset: 8
}
