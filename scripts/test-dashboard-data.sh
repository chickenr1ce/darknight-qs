#!/usr/bin/env bash
# Headless gate for the dashboard live-data blocks (ticket 06).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# checks two things that run anywhere:
#   1. structural assertions over the QML: the fastfetch summary, the CPU
#      plus RAM poll, the per-sink volume list, the player transport, and
#      the Open-Meteo weather fetch each live in one service the dashboard
#      composes;
#   2. python oracles mirroring the pure parsing plus mapping helpers
#      (fastfetch JSON, uptime format, /proc samples, MPRIS repeat cycle,
#      sink volume percent, Open-Meteo JSON, temperature plus rain format,
#      WMO code mapping, weather staleness) at their boundary values. Each
#      oracle cites its QML source; change the source and update the mirror
#      in the same commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "dashboard-data FAIL: $*" >&2; exit 1; }

# --- 1. new services are registered and self-contained ---
for singleton in SystemInfo SystemMonitor AudioService SpotifyService WeatherService; do
    test -f "$ROOT/services/$singleton.qml" \
        || fail "services/$singleton.qml is missing"
    grep -q "^singleton $singleton 1.0 $singleton.qml" "$ROOT/services/qmldir" \
        || fail "$singleton is not registered in services/qmldir"
done

# --- 2. fastfetch summary runs one shot on open ---
SINFO="$ROOT/services/SystemInfo.qml"
grep -q '"fastfetch"' "$SINFO" \
    || fail "SystemInfo does not run fastfetch"
grep -q '"OS:WM:Kernel:Packages:Uptime"' "$SINFO" \
    || fail "SystemInfo does not ask fastfetch for OS, WM, Kernel, Packages and Uptime"
grep -q '"--format", "json"' "$SINFO" \
    || fail "SystemInfo does not read fastfetch JSON"
grep -q 'function parseFastfetch' "$SINFO" \
    || fail "SystemInfo has no parseFastfetch"
grep -q 'function formatKernel' "$SINFO" \
    || fail "SystemInfo has no formatKernel"
grep -q 'function formatShell' "$SINFO" \
    || fail "SystemInfo has no formatShell"
grep -q 'function formatPackages' "$SINFO" \
    || fail "SystemInfo has no formatPackages"
grep -q 'function formatUptime' "$SINFO" \
    || fail "SystemInfo has no formatUptime"
grep -q 'function refresh' "$SINFO" \
    || fail "SystemInfo has no refresh"

DCENTER="$ROOT/windows/DashboardCenter.qml"
grep -q 'SystemInfo.refresh()' "$DCENTER" \
    || fail "DashboardCenter does not refresh the fastfetch summary on open"
grep -q 'onPanelVisibleChanged' "$DCENTER" \
    || fail "DashboardCenter has no open hook for the fastfetch refresh"

SBLOCK="$ROOT/windows/DashboardSystemBlock.qml"
grep -q 'SystemInfo.distro' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live distro"
grep -q 'SystemInfo.compositor' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live compositor"
grep -q 'SystemInfo.kernelText' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live kernel"
grep -q 'SystemInfo.shellText' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live shell"
grep -q 'SystemInfo.packagesText' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live package count"
grep -q 'SystemInfo.uptimeText' "$SBLOCK" \
    || fail "DashboardSystemBlock does not read the live uptime"

# --- 2b. dashboard theme block: live palette, no stub wallpaper grid ---
# The block is the switcher's second home: its swatches bind the shared mapped
# list, the name comes from the active theme, and the empty wallpaper grid is
# gone (ticket 08 owns the background picker).
TBLOCK="$ROOT/windows/DashboardThemeBlock.qml"
if grep -qE '\[[[:space:]]*Colors\.' "$TBLOCK"; then
    fail "DashboardThemeBlock still binds a literal swatch list"
fi
grep -q 'Colors.themeSwatches' "$TBLOCK" \
    || fail "DashboardThemeBlock does not bind the shared mapped swatches"
grep -q 'ThemeService.activeDisplayName' "$TBLOCK" \
    || fail "DashboardThemeBlock does not show the live theme name"
grep -q 'ThemeService.backgroundList' "$TBLOCK" \
    || fail "DashboardThemeBlock does not bind the background list"
grep -q 'ThemeService.currentBackgroundName' "$TBLOCK" \
    || fail "DashboardThemeBlock does not mark the current background"
grep -q 'ThemeService.selectBackground' "$TBLOCK" \
    || fail "DashboardThemeBlock does not pick a background through ThemeService"
grep -q 'BackgroundTile' "$TBLOCK" \
    || fail "DashboardThemeBlock does not render background thumbnails"
if grep -q 'awww' "$TBLOCK"; then
    fail "DashboardThemeBlock applies the background itself; ThemeService owns the awww call"
fi
if grep -qi 'wallpaper' "$TBLOCK"; then
    fail "DashboardThemeBlock still renders the empty wallpaper grid"
fi

# --- 3. CPU plus RAM poll procfs, no subprocess ---
SMON="$ROOT/services/SystemMonitor.qml"
grep -q '"/proc/stat"' "$SMON" \
    || fail "SystemMonitor does not read /proc/stat"
grep -q '"/proc/meminfo"' "$SMON" \
    || fail "SystemMonitor does not read /proc/meminfo"
grep -q 'function parseCpuSample' "$SMON" \
    || fail "SystemMonitor has no parseCpuSample"
grep -q 'function parseRamPercent' "$SMON" \
    || fail "SystemMonitor has no parseRamPercent"
grep -q 'property real cpuUsagePercent' "$SMON" \
    || fail "SystemMonitor has no cpuUsagePercent"
