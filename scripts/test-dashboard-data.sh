#!/usr/bin/env bash
# Headless gate for the dashboard live-data blocks (ticket 06).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# checks two things that run anywhere:
#   1. structural assertions over the QML: the fastfetch summary, the CPU
#      plus RAM poll, the per-sink volume list, the player transport, and
#      the Open-Meteo weather fetch each live in one service the dashboard
#      composes;
#   2. node runs of the shipped pure parsing plus mapping helpers
#      (fastfetch JSON, uptime format, /proc samples, MPRIS repeat cycle,
#      sink volume percent, Open-Meteo JSON, temperature plus rain format,
#      WMO code mapping, weather staleness). These load the real
#      *Logic.js / *Parsers.js modules through tests/qmljs.js, so a change
#      to the source is exercised directly; no mirror to keep in step.
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
grep -q 'import "SystemLogic.js" as SystemLogic' "$SINFO" \
    || fail "SystemInfo does not import SystemLogic.js"
grep -q 'SystemLogic.parseFastfetch' "$SINFO" \
    || fail "SystemInfo.parseFastfetch does not delegate to SystemLogic"
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
grep -q 'import "SystemLogic.js" as SystemLogic' "$SMON" \
    || fail "SystemMonitor does not import SystemLogic.js"
grep -q 'SystemLogic.parseCpuSample' "$SMON" \
    || fail "SystemMonitor.parseCpuSample does not delegate to SystemLogic"
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
grep -q 'AudioLogic.isSinkNode' "$ASVC" \
    || fail "AudioService does not delegate the sink filter to AudioLogic"
grep -q 'import "AudioLogic.js" as AudioLogic' "$ASVC" \
    || fail "AudioService does not import AudioLogic.js"
grep -q 'AudioLogic.percentForVolume' "$ASVC" \
    || fail "AudioService does not convert volume through AudioLogic"
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
grep -q 'import "MprisLogic.js" as MprisLogic' "$MPLAYERS" \
    || fail "MprisPlayers does not import MprisLogic.js"
grep -q 'MprisLogic.playerKey' "$MPLAYERS" \
    || fail "MprisPlayers.playerKey does not delegate to MprisLogic"
grep -q 'MprisLogic.nextLoopState' "$MPLAYERS" \
    || fail "MprisPlayers.nextLoopState does not delegate to MprisLogic"
grep -q 'if (!player || !player.shuffleSupported)' "$MPLAYERS" \
    || fail "MprisPlayers shuffles an unsupported player"
grep -q 'const BROWSER_TOKENS' "$ROOT/services/MprisLogic.js" \
    || fail "MprisLogic does not seed the browsers as hidden"
grep -q 'Mpris.players.values.filter' "$MPLAYERS" \
    || fail "MprisPlayers playerList does not filter by the app filter"

node - "$ROOT/tests/qmljs.js" "$ROOT/services/MprisLogic.js" <<'NODEEOF'
// MprisLogic.playerKey lowercases and drops a .instance suffix;
// defaultAllowed hides the browser seed by exact token or substring;
// parseApps reads the persisted app map; sameApps compares label plus allowed;
// mergeApps keeps in-memory entries the file does not know; formatTime renders
// m:ss clamped at zero; nextLoopState cycles None -> Playlist -> Track -> None.
const qmljs = require(process.argv[2]);
const check = qmljs.checker('dashboard-data');
const mpris = qmljs.load(process.argv[3]);

const STATES = { None: 0, Track: 1, Playlist: 2 };
const key = (desktopEntry, identity, dbusName) => mpris.playerKey({ desktopEntry, identity, dbusName });
check('filter/key-desktop', key('Spotify', 'Spotify', ''), 'spotify');
check('filter/key-identity', key('', 'Mozilla firefox', ''), 'mozilla firefox');
check('filter/key-instance', key('', '', 'org.mpris.MediaPlayer2.firefox.instance_1_50'), 'org.mpris.mediaplayer2.firefox');
check('filter/key-null', mpris.playerKey(null), '');

