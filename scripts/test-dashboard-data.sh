#!/usr/bin/env bash
# Headless gate for the dashboard live-data blocks (ticket 06).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# keeps the checks that lint and boot-check cannot make, and drops the ones
# that only restated implementation text (property names, function bodies,
# call counts, literal values). What remains:
#   1. structural boundaries: the service registry, the pure-logic imports,
#      the forbidden subprocess and token reads, the persisted file names, and
#      the palette boundary;
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

# --- 2. the summary delegates parsing to its pure logic modules ---
SINFO="$ROOT/services/SystemInfo.qml"
grep -q 'import "SystemLogic.js" as SystemLogic' "$SINFO" \
    || fail "SystemInfo does not import SystemLogic.js"
grep -q 'import "DistroLogic.js" as DistroLogic' "$SINFO" \
    || fail "SystemInfo does not import DistroLogic.js"
ICONS="$ROOT/config/Icons.qml"
if grep -q 'readonly property string distro:' "$ICONS"; then
    fail "Icons.qml still defines distro; the distro glyph comes from SystemInfo.distroGlyph"
fi

SBLOCK="$ROOT/windows/DashboardSystemBlock.qml"

# --- 2b. the theme block never applies the background itself ---
# ThemeService owns the awww call, so the block must not reach for it.
TBLOCK="$ROOT/windows/DashboardThemeBlock.qml"
if grep -q 'awww' "$TBLOCK"; then
    fail "DashboardThemeBlock applies the background itself; ThemeService owns the awww call"
fi

# --- 3. CPU plus RAM poll procfs, no subprocess ---
SMON="$ROOT/services/SystemMonitor.qml"
grep -q 'import "SystemLogic.js" as SystemLogic' "$SMON" \
    || fail "SystemMonitor does not import SystemLogic.js"
if grep -q 'Process' "$SMON"; then
    fail "SystemMonitor spawns a process; procfs reads stay in-process"
fi

CBLOCK="$ROOT/windows/DashboardCpuBlock.qml"

# --- 4. per-sink volume list extends the audio seam ---
# Outputs are discovered from pipewire at runtime, then curated through a
# persisted order and hidden set. No hardware allowlist.
ASVC="$ROOT/services/AudioService.qml"
grep -q 'import "AudioLogic.js" as AudioLogic' "$ASVC" \
    || fail "AudioService does not import AudioLogic.js"
grep -q 'name: "audio-outputs"' "$ASVC" \
    || fail "AudioService does not persist curated outputs behind a StateFile"
if grep -q 'match: "JadeAudio"\|match: "AB13X"\|match: "Pebble"' "$ASVC" "$ROOT/modules/Audio.qml"; then
    fail "AudioService or the bar Audio module still hardcodes a sink catalog"
fi
if grep -qE 'audio\.volume *=' "$ROOT/modules/Audio.qml"; then
    fail "the bar Audio module still carries the inline wheel math"
fi

# --- 5. the player app filter persists and its mapping lives in MprisLogic.js ---
MPLAYERS="$ROOT/services/MprisPlayers.qml"
grep -q 'name: "mpris-players"' "$MPLAYERS" \
    || fail "MprisPlayers does not persist the app filter"
grep -q 'import "MprisLogic.js" as MprisLogic' "$MPLAYERS" \
    || fail "MprisPlayers does not import MprisLogic.js"

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

SSVC="$ROOT/services/SpotifyService.qml"
grep -q 'import "SpotifyLogic.js" as SpotifyLogic' "$SSVC" \
    || fail "SpotifyService does not import SpotifyLogic.js"
if grep -q 'access_token' "$SSVC"; then
    fail "SpotifyService must not read the token; the backend owns it"
fi

# --- 6. weather fetch rides Open-Meteo with a last-good cache plus stale ---
WSVC="$ROOT/services/WeatherService.qml"
grep -q 'name: "weather.json"' "$WSVC" \
    || fail "WeatherService does not persist a weather.json cache"
grep -q 'import "WeatherLogic.js" as WeatherLogic' "$WSVC" \
    || fail "WeatherService does not import WeatherLogic.js"
grep -q '^import qs.services' "$WSVC" \
    || fail "WeatherService.qml is missing its qs.services self-import"
grep -q 'name: "weather-location"' "$WSVC" \
    || fail "WeatherService does not persist the city"
if grep -q 'Process' "$ROOT/windows/DashboardWeatherBlock.qml"; then
    fail "DashboardWeatherBlock spawns a process; the service owns the fetch"
fi

# Reading surfaces carry palette tokens only.
VBLOCK="$ROOT/windows/DashboardVolumeBlock.qml"
PBLOCK="$ROOT/windows/DashboardPlayerBlock.qml"
WBLOCK="$ROOT/windows/DashboardWeatherBlock.qml"
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