grep -q 'property real ramUsagePercent' "$SMON" \
    || fail "SystemMonitor has no ramUsagePercent"
if grep -q 'Process' "$SMON"; then
    fail "SystemMonitor spawns a process; procfs reads stay in-process"
fi

grep -q '"/proc/net/dev"' "$SMON" \
    || fail "SystemMonitor does not read /proc/net/dev"
grep -q 'gpu_busy_percent' "$SMON" \
    || fail "SystemMonitor does not read the GPU busy percent"
grep -q 'function parseNetSample' "$SMON" \
    || fail "SystemMonitor has no parseNetSample"
grep -q 'function parseRamSample' "$SMON" \
    || fail "SystemMonitor has no parseRamSample"
grep -q 'property real gpuUsagePercent' "$SMON" \
    || fail "SystemMonitor has no gpuUsagePercent"
grep -q 'property real netRxBytesPerSec' "$SMON" \
    || fail "SystemMonitor has no netRxBytesPerSec"
grep -q 'property real ramUsedBytes' "$SMON" \
    || fail "SystemMonitor has no ramUsedBytes"
grep -q 'function parseTemp' "$SMON" \
    || fail "SystemMonitor has no parseTemp"
grep -q 'property real cpuTempC' "$SMON" \
    || fail "SystemMonitor has no cpuTempC"
grep -q 'property real gpuTempC' "$SMON" \
    || fail "SystemMonitor has no gpuTempC"

CBLOCK="$ROOT/windows/DashboardCpuBlock.qml"
grep -q 'SystemMonitor.cpuUsagePercent' "$CBLOCK" \
    || fail "DashboardCpuBlock does not read the live CPU use"
grep -q 'SystemMonitor.ramUsagePercent' "$CBLOCK" \
    || fail "DashboardCpuBlock does not read the live RAM use"
grep -q 'SystemMonitor.gpuUsagePercent' "$CBLOCK" \
    || fail "DashboardCpuBlock does not read the live GPU use"
grep -q 'SystemMonitor.ramUsedText' "$CBLOCK" \
    || fail "DashboardCpuBlock does not show the RAM amount"
grep -q 'SystemMonitor.netRxText' "$CBLOCK" \
    || fail "DashboardCpuBlock does not show the network rate"
grep -q 'SystemMonitor.cpuTempC' "$CBLOCK" \
    || fail "DashboardCpuBlock does not show the CPU temperature"

# --- 4. per-sink volume list extends the audio seam ---
# Outputs are discovered from pipewire at runtime, then curated through a
# persisted order and hidden set. No hardware allowlist.
ASVC="$ROOT/services/AudioService.qml"
grep -q 'Pipewire.nodes.values' "$ASVC" \
    || fail "AudioService does not enumerate pipewire nodes"
grep -q 'function isSinkNode' "$ASVC" \
    || fail "AudioService has no isSinkNode filter"
grep -q 'node.isSink && !node.isStream' "$ASVC" \
    || fail "AudioService keeps streams or sources in the sink list"
grep -q 'function keyFor' "$ASVC" \
    || fail "AudioService has no stable output key"
grep -q 'function rawLabelFor' "$ASVC" \
    || fail "AudioService has no rawLabelFor display label"
grep -q 'function orderedNodes' "$ASVC" \
    || fail "AudioService has no orderedNodes curation order"
grep -q 'function setHidden' "$ASVC" \
    || fail "AudioService has no setHidden curation"
grep -q 'function moveOutput' "$ASVC" \
    || fail "AudioService has no moveOutput curation"
grep -q 'function percentForVolume' "$ASVC" \
    || fail "AudioService has no percentForVolume"
grep -q 'function volumeForPercent' "$ASVC" \
    || fail "AudioService has no volumeForPercent"
grep -q 'function setVolume' "$ASVC" \
    || fail "AudioService has no setVolume"
grep -q 'name: "audio-outputs"' "$ASVC" \
    || fail "AudioService does not persist curated outputs behind a StateFile"
if grep -q 'function setLabel\|labelOverrides' "$ASVC"; then
    fail "AudioService still carries the removed rename state"
fi
if grep -q 'match: "JadeAudio"\|match: "AB13X"\|match: "Pebble"' "$ASVC" "$ROOT/modules/Audio.qml"; then
    fail "AudioService or the bar Audio module still hardcodes a sink catalog"
fi
grep -q 'AudioService.sinks' "$ROOT/modules/Audio.qml" \
    || fail "the bar Audio module does not read the live sink list"
grep -q 'AudioService.rawLabelFor' "$ROOT/modules/Audio.qml" \
    || fail "the bar Audio module does not use the output label"

VBLOCK="$ROOT/windows/DashboardVolumeBlock.qml"
grep -q 'AudioService.sinks' "$VBLOCK" \
    || fail "DashboardVolumeBlock does not list the audio outputs"
grep -q 'AudioService.setVolume' "$VBLOCK" \
    || fail "DashboardVolumeBlock cannot set a sink volume"
grep -q 'Slider' "$VBLOCK" \
    || fail "DashboardVolumeBlock has no slider per output"

# --- 5. player transport plus repeat plus shuffle ride the MPRIS seam ---
MPLAYERS="$ROOT/services/MprisPlayers.qml"
grep -q 'function nextLoopState' "$MPLAYERS" \
    || fail "MprisPlayers has no nextLoopState mapping"
grep -q 'function cycleRepeat' "$MPLAYERS" \
    || fail "MprisPlayers has no cycleRepeat"
grep -q 'function toggleShuffle' "$MPLAYERS" \
    || fail "MprisPlayers has no toggleShuffle"
