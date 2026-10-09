pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property int barHeight: 28
    readonly property int spacing: 10
    readonly property int modulePadding: 12
    readonly property int moduleMargin: 4
    property int barTopMargin: 4
    property int barSideMargin: 10
    readonly property int barTopMarginMax: 24
    readonly property int barSideMarginMax: 48
    readonly property int radius: 5
    readonly property int slabRadius: 9
    readonly property int fontPixelSize: 16
    // Font roles are chosen in Settings (Fonts) and persisted by FontService.
    // The icon picker is restricted to Nerd Fonts, so every glyph still comes
    // from qs.config Icons rather than fontconfig fallback.
    property string fontFamily: "Iosevka"
    property string uiFontFamily: "Geist"
    property string iconFontFamily: "GeistMono Nerd Font"
    readonly property int uiCaptionSize: 12
    readonly property int uiTitleSize: 15
    readonly property int uiDisplaySize: 28
    readonly property int uiBodySize: 14
    readonly property int uiPillSize: 13
    readonly property int uiIconSize: 20
    readonly property int iconButtonPadding: 2

    readonly property int toastWidth: 320

    readonly property int centerWidth: 380
    readonly property int centerMaxHeight: 540

    readonly property int polkitWidth: 520
    readonly property int polkitMetaHeight: 26
    readonly property int polkitInputHeight: 36
    readonly property int polkitFooterHeight: 24
    readonly property real polkitScrimOpacity: 0.55
    readonly property int centerOpenMs: 140
    readonly property int centerCloseMs: 140
    readonly property int dashboardWidth: 720
    readonly property int dashboardMaxHeight: 600
    readonly property real dashboardAppsMaxFraction: 0.8
    readonly property int dashboardUsageWidth: 320
    readonly property int appIconSize: 28
    readonly property int appsFooterGap: 8
    readonly property int menuWidth: 236
    readonly property int menuMaxWidth: 340
    readonly property int menuItemHeight: 30
    readonly property int menuHeaderHeight: 40
    readonly property int menuGlyphWidth: 16
    readonly property int menuMargin: 4
    readonly property int menuSeparatorHeight: 5
    readonly property int menuLabelHeight: 20
    readonly property int menuSubmenuGap: 2
    readonly property int playerArtSize: 86
    readonly property int playerDeviceLabelWidth: 120
    readonly property int backgroundTileHeight: 48

    readonly property int settingsSidebarWidth: 148
    readonly property int settingsBodyMaxHeight: 320

    readonly property int panelTopGap: 8
    readonly property int panelEdgeMargin: root.barSideMargin
    readonly property int panelSeamOverlap: 1
    readonly property int junctionRadiusDefault: 16
    readonly property int junctionRadiusMax: 32

    readonly property int hoverMs: 140
    readonly property int pressMs: 120
    readonly property int tooltipDelayMs: 1000
    readonly property int wheelMs: 160
    readonly property int wheelStep: 240

    readonly property int toastMs: 180
    readonly property int toastStickyClampMs: 30000
    readonly property int osdHoldMs: 1400
    readonly property int osdArmMs: 500
    readonly property int osdWidth: 280
    readonly property int osdHeight: 56
    readonly property int osdBottomMargin: 48
    readonly property int osdBarHeight: 4
    readonly property int focusWatchdogMs: 1000
    readonly property int focusRetryMs: 250
    readonly property int focusRetryTicks: 12
    readonly property int panelSettleMs: 20
    readonly property int cavaRestartBaseMs: 1500
    readonly property int cavaRestartMaxMs: 30000

    readonly property real pressScaleModule: 0.94
    readonly property real pressScalePill: 0.86
    readonly property real pressScaleRow: 0.985

    property bool reducedMotion: false

    readonly property int slabInset: root.barSideMargin + slabEdgePadding
    readonly property int slabEdgePadding: 6
    readonly property int hairlineVerticalInset: 8

    readonly property int panelPadding: 12
    readonly property int cardPadding: 10
    readonly property int cardHPadding: 12
    readonly property int cardRadius: 6
    readonly property int pillRadius: 4
    readonly property int pillHPadding: 8
    readonly property int pillVPadding: 3
    readonly property int quietButtonHPadding: 2
    readonly property int quietButtonVPadding: 1
    readonly property int appDotSize: 9
    readonly property int appInlineSeparatorHeight: 14
    readonly property int themeSwatchChipSize: 12
    readonly property int appRailWidth: 3
    readonly property int scrollbarWidth: 6
    readonly property int scrollbarRadius: 3
    readonly property int panelRadius: slabRadius
    readonly property int headerHeight: 34
    readonly property int dayCellGap: 4
    readonly property int dayCellHeight: 32

    readonly property int eventDotSize: 4
    readonly property int agendaTimeWidth: 44
    readonly property int volumeLabelWidth: 84
    readonly property int volumeValueWidth: 40
    readonly property int volumeStep: 5
    readonly property int usageDetailWidth: 68
    readonly property int listSpacing: 6
    readonly property int rowSpacing: 8
    readonly property int fieldPadding: 5
    readonly property int hairlineHeight: 1
    readonly property int armedEdgeWidth: 2
    readonly property int bodyScrollMin: 160
    readonly property real uiLetterSpacing: 0.6

    readonly property var screensByPosition: {
        const ordered = [];
        for (let i = 0; i < Quickshell.screens.length; i++)
            ordered.push(Quickshell.screens[i]);
        ordered.sort((a, b) => a.x - b.x || a.y - b.y
            || (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)));
        return ordered;
    }

    property string primaryMonitorOverride: ""

    readonly property bool primaryMonitorValid: root.screensByPosition.some(screen => screen.name === root.primaryMonitorOverride)

    readonly property string primaryMonitor: root.primaryMonitorValid
        ? root.primaryMonitorOverride
        : (root.screensByPosition.length > 0 ? root.screensByPosition[0].name : "")

    function triggerCenterX(triggerItem, triggerScreen): real {
        return triggerItem.mapToGlobal(triggerItem.width / 2, 0).x - (triggerScreen ? triggerScreen.x : 0);
    }

    function onPrimaryMonitor(monitorName: string): bool {
        return monitorName === "" || monitorName === root.primaryMonitor;
    }
}