check('filter/spotify', mpris.defaultAllowed('spotify'), true);
check('filter/firefox', mpris.defaultAllowed('firefox'), false);
check('filter/firefox-identity', mpris.defaultAllowed('mozilla firefox'), false);
check('filter/zen', mpris.defaultAllowed('zen'), false);
check('filter/zen-partial', mpris.defaultAllowed('citizen'), true);
check('filter/vlc', mpris.defaultAllowed('vlc'), true);

check('filter/parse-malformed', mpris.parseApps('{ not json'), {});
check('filter/parse-empty', mpris.parseApps('{"apps": {}}'), {});
check('filter/parse-label-fallback',
      mpris.parseApps('{"apps": {"firefox": {"allowed": false}}}')["firefox"],
      { label: 'firefox', allowed: false });
check('filter/parse-strict-allowed',
      mpris.parseApps('{"apps": {"vlc": {"label": "VLC", "allowed": 0}}}')["vlc"]["allowed"], true);
check('filter/merge-keeps-current',
      Object.keys(mpris.mergeApps(
          mpris.parseApps('{"apps": {"firefox": {"label": "Mozilla firefox", "allowed": false}}}'),
          { spotify: { label: 'Spotify', allowed: true } })).sort(),
      ['firefox', 'spotify']);
check('filter/merge-stored-wins',
      mpris.mergeApps(
          mpris.parseApps('{"apps": {"firefox": {"label": "Mozilla firefox", "allowed": false}}}'),
          { firefox: { label: 'old', allowed: true } })["firefox"]["allowed"],
      false);
check('filter/same-apps', mpris.sameApps({ a: { label: 'A', allowed: true } }, { a: { label: 'A', allowed: 1 } }), true);
check('filter/same-apps-allowed', mpris.sameApps({ a: { label: 'A', allowed: false } }, { a: { label: 'A', allowed: true } }), false);
check('filter/same-apps-label', mpris.sameApps({ a: { label: 'A', allowed: true } }, { a: { label: 'B', allowed: true } }), false);
check('filter/same-apps-keys', mpris.sameApps({ a: { label: 'A', allowed: true } }, {}), false);

check('repeat/none', mpris.nextLoopState(0, STATES), 2);
check('repeat/playlist', mpris.nextLoopState(2, STATES), 1);
check('repeat/track', mpris.nextLoopState(1, STATES), 0);
check('repeat/cycle', [0, 2, 1].map(v => mpris.nextLoopState(v, STATES)), [2, 1, 0]);

check('time/zero', mpris.formatTime(0), '0:00');
check('time/seconds', mpris.formatTime(74), '1:14');
check('time/pad', mpris.formatTime(65), '1:05');
check('time/negative', mpris.formatTime(-5), '0:00');
check('time/long', mpris.formatTime(3725), '62:05');
NODEEOF

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
grep -q 'import "SpotifyLogic.js" as SpotifyLogic' "$SSVC" \
    || fail "SpotifyService does not import SpotifyLogic.js"
grep -q 'SpotifyLogic.parseResponse(text)' "$SSVC" \
    || fail "SpotifyService.parseResponse does not delegate to SpotifyLogic"
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
WLOGIC="$ROOT/services/WeatherLogic.js"
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
grep -q 'current.temperature_2m' "$WLOGIC" \
    || fail "WeatherLogic does not map the current temperature"
grep -q 'current.weather_code' "$WLOGIC" \
    || fail "WeatherLogic does not map the weather code"
grep -q 'precipitation_probability_max' "$WLOGIC" \
    || fail "WeatherLogic does not map the rain probability"
grep -q 'temperature_2m_max' "$WLOGIC" \
    || fail "WeatherLogic does not map the daily high"
grep -q 'temperature_2m_min' "$WLOGIC" \
    || fail "WeatherLogic does not map the daily low"
grep -q 'import "WeatherLogic.js" as WeatherLogic' "$WSVC" \
    || fail "WeatherService does not import WeatherLogic.js"
grep -q 'Icons\[WeatherLogic.glyphKeyFor' "$WSVC" \
    || fail "WeatherService.glyphFor does not map through WeatherLogic.glyphKeyFor"
grep -q 'WeatherLogic.isStale(nowMs, fetchedAtMs, failed, root.staleAfterMs)' "$WSVC" \
    || fail "WeatherService.isStale does not pass the service stale threshold"
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