grep -q 'function formatTime' "$MPLAYERS" \
    || fail "MprisPlayers has no formatTime"
grep -q 'function setAllowed' "$MPLAYERS" \
    || fail "MprisPlayers has no setAllowed"
grep -q 'name: "mpris-players"' "$MPLAYERS" \
    || fail "MprisPlayers does not persist the app filter"
grep -q 'property var browserTokens' "$MPLAYERS" \
    || fail "MprisPlayers does not seed the browsers as hidden"
grep -q 'Mpris.players.values.filter' "$MPLAYERS" \
    || fail "MprisPlayers playerList does not filter by the app filter"

PBLOCK="$ROOT/windows/DashboardPlayerBlock.qml"
grep -q 'MprisPlayers.activePlayer' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not read the active player"
grep -q 'trackTitle' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not show the live track"
grep -q 'trackArtist' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not show the live artist"
grep -q 'player.togglePlaying()' "$PBLOCK" \
    || fail "DashboardPlayerBlock play pause is not wired"
grep -q 'player.next()' "$PBLOCK" \
    || fail "DashboardPlayerBlock next is not wired"
grep -q 'player.previous()' "$PBLOCK" \
    || fail "DashboardPlayerBlock previous is not wired"
grep -q 'MprisPlayers.cycleRepeat()' "$PBLOCK" \
    || fail "DashboardPlayerBlock repeat is not wired"
grep -q 'MprisPlayers.toggleShuffle()' "$PBLOCK" \
    || fail "DashboardPlayerBlock shuffle is not wired"
grep -q 'trackArtUrl' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not bind the track art"
grep -q 'CoverArtButton' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not compose the shared CoverArtButton"
test -f "$ROOT/components/CoverArtButton.qml" \
    || fail "components/CoverArtButton.qml is missing"
grep -q 'ClippingRectangle' "$ROOT/components/CoverArtButton.qml" \
    || fail "CoverArtButton does not clip the art to the card radius"
grep -q 'SpotifyService.devices' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not list the Connect devices"
grep -q 'SpotifyService.transferTo' "$PBLOCK" \
    || fail "DashboardPlayerBlock cannot transfer Spotify playback"
grep -q 'modelData.isActive' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not mark the active device"
grep -q 'modelData.isRestricted' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not gate restricted devices"

SSVC="$ROOT/services/SpotifyService.qml"
grep -q 'spotify-connect.py' "$SSVC" \
    || fail "SpotifyService does not call the Connect backend"
grep -q 'function refreshDevices' "$SSVC" \
    || fail "SpotifyService has no refreshDevices"
grep -q 'function transferTo' "$SSVC" \
    || fail "SpotifyService has no transferTo"
grep -q 'function parseResponse' "$SSVC" \
    || fail "SpotifyService has no parseResponse"
grep -q '"--play"' "$SSVC" \
    || fail "SpotifyService transfer must ask for playback so the switch takes effect"
grep -q 'DashboardService.dashboardVisible' "$SSVC" \
    || fail "SpotifyService does not gate its poll on the dashboard"
if grep -q 'access_token' "$SSVC"; then
    fail "SpotifyService must not read the token; the backend owns it"
fi

# The transport glyphs exist in the one icon registry.
for glyph in skipNext skipPrevious repeat repeatOnce shuffle; do
    grep -q "property string $glyph" "$ROOT/config/Icons.qml" \
        || fail "Icons.qml misses the $glyph glyph"
done

# --- 6. weather fetch rides Open-Meteo with a last-good cache plus stale ---
WSVC="$ROOT/services/WeatherService.qml"
grep -q 'api.open-meteo.com' "$WSVC" \
    || fail "WeatherService does not fetch Open-Meteo"
grep -q '"curl"' "$WSVC" \
    || fail "WeatherService does not poll through curl"
grep -q 'property real latitude' "$WSVC" \
    || fail "WeatherService has no latitude"
grep -q 'property real longitude' "$WSVC" \
    || fail "WeatherService has no longitude"
grep -q '52.52' "$WSVC" \
    || fail "WeatherService is not pinned to the Berlin latitude"
grep -q '13.41' "$WSVC" \
    || fail "WeatherService is not pinned to the Berlin longitude"
grep -q 'pollMs: 30 \* 60 \* 1000' "$WSVC" \
    || fail "WeatherService does not poll every 30 minutes"
grep -q 'staleAfterMs: 60 \* 60 \* 1000' "$WSVC" \
    || fail "WeatherService does not mark stale after 60 minutes"
grep -q 'property real temperatureC' "$WSVC" \
    || fail "WeatherService has no temperatureC"
grep -q 'property int weatherCode' "$WSVC" \
    || fail "WeatherService has no weatherCode"
grep -q 'property real precipProb' "$WSVC" \
    || fail "WeatherService has no precipProb"
grep -q 'property double fetchedAtMs' "$WSVC" \
    || fail "WeatherService has no fetchedAtMs"
grep -q 'property bool lastPollFailed' "$WSVC" \
    || fail "WeatherService has no lastPollFailed"
grep -q 'function parseWeather' "$WSVC" \
    || fail "WeatherService has no parseWeather"
grep -q 'function formatTemp' "$WSVC" \
    || fail "WeatherService has no formatTemp"
grep -q 'function formatPrecip' "$WSVC" \
    || fail "WeatherService has no formatPrecip"
grep -q 'function glyphFor' "$WSVC" \
    || fail "WeatherService has no glyphFor"
grep -q 'function isStale' "$WSVC" \
    || fail "WeatherService has no isStale"
grep -q 'function refresh' "$WSVC" \
    || fail "WeatherService has no refresh"
