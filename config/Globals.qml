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

    // Reading-surface typography (typography pass, 2026-08-24): notifications
    // use a proportional sans with a named scale, so the toast (ticket 02),
    // notification center (03) and bar module (04) consume values, not magic
    // numbers. Iosevka stays exclusive to the bar and its modules.
    readonly property string uiFontFamily: "Geist"
    readonly property int uiCaptionSize: 12 // metadata strip (app label)
    readonly property int uiTitleSize: 15   // summary / future panel headings
    readonly property int uiBodySize: 14    // body text
    readonly property int uiPillSize: 13    // action pills

    // Notification toast geometry (ticket 02): single source for the card
    // width so the window canvas, input mask and card stay in lockstep.
    readonly property int toastWidth: 320

    // Notification center geometry (ticket 03): frozen decision 1A panel
    // canvas; open/close motion per acceptance criteria (140ms open, 120ms
    // close). The open duration doubles as the accordion expand register
    // (frozen decision 2A).
    readonly property int centerWidth: 380
    readonly property int centerMaxHeight: 540
    readonly property int centerOpenMs: 140
    readonly property int centerCloseMs: 120

    // Phase 6a motion tokens (D-08, tuned to 140ms snappy register)
    readonly property int hoverMs: 140
    readonly property int pressMs: 120

    // Toast OSD motion register (ticket 02): entrance slide/fade plus the
    // ListView displaced reflow share one timing so both moves read alike.
    readonly property int toastMs: 180

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
