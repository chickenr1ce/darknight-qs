pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property int barHeight: 28
    readonly property int spacing: 10
    readonly property int modulePadding: 12
    readonly property int moduleMargin: 4
    readonly property int horizontalBarMargin: 10
    readonly property int radius: 5
    readonly property int slabRadius: 9
    readonly property int fontPixelSize: 16
    readonly property string fontFamily: "Iosevka"

    readonly property string uiFontFamily: "Geist"
    readonly property int uiCaptionSize: 12
    readonly property int uiTitleSize: 15
    readonly property int uiBodySize: 14
    readonly property int uiPillSize: 13

    readonly property int toastWidth: 320

    readonly property int centerWidth: 380
    readonly property int centerMaxHeight: 540
    readonly property int centerOpenMs: 140
    readonly property int centerCloseMs: 140

    readonly property int panelTopGap: 8
    readonly property int panelEdgeMargin: horizontalBarMargin

    readonly property int hoverMs: 140
    readonly property int pressMs: 120

    readonly property int toastMs: 180

    readonly property real pressScaleModule: 0.94
    readonly property real pressScalePill: 0.86

    readonly property int slabInset: horizontalBarMargin + slabEdgePadding
    readonly property int slabEdgePadding: 6
    readonly property int hairlineVerticalInset: 8

    readonly property int panelPadding: 12
    readonly property int cardPadding: 10
    readonly property int cardHPadding: 12
    readonly property int cardRadius: 6
    readonly property int pillRadius: 4
    readonly property int pillHPadding: 8
    readonly property int panelRadius: slabRadius
    readonly property int headerHeight: 34
    readonly property int dayCellGap: 4
    readonly property int dayCellHeight: 32

    readonly property int eventDotSize: 4
    readonly property int agendaTimeWidth: 44
    readonly property int listSpacing: 6
    readonly property int rowSpacing: 8
    readonly property int fieldPadding: 5
    readonly property int hairlineHeight: 1
    readonly property int bodyScrollMin: 160
    readonly property real uiLetterSpacing: 0.6

    readonly property string primaryMonitor: "DP-1"

    function triggerCenterX(triggerItem, triggerScreen): real {
        return triggerItem.mapToGlobal(triggerItem.width / 2, 0).x - (triggerScreen ? triggerScreen.x : 0);
    }

    function onPrimaryMonitor(monitorName: string): bool {
        return monitorName === "" || monitorName === root.primaryMonitor;
    }
}