grep -q 'function repoll' "$WSVC" \
    || fail "WeatherService has no repoll"
grep -q 'function requestUrl' "$WSVC" \
    || fail "WeatherService has no requestUrl"
grep -q 'function applyPayload' "$WSVC" \
    || fail "WeatherService has no applyPayload"
grep -q 'function applyCache' "$WSVC" \
    || fail "WeatherService has no applyCache"
grep -q 'function saveCache' "$WSVC" \
    || fail "WeatherService has no saveCache"
grep -q 'name: "weather.json"' "$WSVC" \
    || fail "WeatherService does not persist a weather.json cache"
grep -q 'current.temperature_2m' "$WSVC" \
    || fail "WeatherService does not map the current temperature"
grep -q 'current.weather_code' "$WSVC" \
    || fail "WeatherService does not map the weather code"
grep -q 'precipitation_probability_max' "$WSVC" \
    || fail "WeatherService does not map the rain probability"
grep -q 'temperature_2m_max' "$WSVC" \
    || fail "WeatherService does not map the daily high"
grep -q 'temperature_2m_min' "$WSVC" \
    || fail "WeatherService does not map the daily low"
grep -q 'Icons.weatherCloudy' "$WSVC" \
    || fail "WeatherService does not map cloudy codes"
grep -q 'Icons.weatherRainy' "$WSVC" \
    || fail "WeatherService does not map rainy codes"
grep -q 'Icons.weatherSnowy' "$WSVC" \
    || fail "WeatherService does not map snowy codes"
grep -q 'Icons.weatherStorm' "$WSVC" \
    || fail "WeatherService does not map storm codes"
grep -q 'Icons.weatherFog' "$WSVC" \
    || fail "WeatherService does not map fog codes"
grep -q '^import qs.services' "$WSVC" \
    || fail "WeatherService.qml is missing its qs.services self-import"
grep -q 'geocoding-api.open-meteo.com' "$WSVC" \
    || fail "WeatherService does not search the Open-Meteo geocoding API"
grep -q 'count=5' "$WSVC" \
    || fail "WeatherService does not cap geocoding results"
grep -q 'property string locationName' "$WSVC" \
    || fail "WeatherService has no locationName"
grep -q 'property var locationResults' "$WSVC" \
    || fail "WeatherService has no locationResults"
grep -q 'function geocodeUrl' "$WSVC" \
    || fail "WeatherService has no geocodeUrl"
grep -q 'function searchLocations' "$WSVC" \
    || fail "WeatherService has no searchLocations"
grep -q 'function repollGeocode' "$WSVC" \
    || fail "WeatherService has no repollGeocode"
grep -q 'function parseLocations' "$WSVC" \
    || fail "WeatherService has no parseLocations"
grep -q 'function selectLocation' "$WSVC" \
    || fail "WeatherService has no selectLocation"
grep -q 'function applyLocation' "$WSVC" \
    || fail "WeatherService has no applyLocation"
grep -q 'function saveLocation' "$WSVC" \
    || fail "WeatherService has no saveLocation"
grep -q 'name: "weather-location"' "$WSVC" \
    || fail "WeatherService does not persist the city"
grep -q 'payload\["latitude"\]' "$WSVC" \
    || fail "WeatherService cache does not record the city coordinates"
grep -q 'parsed.latitude' "$WSVC" \
    || fail "WeatherService does not reject a cache from another city"
if grep -q 'Process' "$ROOT/windows/DashboardWeatherBlock.qml"; then
    fail "DashboardWeatherBlock spawns a process; the service owns the fetch"
fi

WBLOCK="$ROOT/windows/DashboardWeatherBlock.qml"
grep -q 'WeatherService.tempText' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live temperature"
grep -q 'WeatherService.precipText' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live rain probability"
grep -q 'WeatherService.highText' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live daily high"
grep -q 'WeatherService.lowText' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live daily low"
grep -q 'WeatherService.glyph' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live condition glyph"
grep -q 'WeatherService.city' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not read the live city"
grep -q 'WeatherService.stale' "$WBLOCK" \
    || fail "DashboardWeatherBlock does not show the stale marker"
grep -q 'WeatherService.refresh()' "$DCENTER" \
    || fail "DashboardCenter does not refresh the weather on open"

# The weather glyphs exist in the one icon registry.
for glyph in weatherSunny weatherCloudy weatherFog weatherRainy weatherSnowy weatherStorm; do
    grep -q "property string $glyph" "$ROOT/config/Icons.qml" \
        || fail "Icons.qml misses the $glyph glyph"
done

# Reading surfaces carry palette tokens only.
for surface in "$SINFO" "$SMON" "$ASVC" "$WSVC" "$SBLOCK" "$CBLOCK" "$VBLOCK" "$PBLOCK" "$WBLOCK"; do
    if grep -qnE '#[0-9a-fA-F]{3,8}' "$surface"; then
        fail "$(basename "$surface") carries raw hex; palette tokens only"
    fi
done

# --- 7. python oracles for the pure parsing plus mapping helpers ---
python3 - "$ROOT/tests/fixtures/fastfetch-summary.json" "$ROOT/tests/fixtures/open-meteo-forecast.json" <<'EOF'
import json
import math
import sys