# AudioLogic mirrors the AudioService discovery pipeline: every real sink
# (isSink, not a stream, non-null audio) is discovered, then a saved order
# puts known keys first and the rest sort by label; hidden keys drop out.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/AudioLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('dashboard-data');
const al = qmljs.load(process.argv[3]);

const HDMI = { isSink: true, isStream: false, audio: {}, description: 'Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI) [LG ULTRAGEAR]', name: 'alsa_output.pci-0000_28_00.1.hdmi-stereo' };
const EASY = { isSink: true, isStream: false, audio: {}, description: 'Easy Effects Sink', name: 'easyeffects_sink' };
const JADE = { isSink: true, isStream: false, audio: {}, description: 'JadeAudio JIEZI Analog Stereo', name: 'alsa_output.usb-JadeAudio_JIEZI-00.analog-stereo' };
const PEBBLE = { isSink: true, isStream: false, audio: {}, description: 'Pebble V3 Analog Stereo', name: 'alsa_output.usb-Creative_Pebble_V3-00.analog-stereo' };

check('sink/real', al.isSinkNode({ isSink: true, isStream: false, audio: {} }), true);
check('sink/stream', al.isSinkNode({ isSink: true, isStream: true, audio: {} }), false);
check('sink/source', al.isSinkNode({ isSink: false, isStream: false, audio: {} }), false);
check('sink/no-audio', al.isSinkNode({ isSink: true, isStream: false, audio: null }), false);
check('sink/no-flag', al.isSinkNode({ audio: {} }), false);
check('sink/key-prefers-name', al.keyFor(PEBBLE), PEBBLE.name);
check('sink/key-falls-back', al.keyFor({ description: 'Fallback', id: 7 }), 'Fallback');

// The service composes discovery + ordering + the hidden filter into sinks.
function visibleSinks(nodes, hidden, order) {
    hidden = hidden || [];
    order = order || [];
    const out = [];
    const ordered = al.orderedNodes(nodes.filter(al.isSinkNode), order);
    for (let i = 0; i < ordered.length; i++) {
        const key = al.keyFor(ordered[i]);
        if (hidden.indexOf(key) !== -1)
            continue;
        out.push({ key: key, label: al.rawLabelFor(ordered[i]) });
    }
    return out;
}
check('sink/discover-all', visibleSinks([PEBBLE, HDMI, JADE]).map(s => s.label), [JADE.description, HDMI.description, PEBBLE.description]);
check('sink/hidden-drops', visibleSinks([JADE, EASY, PEBBLE], [al.keyFor(EASY)]).map(s => s.key), [al.keyFor(JADE), al.keyFor(PEBBLE)]);
check('sink/saved-order', visibleSinks([JADE, PEBBLE, HDMI], [], [al.keyFor(PEBBLE), al.keyFor(JADE)]).map(s => s.key), [al.keyFor(PEBBLE), al.keyFor(JADE), al.keyFor(HDMI)]);
check('sink/drops-non-sinks', visibleSinks([{ isSink: false, isStream: false, audio: {}, name: 'mic' }]), []);

check('volume/round-half-up', al.percentForVolume(0.555), 56);
check('volume/clamp-high', al.percentForVolume(1.4), 100);
check('volume/clamp-low', al.percentForVolume(-0.2), 0);
check('volume/nan', al.percentForVolume('nope'), 0);
check('volume/percent-clamp', al.volumeForPercent(140), 1.0);
check('volume/percent-low', al.volumeForPercent(-10), 0.0);
check('volume/round-trip', al.percentForVolume(al.volumeForPercent(55)), 55);
NODEEOF

# --- 7b. weather plus spotify pure logic: node runs of the shipped modules ---
# WeatherService and SpotifyService delegate to WeatherLogic.js and
# SpotifyLogic.js; the real modules load under node through tests/qmljs.js,
# so these cases fail on broken shipped code instead of a Python copy.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/WeatherLogic.js" "$ROOT/services/SpotifyLogic.js" "$ROOT/tests/fixtures/open-meteo-forecast.json" <<'NODEEOF'
const fs = require('fs');
const qmljs = require(process.argv[2]);
const check = qmljs.checker('dashboard-data');
const wl = qmljs.load(process.argv[3]);
const sp = qmljs.load(process.argv[4]);