check('step/up-47', al.stepPercent(47, 1, 5), 50);
check('step/up-50', al.stepPercent(50, 1, 5), 55);
check('step/up-100', al.stepPercent(100, 1, 5), 100);
check('step/up-120', al.stepPercent(120, 1, 5), 120);
check('step/down-53', al.stepPercent(53, -1, 5), 50);
check('step/down-50', al.stepPercent(50, -1, 5), 45);
check('step/down-3', al.stepPercent(3, -1, 5), 0);
check('step/down-0', al.stepPercent(0, -1, 5), 0);
check('step/down-120', al.stepPercent(120, -1, 5), 115);
check('step/nan', al.stepPercent(NaN, 1, 5), 5);
check('step/zero', al.stepPercent(42, 0, 5), 42);
check('step/round-first', al.stepPercent(47.6, 1, 5), 50);

// statusText reports the raw rounded percent for the IPC readout: it is not
// clamped to 100 (amplified sinks read 120), NaN reads 0, and muted wins.
check('status/percent', al.statusText(0.55, false), '55');
check('status/round-half-up', al.statusText(0.555, false), '56');
check('status/over-100', al.statusText(1.2, false), '120');
check('status/zero', al.statusText(0, false), '0');
check('status/nan', al.statusText('nope', false), '0');
check('status/muted', al.statusText(0.55, true), 'muted');
check('status/muted-wins', al.statusText('nope', true), 'muted');

// percentText is the OSD's raw readout: same rounding as statusText without the
// mute branch, so an amplified sink still reads its real number.
check('percent/basic', al.percentText(0.55), '55');
check('percent/round-half-up', al.percentText(0.555), '56');
check('percent/over-100', al.percentText(1.2), '120');
check('percent/zero', al.percentText(0), '0');
check('percent/nan', al.percentText('nope'), '0');

// volumeFraction is the level-bar fill: clamped to 0..1, NaN reads empty.
check('fraction/mid', al.volumeFraction(0.55), 0.55);
check('fraction/full', al.volumeFraction(1), 1);
check('fraction/clamp-high', al.volumeFraction(1.4), 1);
check('fraction/clamp-low', al.volumeFraction(-0.2), 0);
check('fraction/nan', al.volumeFraction('nope'), 0);
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

# services/DistroLogic.js: os-release parsing and the ID -> glyph table. The
# table rows are read from the source so each glyph is checked against the
# U+ codepoint in its comment; the expected mapping is typed out here.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/DistroLogic.js" "$ROOT/tests/fixtures/os-release-cachyos" "$ROOT/tests/fixtures/os-release-ubuntu" "$ROOT/tests/fixtures/os-release-bazzite" <<'NODEEOF'
const fs = require('fs');
const qmljs = require(process.argv[2]);
const check = qmljs.checker('dashboard-data');
const dl = qmljs.load(process.argv[3]);
const glyph = (hex) => String.fromCodePoint(parseInt(hex, 16));
const TUX = 'F31A';

const EXPECTED = 'arch:F303 cachyos:F385 endeavouros:F322 manjaro:F312 garuda:F337 artix:F31F arcolinux:F346 archcraft:F345 archlabs:F31E parabola:F340 hyperbola:F33A biglinux:F347 debian:F306 ubuntu:F31B pop:F32A linuxmint:F30E elementary:F309 zorin:F32F kali:F327 parrot:F329 raspbian:F315 deepin:F321 mx:F33F devuan:F307 tails:F343 trisquel:F344 postmarketos:F374 fedora:F30A nobara:F380 rhel:F316 centos:F304 rocky:F32B almalinux:F31D opensuse-tumbleweed:F37D opensuse-leap:F37E opensuse:F314 suse:F314 nixos:F313 gentoo:F30D void:F32E alpine:F300 slackware:F318 solus:F32D guix:F325 qubes:F342 mageia:F310 openwrt:F382 freebsd:F30C openbsd:F328';

const source = fs.readFileSync(process.argv[3], 'utf8');
const rows = [...source.matchAll(/^\s+"([a-z0-9-]+)": "(.)",?\s+\/\/ nf-linux-\S+ U\+([0-9A-F]{4})$/gm)].map((m) => ({
    id: m[1],
    hex: m[2].codePointAt(0).toString(16).toUpperCase(),
    comment: m[3],
}));
const fallback = source.match(/^const DISTRO_FALLBACK_GLYPH = "(.)";\s+\/\/ nf-linux-tux U\+([0-9A-F]{4})$/m);