def check(name, got, want):
    if got != want:
        print(f"dashboard-data FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

def js_round(value):
    return math.floor(value + 0.5)

# Mirror of AudioService output discovery (services/AudioService.qml): every
# real sink is discovered at runtime, then a saved order and hidden set curate
# it. A saved key orders first; outputs the user has not seen append after it
# sorted by label, so a fresh install lists its own hardware.
def is_sink_node(node):
    return bool(node) and node.get("isSink", False) and not node.get("isStream", False) and node.get("audio") is not None

def key_for(node):
    if not node:
        return ""
    return node.get("name") or node.get("description") or node.get("nickname") or str(node.get("id"))

def raw_label_for(node):
    if not node:
        return ""
    return node.get("description") or node.get("nickname") or node.get("name") or ""

def ordered_nodes(nodes, order):
    out = []
    for key in order:
        for node in nodes:
            if key_for(node) == key:
                out.append(node)
                break
    rest = [node for node in nodes if key_for(node) not in order]
    rest.sort(key=lambda node: raw_label_for(node).lower())
    out.extend(rest)
    return out

def visible_sinks(nodes, hidden=None, order=None):
    hidden = hidden or []
    order = order or []
    out = []
    real = [node for node in nodes if is_sink_node(node)]
    for node in ordered_nodes(real, order):
        key = key_for(node)
        if key in hidden:
            continue
        out.append({"key": key, "label": raw_label_for(node)})
    return out

HDMI = {"isSink": True, "isStream": False, "audio": {}, "description": "Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI) [LG ULTRAGEAR]", "name": "alsa_output.pci-0000_28_00.1.hdmi-stereo"}
EASY = {"isSink": True, "isStream": False, "audio": {}, "description": "Easy Effects Sink", "name": "easyeffects_sink"}
JADE = {"isSink": True, "isStream": False, "audio": {}, "description": "JadeAudio JIEZI Analog Stereo", "name": "alsa_output.usb-JadeAudio_JIEZI-00.analog-stereo"}
AB13X = {"isSink": True, "isStream": False, "audio": {}, "description": "AB13X Headset Adapter Analog Stereo", "name": "alsa_output.usb-AB13X-00.analog-stereo"}
PEBBLE = {"isSink": True, "isStream": False, "audio": {}, "description": "Pebble V3 Analog Stereo", "name": "alsa_output.usb-Creative_Pebble_V3-00.analog-stereo"}

check("sink/real", is_sink_node({"isSink": True, "isStream": False, "audio": {}}), True)
check("sink/stream", is_sink_node({"isSink": True, "isStream": True, "audio": {}}), False)
check("sink/source", is_sink_node({"isSink": False, "isStream": False, "audio": {}}), False)
check("sink/no-audio", is_sink_node({"isSink": True, "isStream": False, "audio": None}), False)
check("sink/key-prefers-name", key_for(PEBBLE), PEBBLE["name"])
check("sink/key-falls-back", key_for({"description": "Fallback", "id": 7}), "Fallback")
check("sink/discover-all", [s["label"] for s in visible_sinks([PEBBLE, HDMI, JADE])], [JADE["description"], HDMI["description"], PEBBLE["description"]])
check("sink/hidden-drops", [s["key"] for s in visible_sinks([JADE, EASY, PEBBLE], hidden=[key_for(EASY)])], [key_for(JADE), key_for(PEBBLE)])
check("sink/saved-order", [s["key"] for s in visible_sinks([JADE, PEBBLE, HDMI], order=[key_for(PEBBLE), key_for(JADE)])], [key_for(PEBBLE), key_for(JADE), key_for(HDMI)])
check("sink/drops-non-sinks", visible_sinks([{"isSink": False, "isStream": False, "audio": {}, "name": "mic"}]), [])

# Mirror of AudioService.percentForVolume plus volumeForPercent.
def percent_for_volume(volume):
    try:
        value = float(volume)
    except (TypeError, ValueError):
        return 0
    if math.isnan(value):
        return 0
    return js_round(max(0.0, min(1.0, value)) * 100)

def volume_for_percent(percent):
    try:
        value = float(percent)
    except (TypeError, ValueError):
        return 0
    if math.isnan(value):
        return 0
    return max(0.0, min(100.0, value)) / 100

check("volume/round-half-up", percent_for_volume(0.555), 56)
check("volume/clamp-high", percent_for_volume(1.4), 100)
check("volume/clamp-low", percent_for_volume(-0.2), 0)
check("volume/nan", percent_for_volume("nope"), 0)
check("volume/percent-clamp", volume_for_percent(140), 1.0)
check("volume/percent-low", volume_for_percent(-10), 0.0)
check("volume/round-trip", percent_for_volume(volume_for_percent(55)), 55)

# Mirror of MprisPlayers.nextLoopState (services/MprisPlayers.qml):
# None(0) -> Playlist(2) -> Track(1) -> None.
def next_loop_state(current):
    if current == 2:
        return 1
    if current == 1:
        return 0
    return 2

check("repeat/none", next_loop_state(0), 2)
check("repeat/playlist", next_loop_state(2), 1)
check("repeat/track", next_loop_state(1), 0)
check("repeat/cycle", [next_loop_state(v) for v in (0, 2, 1)], [2, 1, 0])

# Mirror of MprisPlayers.toggleShuffle (services/MprisPlayers.qml): flip the
# shuffle flag only while the player advertises shuffle support.
def toggle_shuffle(shuffle, supported):
    return (not shuffle) if supported else shuffle

check("shuffle/on", toggle_shuffle(False, True), True)
check("shuffle/off", toggle_shuffle(True, True), False)
check("shuffle/unsupported", toggle_shuffle(True, False), True)

# Mirror of MprisPlayers.formatTime (services/MprisPlayers.qml): the MPRIS
# position/length in seconds render as m:ss, clamped at zero.
def format_time(seconds):
    total = max(0, math.floor(float(seconds or 0)))
    return f"{total // 60}:{total % 60:02d}"

check("time/zero", format_time(0), "0:00")
check("time/seconds", format_time(74), "1:14")
check("time/pad", format_time(65), "1:05")
check("time/negative", format_time(-5), "0:00")
check("time/long", format_time(3725), "62:05")

# Mirror of MprisPlayers.defaultAllowed (services/MprisPlayers.qml): the browser
# seed hides a known browser key by exact token or substring, everything else
# stays allowed.
BROWSER_TOKENS = ["firefox", "firefox-esr", "waterfox", "floorp", "zen-browser",
                  "chromium", "chrome", "brave", "vivaldi", "opera",
                  "microsoft-edge", "thorium", "ladybird", "epiphany"]
BROWSER_EXACT = ["zen"]

def default_allowed(key):
    if key in BROWSER_EXACT:
        return False
    return not any(token in key for token in BROWSER_TOKENS)

check("filter/spotify", default_allowed("spotify"), True)
check("filter/firefox", default_allowed("firefox"), False)
check("filter/firefox-identity", default_allowed("mozilla firefox"), False)
check("filter/zen", default_allowed("zen"), False)
check("filter/zen-partial", default_allowed("citizen"), True)
check("filter/vlc", default_allowed("vlc"), True)

# Mirror of MprisPlayers.playerKey/parseApps/applyApps (services/MprisPlayers.qml):
# keys are lowercased and instance suffixes dropped; a malformed file parses to
# no entries; a load keeps in-memory entries the file does not know.
def player_key(desktop_entry, identity, dbus_name):
    key = (desktop_entry or identity or dbus_name or "").lower().strip()
    return key.split(".instance")[0]

def parse_apps(text):
    out = {}
    try:
        parsed = json.loads(text)
    except Exception:
        return out
    if not isinstance(parsed, dict) or not isinstance(parsed.get("apps"), dict):
        return out
    for key, entry in parsed["apps"].items():
        if not isinstance(entry, dict):
            continue
        label = entry.get("label")
        out[key.lower()] = {
            "label": label if isinstance(label, str) and label != "" else key,
            "allowed": entry.get("allowed") is not False,
        }
    return out

def apply_apps(current, text):
    stored = parse_apps(text)
    for key, value in current.items():
        if key not in stored:
            stored[key] = value
    return stored

check("filter/key-desktop", player_key("Spotify", "Spotify", ""), "spotify")
check("filter/key-identity", player_key("", "Mozilla firefox", ""), "mozilla firefox")
check("filter/key-instance", player_key("", "", "org.mpris.MediaPlayer2.firefox.instance_1_50"),
      "org.mpris.mediaplayer2.firefox")
check("filter/parse-malformed", parse_apps("{ not json"), {})
check("filter/parse-empty", parse_apps('{"apps": {}}'), {})
check("filter/parse-label-fallback",
      parse_apps('{"apps": {"firefox": {"allowed": false}}}')["firefox"],
      {"label": "firefox", "allowed": False})
check("filter/parse-strict-allowed",
      parse_apps('{"apps": {"vlc": {"label": "VLC", "allowed": 0}}}')["vlc"]["allowed"], True)
check("filter/merge-keeps-current",
      sorted(apply_apps({"spotify": {"label": "Spotify", "allowed": True}},
                        '{"apps": {"firefox": {"label": "Mozilla firefox", "allowed": false}}}').keys()),
      ["firefox", "spotify"])
check("filter/merge-stored-wins",
      apply_apps({"firefox": {"label": "old", "allowed": True}},
                 '{"apps": {"firefox": {"label": "Mozilla firefox", "allowed": false}}}')["firefox"]["allowed"],
      False)

# Mirror of SpotifyService.parseResponse (services/SpotifyService.qml): the
# backend prints one JSON object per call; ok gates the payload and a bad
# stream falls back to an empty state instead of throwing.
def parse_response(text):
    out = {"ok": False, "error": "", "message": "", "devices": [], "activeId": ""}
    try:
        parsed = json.loads(text)
    except Exception:
        return out
    if parsed is None or not isinstance(parsed, (dict, list)):
        return out
    if isinstance(parsed, dict):
        out["ok"] = parsed.get("ok") is True
        out["error"] = parsed.get("error") or ""
        out["activeId"] = parsed.get("activeId") or ""
        devices = parsed.get("devices")
        out["devices"] = devices if isinstance(devices, list) else []
    return out

ok = parse_response('{"ok": true, "activeId": "d1", "devices": [{"id": "d1", "name": "PC"}]}')
check("spotify/ok", ok["ok"], True)
check("spotify/devices", ok["devices"], [{"id": "d1", "name": "PC"}])
check("spotify/active", ok["activeId"], "d1")
check("spotify/auth-missing", parse_response('{"ok": false, "error": "auth_missing"}')["error"], "auth_missing")
check("spotify/garbage", parse_response("{nope")["ok"], False)
check("spotify/devices-not-list", parse_response('{"ok": true, "devices": "x"}')["devices"], [])
check("spotify/null", parse_response("null")["ok"], False)
# Mirror of WeatherService.parseWeather (services/WeatherService.qml): the
# Open-Meteo current block is required, the daily high/low plus rain
# probability fall back to the current temperature and unknown.
def parse_weather(text):
    try:
        parsed = json.loads(text)
    except Exception:
        return None
    if not isinstance(parsed, dict):
        return None
    current = parsed.get("current")
    if not isinstance(current, dict):
        return None
    try:
        temperature = float(current.get("temperature_2m"))
        code = round(float(current.get("weather_code")))
    except (TypeError, ValueError):
        return None
    if math.isnan(temperature) or math.isnan(code):
        return None
    high = temperature
    low = temperature
    precip = -1
    daily = parsed.get("daily")
    if isinstance(daily, dict):
        maxima = daily.get("temperature_2m_max")
        if isinstance(maxima, list) and len(maxima) > 0:
            try:
                value = float(maxima[0])
                if not math.isnan(value):
                    high = value
            except (TypeError, ValueError):
                pass
        minima = daily.get("temperature_2m_min")
        if isinstance(minima, list) and len(minima) > 0:
            try:
                value = float(minima[0])
                if not math.isnan(value):
                    low = value
            except (TypeError, ValueError):
                pass
        probs = daily.get("precipitation_probability_max")
        if isinstance(probs, list) and len(probs) > 0:
            try:
                value = float(probs[0])
                if not math.isnan(value):
                    precip = value
            except (TypeError, ValueError):
                pass
    return {"temperatureC": temperature, "weatherCode": code, "precipProb": precip, "highC": high, "lowC": low}

weather_fixture = open(sys.argv[2]).read()
check("weather/fixture", parse_weather(weather_fixture), {"temperatureC": 15.2, "weatherCode": 2, "precipProb": 10.0, "highC": 19.1, "lowC": 11.3})
check("weather/malformed", parse_weather("{nope"), None)
check("weather/not-object", parse_weather("[1, 2]"), None)
check("weather/missing-current", parse_weather('{"daily": {}}'), None)
check("weather/bad-temp", parse_weather('{"current": {"temperature_2m": "warm", "weather_code": 2}}'), None)
check("weather/bad-code", parse_weather('{"current": {"temperature_2m": 15.2}}'), None)
check("weather/no-daily", parse_weather('{"current": {"temperature_2m": 15.2, "weather_code": 0}}'), {"temperatureC": 15.2, "weatherCode": 0, "precipProb": -1, "highC": 15.2, "lowC": 15.2})

# Mirror of WeatherService.formatTemp (services/WeatherService.qml): whole
# degrees plus a degree sign, empty when the reading is missing.
def format_temp(celsius):
    try:
        value = float(celsius)
    except (TypeError, ValueError):
        return ""
    if math.isnan(value):
        return ""
    return f"{js_round(value)}°"

check("temp/fixture", format_temp(15.2), "15°")
check("temp/rounds", format_temp(-2.6), "-3°")
check("temp/zero", format_temp(0), "0°")
check("temp/missing", format_temp(float("nan")), "")

# Mirror of WeatherService.formatPrecip (services/WeatherService.qml):
# percent clamped to 0..100, empty while unknown (negative).
def format_precip(percent):
    try:
        value = float(percent)
    except (TypeError, ValueError):
        return ""
    if math.isnan(value) or value < 0:
        return ""
    return f"{js_round(max(0.0, min(100.0, value)))}%"

check("precip/fixture", format_precip(10), "10%")
check("precip/zero", format_precip(0), "0%")
check("precip/clamp", format_precip(140), "100%")
check("precip/unknown", format_precip(-1), "")
check("precip/bad", format_precip("damp"), "")

# Mirror of WeatherService.glyphFor (services/WeatherService.qml): WMO
# weather codes bucketed onto the six Icons.qml weather glyphs.
def glyph_for(code):
    try:
        c = round(float(code))
    except (TypeError, ValueError):
        return "cloudy"
    if c in (0, 1):
        return "sunny"
    if c in (2, 3):
        return "cloudy"
    if c in (45, 48):
        return "fog"
    if (51 <= c <= 57) or (61 <= c <= 67) or (80 <= c <= 82):
        return "rainy"
    if (71 <= c <= 77) or c in (85, 86):
        return "snowy"
    if 95 <= c <= 99:
        return "storm"
    if c < 0:
        return "sunny"
    return "cloudy"

check("glyph/clear", glyph_for(0), "sunny")
check("glyph/mainly-clear", glyph_for(1), "sunny")
check("glyph/partly-cloudy", glyph_for(2), "cloudy")
check("glyph/overcast", glyph_for(3), "cloudy")
check("glyph/fog", glyph_for(45), "fog")
check("glyph/rime-fog", glyph_for(48), "fog")
check("glyph/drizzle", glyph_for(53), "rainy")
check("glyph/rain", glyph_for(63), "rainy")
check("glyph/showers", glyph_for(81), "rainy")
check("glyph/snow", glyph_for(73), "snowy")
check("glyph/snow-showers", glyph_for(85), "snowy")
check("glyph/storm", glyph_for(95), "storm")
check("glyph/hail-storm", glyph_for(99), "storm")
check("glyph/missing", glyph_for(-1), "sunny")

# Mirror of WeatherService.isStale (services/WeatherService.qml): a failed
# poll reads stale at once, otherwise the cache lapses after 60 minutes.
STALE_AFTER_MS = 60 * 60 * 1000

def is_stale(now_ms, fetched_at_ms, failed):
    if failed:
        return True
    if not (fetched_at_ms > 0):
        return False
    return (now_ms - fetched_at_ms) > STALE_AFTER_MS

NOW = 1800000000000
check("stale/failed", is_stale(NOW, NOW, True), True)
check("stale/never", is_stale(NOW, 0, False), False)
check("stale/fresh", is_stale(NOW, NOW - 30 * 60 * 1000, False), False)
check("stale/old", is_stale(NOW, NOW - 61 * 60 * 1000, False), True)
EOF

# Run the shipped SystemInfo/SystemMonitor parsers and formatters under node.
# The twelve mirrors (five SystemInfo, seven SystemMonitor) are gone; every
# case they checked runs against services/SystemLogic.js, plus the cpu/net
# delta math pulled out of applyCpuSample and applyNetSample.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/SystemLogic.js" "$ROOT/tests/fixtures/fastfetch-summary.json" <<'NODEEOF'
const fs = require('fs');
const qmljs = require(process.argv[2]);
const check = qmljs.checker('dashboard-data');
const sl = qmljs.load(process.argv[3]);
const fixture = fs.readFileSync(process.argv[4], 'utf8');

const parsed = sl.parseFastfetch(fixture);
check('fastfetch/fixture', parsed, { distro: 'Arch Linux', compositor: 'Hyprland', kernel: '6.13.4-arch1-1', packages: 942, uptimeMs: 4980000 });
check('fastfetch/malformed', sl.parseFastfetch('{nope'), { distro: '', compositor: '', kernel: '', packages: 0, uptimeMs: 0 });
check('fastfetch/not-list', sl.parseFastfetch('{"type": "OS"}'), { distro: '', compositor: '', kernel: '', packages: 0, uptimeMs: 0 });
check('fastfetch/missing-result', sl.parseFastfetch('[{"type": "WM"}]'), { distro: '', compositor: '', kernel: '', packages: 0, uptimeMs: 0 });
check('fastfetch/name-fallback', sl.parseFastfetch('[{"type": "OS", "result": {"name": "Fixtures"}}]').distro, 'Fixtures');
check('fastfetch/process-fallback', sl.parseFastfetch('[{"type": "WM", "result": {"processName": "niri"}}]').compositor, 'niri');
check('fastfetch/kernel', sl.parseFastfetch(fixture).kernel, '6.13.4-arch1-1');
check('fastfetch/packages-missing', sl.parseFastfetch('[{"type": "Packages", "result": {}}]').packages, 0);

check('kernel/dash-suffix', sl.formatKernel('6.13.4-arch1-1'), '6.13.4');
check('kernel/cachy', sl.formatKernel('7.2.8-1-cachyos'), '7.2.8');
check('kernel/bare', sl.formatKernel('6.13.4'), '6.13.4');
check('kernel/empty', sl.formatKernel(''), '');

check('shell/absolute', sl.formatShell('/usr/bin/fish'), 'fish');
check('shell/bin', sl.formatShell('/bin/zsh'), 'zsh');
check('shell/bare', sl.formatShell('bash'), 'bash');
check('shell/empty', sl.formatShell(''), '');

check('packages/fixture', sl.formatPackages(942), '942');
check('packages/zero', sl.formatPackages(0), '');
check('packages/thousand', sl.formatPackages(1000), '1.0k');
check('packages/rounded', sl.formatPackages(1819), '1.8k');

check('uptime/fixture', sl.formatUptime(4980000), '1h 23m');
check('uptime/zero', sl.formatUptime(0), '');
check('uptime/minutes', sl.formatUptime(45 * 60000), '45m');
check('uptime/days', sl.formatUptime(93600000), '1d 2h');

const cpuFirst = sl.parseCpuSample('cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3 4');
check('cpu/parse', cpuFirst, { total: 1000, idle: 800 });
check('cpu/first-no-usage', sl.cpuPercent(-1, 0, cpuFirst), null);
const cpuSecond = sl.parseCpuSample('cpu  200 0 200 1600 0 0 0 0 0 0');
check('cpu/second-usage', Math.round(sl.cpuPercent(cpuFirst.total, cpuFirst.idle, cpuSecond) * 1e6) / 1e6, 20);
check('cpu/short', sl.parseCpuSample('cpu 1 2 3'), null);

check('ram/fixture', sl.parseRamPercent('MemTotal: 1000 kB\nMemAvailable: 250 kB\n'), 75);
check('ram/missing-available', sl.parseRamPercent('MemTotal: 1000 kB\n'), 0);
check('ram/zero-total', sl.parseRamPercent('MemTotal: 0 kB\nMemAvailable: 0 kB\n'), 0);

check('ram-sample/fixture', sl.parseRamSample('MemTotal: 1000 kB\nMemAvailable: 250 kB\n'), { usedBytes: 750 * 1024, totalBytes: 1000 * 1024 });
check('ram-sample/missing', sl.parseRamSample('MemTotal: 1000 kB\n'), { usedBytes: 0, totalBytes: 0 });

check('percent/gpu', sl.parsePercent('37\n'), 37);
check('percent/clamp', sl.parsePercent('140'), 100);
check('percent/bad', sl.parsePercent('nope'), 0);

check('temp/edge', sl.parseTemp('48000\n'), 48);
check('temp/zero', sl.parseTemp('0'), 0);
check('temp/bad', sl.parseTemp('nope'), 0);

const NET_DEV = `Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000 10 0 0 0 0 0 0 2000 20 0 0 0 0 0 0
enp35s0: 5000 50 0 0 0 0 0 0 8000 80 0 0 0 0 0 0
docker0: 700 7 0 0 0 0 0 0 300 3 0 0 0 0 0 0
`;
const netFirst = sl.parseNetSample(NET_DEV);
check('net/sum', netFirst, { rx: 5700, tx: 8300 });
check('net/first-no-rate', sl.netRates(-1, -1, netFirst, 2), null);
const netSecond = sl.parseNetSample(NET_DEV.replace('5000', '6200').replace('8000', '8400'));
check('net/rates', sl.netRates(netFirst.rx, netFirst.tx, netSecond, 2), { rx: 600, tx: 200 });

check('format/gib-large', sl.formatGib(16 * 1024 ** 3), '16');
check('format/gib-small', sl.formatGib(6 * 1024 ** 3), '6.0');
check('format/rate-mb', sl.formatRate(1572864), '1.5 MB/s');
check('format/rate-kb', sl.formatRate(2048), '2 KB/s');
check('format/rate-b', sl.formatRate(700), '700 B/s');
NODEEOF

echo "dashboard-data: all ok"
