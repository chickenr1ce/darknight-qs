pragma Singleton

import QtQuick

// Single source of truth for icon glyphs. Every codepoint here is drawn with
// Globals.iconFontFamily (GeistMono Nerd Font, Material Design Icons set), so
// no icon depends on fontconfig fallback picking a foreign family.
QtObject {
    id: root

    readonly property string close: "󰅖"  // md-close U+F0156
    readonly property string cog: "󰒓"  // md-cog U+F0493
    readonly property string check: "󰄬"  // md-check U+F012C
    readonly property string plus: "󰐕"  // md-plus U+F0415
    readonly property string minus: "󰍴"  // md-minus U+F0374
    readonly property string reply: "󰑚"  // md-reply U+F045A
    readonly property string chevronUp: "󰅃"  // md-chevron_up U+F0143
    readonly property string chevronDown: "󰅀"  // md-chevron_down U+F0140
    readonly property string chevronLeft: "󰅁"  // md-chevron_left U+F0141
    readonly property string chevronRight: "󰅂"  // md-chevron_right U+F0142
    readonly property string play: "󰐊"  // md-play U+F040A
    readonly property string pause: "󰏤"  // md-pause U+F03E4
    readonly property string stop: "󰓛"  // md-stop U+F04DB
    readonly property string skipNext: "󰒭"  // md-skip_next U+F04AD
    readonly property string skipPrevious: "󰒮"  // md-skip_previous U+F04AE
    readonly property string repeat: "󰑖"  // md-repeat U+F0456
    readonly property string repeatOnce: "󰑘"  // md-repeat_once U+F0458
    readonly property string shuffle: "󰒝"  // md-shuffle U+F049D
    readonly property string music: "󰝚"  // md-music U+F075A
    readonly property string volumeHigh: "󰕾"  // md-volume_high U+F057E
    readonly property string volumeMute: "󰝟"  // md-volume_mute U+F075F
    readonly property string volumeOff: "󰖁"  // md-volume_off U+F0581
    readonly property string bell: "󰂚"  // md-bell U+F009A
    readonly property string bellBadge: "󱅫"  // md-bell_badge U+F116B
    readonly property string bellOffOutline: "󰪑"  // md-bell_off_outline U+F0A91
    readonly property string weatherSunny: "󰖙"  // md-weather_sunny U+F0599
    readonly property string weatherCloudy: "󰖕"  // md-weather_cloudy U+F0595
    readonly property string weatherFog: "󰖑"  // md-weather_fog U+F0591
    readonly property string weatherRainy: "󰖗"  // md-weather_rainy U+F0597
    readonly property string weatherSnowy: "󰖘"  // md-weather_snowy U+F0598
    readonly property string weatherStorm: "󰖓"  // md-weather_lightning U+F0593
    readonly property string location: "󰍎"  // md-map_marker U+F034E
    readonly property string power: "󰐥"  // md-power U+F0425
    readonly property string powerSleep: "󰤄"  // md-power_sleep U+F0904
    readonly property string lock: "󰌾"  // md-lock U+F033E
    readonly property string logout: "󰍃"  // md-logout U+F0343
    readonly property string restart: "󰜉"  // md-restart U+F0709
    readonly property string windows: "󰍲"  // md-microsoft U+F0372
    readonly property string distro: ""  // linux-cachyos U+F385
}