const weatherFixture = fs.readFileSync(process.argv[5], 'utf8');
check('weather/fixture', wl.parseWeather(weatherFixture),
      { temperatureC: 15.2, weatherCode: 2, precipProb: 10.0, highC: 19.1, lowC: 11.3 });
check('weather/malformed', wl.parseWeather('{nope'), null);
check('weather/not-object', wl.parseWeather('[1, 2]'), null);
check('weather/missing-current', wl.parseWeather('{"daily": {}}'), null);
check('weather/bad-temp', wl.parseWeather('{"current": {"temperature_2m": "warm", "weather_code": 2}}'), null);
check('weather/bad-code', wl.parseWeather('{"current": {"temperature_2m": 15.2}}'), null);
check('weather/no-daily', wl.parseWeather('{"current": {"temperature_2m": 15.2, "weather_code": 0}}'),
      { temperatureC: 15.2, weatherCode: 0, precipProb: -1, highC: 15.2, lowC: 15.2 });

check('temp/fixture', wl.formatTemp(15.2), '15°');
check('temp/rounds', wl.formatTemp(-2.6), '-3°');
check('temp/rounds-up', wl.formatTemp(15.7), '16°');
check('temp/zero', wl.formatTemp(0), '0°');
check('temp/missing', wl.formatTemp(NaN), '');

check('precip/fixture', wl.formatPrecip(10), '10%');
check('precip/zero', wl.formatPrecip(0), '0%');
check('precip/clamp', wl.formatPrecip(140), '100%');
check('precip/unknown', wl.formatPrecip(-1), '');
check('precip/bad', wl.formatPrecip('damp'), '');

check('glyph/clear', wl.glyphKeyFor(0), 'weatherSunny');
check('glyph/mainly-clear', wl.glyphKeyFor(1), 'weatherSunny');
check('glyph/partly-cloudy', wl.glyphKeyFor(2), 'weatherCloudy');
check('glyph/overcast', wl.glyphKeyFor(3), 'weatherCloudy');
check('glyph/fog', wl.glyphKeyFor(45), 'weatherFog');
check('glyph/rime-fog', wl.glyphKeyFor(48), 'weatherFog');
check('glyph/drizzle', wl.glyphKeyFor(53), 'weatherRainy');
check('glyph/rain', wl.glyphKeyFor(63), 'weatherRainy');
check('glyph/showers', wl.glyphKeyFor(81), 'weatherRainy');
check('glyph/snow', wl.glyphKeyFor(73), 'weatherSnowy');
check('glyph/snow-showers', wl.glyphKeyFor(85), 'weatherSnowy');
check('glyph/storm', wl.glyphKeyFor(95), 'weatherStorm');
check('glyph/hail-storm', wl.glyphKeyFor(99), 'weatherStorm');
check('glyph/missing', wl.glyphKeyFor(-1), 'weatherSunny');

const STALE_AFTER_MS = 60 * 60 * 1000;
const NOW = 1800000000000;
check('stale/failed', wl.isStale(NOW, NOW, true, STALE_AFTER_MS), true);
check('stale/never', wl.isStale(NOW, 0, false, STALE_AFTER_MS), false);
check('stale/fresh', wl.isStale(NOW, NOW - 30 * 60 * 1000, false, STALE_AFTER_MS), false);
check('stale/old', wl.isStale(NOW, NOW - 61 * 60 * 1000, false, STALE_AFTER_MS), true);

const ok = sp.parseResponse('{"ok": true, "activeId": "d1", "devices": [{"id": "d1", "name": "PC"}]}');
check('spotify/ok', ok.ok, true);
check('spotify/devices', ok.devices, [{ id: 'd1', name: 'PC' }]);
check('spotify/active', ok.activeId, 'd1');
check('spotify/auth-missing', sp.parseResponse('{"ok": false, "error": "auth_missing"}').error, 'auth_missing');
check('spotify/garbage', sp.parseResponse('{nope').ok, false);
check('spotify/devices-not-list', sp.parseResponse('{"ok": true, "devices": "x"}').devices, []);
check('spotify/null', sp.parseResponse('null').ok, false);
check('spotify/truthy-not-true', sp.parseResponse('{"ok": 1}').ok, false);
NODEEOF

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