check('table/rows', rows.map((r) => `${r.id}:${r.hex}`).join(' '), EXPECTED);
check('table/comment-matches-glyph', rows.filter((r) => r.hex !== r.comment).map((r) => r.id), []);
check('table/pua-range', rows.filter((r) => { const c = parseInt(r.hex, 16); return c < 0xF300 || c > 0xF385; }).map((r) => r.id), []);
const tableBody = source.slice(source.indexOf('const DISTRO_GLYPHS'), source.indexOf('\n};'));
check('table/every-line-parsed', rows.length, tableBody.split('\n').filter((l) => /^\s+"/.test(l)).length);
check('table/fallback-codepoint', fallback ? fallback[2] : null, TUX);
check('table/fallback-glyph', fallback ? fallback[1].codePointAt(0).toString(16).toUpperCase() : null, TUX);
for (const pair of EXPECTED.split(' ')) {
    const [id, hex] = pair.split(':');
    check(`map/${id}`, dl.distroGlyph(id, []), glyph(hex));
}

check('parse/empty', dl.parseOsRelease(''), { id: '', idLike: [], prettyName: '' });
check('parse/garbage', dl.parseOsRelease('this is not os-release\n\n====\n=x\n'), { id: '', idLike: [], prettyName: '' });
check('parse/unquoted', dl.parseOsRelease('ID=arch\nID_LIKE=\nPRETTY_NAME=Arch'), { id: 'arch', idLike: [], prettyName: 'Arch' });
check('parse/double-quoted', dl.parseOsRelease('ID="fedora"\nID_LIKE="rhel centos"\nPRETTY_NAME="Fedora Linux 41"'), { id: 'fedora', idLike: ['rhel', 'centos'], prettyName: 'Fedora Linux 41' });
check('parse/single-quoted', dl.parseOsRelease("PRETTY_NAME='Pop!_OS 22.04'\nID='pop'"), { id: 'pop', idLike: [], prettyName: 'Pop!_OS 22.04' });
check('parse/single-quote-literal', dl.parseOsRelease(String.raw`PRETTY_NAME='a\"b\\c'`).prettyName, String.raw`a\"b\\c`);
check('parse/double-escapes', dl.parseOsRelease('PRETTY_NAME="a \\"b\\" \\\\ \\$c \\`d\\`"').prettyName, 'a "b" \\ $c `d`');
check('parse/id-lowercased', dl.parseOsRelease('ID=CachyOS\nID_LIKE="Ubuntu DEBIAN"'), { id: 'cachyos', idLike: ['ubuntu', 'debian'], prettyName: '' });
check('parse/crlf', dl.parseOsRelease('ID=cachyos\r\nID_LIKE=arch\r\nPRETTY_NAME="CachyOS Linux"\r\n'), { id: 'cachyos', idLike: ['arch'], prettyName: 'CachyOS Linux' });
check('parse/comments-blank', dl.parseOsRelease('# generated\n\n   \nID=arch\n# ID=ignored\nPRETTY_NAME="Arch Linux"\n'), { id: 'arch', idLike: [], prettyName: 'Arch Linux' });
check('parse/equals-in-value', dl.parseOsRelease('PRETTY_NAME=a=b').prettyName, 'a=b');
check('fixture/cachyos', dl.parseOsRelease(fs.readFileSync(process.argv[4], 'utf8')), { id: 'cachyos', idLike: ['arch'], prettyName: 'CachyOS Linux' });
check('fixture/ubuntu', dl.parseOsRelease(fs.readFileSync(process.argv[5], 'utf8')), { id: 'ubuntu', idLike: ['debian'], prettyName: 'Ubuntu 24.04.1 LTS' });
const bazzite = dl.parseOsRelease(fs.readFileSync(process.argv[6], 'utf8'));
check('fixture/bazzite', bazzite, { id: 'bazzite', idLike: ['fedora'], prettyName: 'Bazzite (Kinoite)' });
check('fixture/bazzite-glyph', dl.distroGlyph(bazzite.id, bazzite.idLike), glyph('F30A'));

check('glyph/bazzite-idlike', dl.distroGlyph('bazzite', ['fedora']), glyph('F30A'));
check('glyph/steamos-arch', dl.distroGlyph('steamos', ['arch']), glyph('F303'));
check('glyph/sles-idlike-suse', dl.distroGlyph('sles', ['suse']), glyph('F314'));
check('glyph/linuxmint-before-ubuntu', dl.distroGlyph('linuxmint', ['ubuntu', 'debian']), glyph('F30E'));
check('glyph/exact-beats-idlike', dl.distroGlyph('ubuntu', ['debian']), glyph('F31B'));
check('glyph/idlike-left-to-right', dl.distroGlyph('nonesuch', ['unknown', 'debian', 'arch']), glyph('F306'));
check('glyph/idlike-string', dl.distroGlyph('bazzite', 'fedora'), glyph('F30A'));
check('glyph/case-insensitive', dl.distroGlyph('CachyOS', ['Arch']), glyph('F385'));
check('glyph/unknown-tux', dl.distroGlyph('templeos', []), glyph(TUX));
check('glyph/empty-tux', dl.distroGlyph('', []), glyph(TUX));
check('glyph/undefined-tux', dl.distroGlyph(undefined, undefined), glyph(TUX));
check('glyph/unknown-idlike-tux', dl.distroGlyph('templeos', ['also-unknown']), glyph(TUX));
check('glyph/prototype-constructor', dl.distroGlyph('constructor', []), glyph(TUX));
check('glyph/prototype-idlike', dl.distroGlyph('toString', ['__proto__', 'hasOwnProperty']), glyph(TUX));
check('glyph/prototype-id-falls-to-idlike', dl.distroGlyph('constructor', ['arch']), glyph('F303'));
NODEEOF

echo "dashboard-data: all ok"
