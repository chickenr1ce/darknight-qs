#!/usr/bin/env bash
# Headless gate for the dashboard live-data blocks (ticket 06).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# checks two things that run anywhere:
#   1. structural assertions over the QML: the fastfetch summary, the CPU
#      plus RAM poll, the per-sink volume list, and the player transport
#      each live in one service the dashboard composes;
#   2. python oracles mirroring the pure parsing plus mapping helpers
#      (fastfetch JSON, uptime format, /proc samples, MPRIS repeat cycle,
#      sink volume percent) at their boundary values. Each oracle cites
#      its QML source; change the source and update the mirror in the same
#      commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "dashboard-data FAIL: $*" >&2; exit 1; }

# --- 1. new services are registered and self-contained ---
for singleton in SystemInfo SystemMonitor AudioService SpotifyService; do
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
grep -q 'entry.type === "OS"' "$SINFO" \
    || fail "SystemInfo does not map the OS module"
grep -q 'entry.type === "WM"' "$SINFO" \
    || fail "SystemInfo does not map the WM module"
grep -q 'entry.type === "Kernel"' "$SINFO" \
    || fail "SystemInfo does not map the Kernel module"
grep -q 'entry.type === "Packages"' "$SINFO" \
    || fail "SystemInfo does not map the Packages module"
grep -q 'entry.type === "Uptime"' "$SINFO" \
    || fail "SystemInfo does not map the Uptime module"

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
ASVC="$ROOT/services/AudioService.qml"
grep -q 'Pipewire.nodes.values' "$ASVC" \
    || fail "AudioService does not enumerate pipewire nodes"
grep -q 'readonly property var catalog' "$ASVC" \
    || fail "AudioService has no shared output catalog"
grep -q 'function isSinkNode' "$ASVC" \
    || fail "AudioService has no isSinkNode filter"
grep -q 'function matchesCatalog' "$ASVC" \
    || fail "AudioService has no matchesCatalog"
grep -q 'function catalogLabelFor' "$ASVC" \
    || fail "AudioService has no catalogLabelFor"
grep -q 'function percentForVolume' "$ASVC" \
    || fail "AudioService has no percentForVolume"
grep -q 'function volumeForPercent' "$ASVC" \
    || fail "AudioService has no volumeForPercent"
grep -q 'function setVolume' "$ASVC" \
    || fail "AudioService has no setVolume"
grep -q 'node.isSink && !node.isStream' "$ASVC" \
    || fail "AudioService keeps streams or sources in the sink list"
grep -q 'AudioService.catalog' "$ROOT/modules/Audio.qml" \
    || fail "the bar Audio module keeps a second sink catalog"
if grep -q 'match: "JadeAudio"' "$ROOT/modules/Audio.qml"; then
    fail "the bar Audio module still hardcodes the sink catalog"
fi

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
grep -q 'ClippingRectangle' "$PBLOCK" \
    || fail "DashboardPlayerBlock does not clip the art to the card radius"
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

# Reading surfaces carry palette tokens only.
for surface in "$SINFO" "$SMON" "$ASVC" "$SBLOCK" "$CBLOCK" "$VBLOCK" "$PBLOCK"; do
    if grep -qnE '#[0-9a-fA-F]{3,8}' "$surface"; then
        fail "$(basename "$surface") carries raw hex; palette tokens only"
    fi
done

# --- 6. python oracles for the pure parsing plus mapping helpers ---
python3 - "$ROOT/tests/fixtures/fastfetch-summary.json" <<'EOF'
import json
import math
import sys

def check(name, got, want):
    if got != want:
        print(f"dashboard-data FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

def js_round(value):
    return math.floor(value + 0.5)

fixture = open(sys.argv[1]).read()

# Mirror of SystemInfo.parseFastfetch (services/SystemInfo.qml).
def parse_fastfetch(text):
    out = {"distro": "", "compositor": "", "kernel": "", "packages": 0, "uptimeMs": 0}
    try:
        parsed = json.loads(text)
    except Exception:
        return out
    if not isinstance(parsed, list):
        return out
    for entry in parsed:
        if not isinstance(entry, dict) or not entry.get("result"):
            continue
        result = entry["result"]
        if entry.get("type") == "OS":
            out["distro"] = result.get("prettyName") or result.get("name") or ""
        elif entry.get("type") == "WM":
            out["compositor"] = result.get("prettyName") or result.get("processName") or ""
        elif entry.get("type") == "Kernel":
            out["kernel"] = result.get("release") or ""
        elif entry.get("type") == "Packages":
            out["packages"] = int(result.get("all") or 0)
        elif entry.get("type") == "Uptime":
            out["uptimeMs"] = float(result.get("uptime") or 0)
    return out

parsed = parse_fastfetch(fixture)
check("fastfetch/fixture", parsed, {"distro": "Arch Linux", "compositor": "Hyprland", "kernel": "6.13.4-arch1-1", "packages": 942, "uptimeMs": 4980000.0})
check("fastfetch/malformed", parse_fastfetch("{nope"), {"distro": "", "compositor": "", "kernel": "", "packages": 0, "uptimeMs": 0})
check("fastfetch/not-list", parse_fastfetch('{"type": "OS"}'), {"distro": "", "compositor": "", "kernel": "", "packages": 0, "uptimeMs": 0})
check("fastfetch/missing-result", parse_fastfetch('[{"type": "WM"}]'), {"distro": "", "compositor": "", "kernel": "", "packages": 0, "uptimeMs": 0})
check("fastfetch/name-fallback", parse_fastfetch('[{"type": "OS", "result": {"name": "Fixtures"}}]')["distro"], "Fixtures")
check("fastfetch/process-fallback", parse_fastfetch('[{"type": "WM", "result": {"processName": "niri"}}]')["compositor"], "niri")
check("fastfetch/kernel", parse_fastfetch(fixture)["kernel"], "6.13.4-arch1-1")
check("fastfetch/packages-missing", parse_fastfetch('[{"type": "Packages", "result": {}}]')["packages"], 0)

# Mirror of SystemInfo.formatKernel (services/SystemInfo.qml). The release keeps
# its version up to the first dash; the distro suffix is dropped.
def format_kernel(release):
    if release == "":
        return ""
    return release.split("-", 1)[0]

check("kernel/dash-suffix", format_kernel("6.13.4-arch1-1"), "6.13.4")
check("kernel/cachy", format_kernel("7.2.8-1-cachyos"), "7.2.8")
check("kernel/bare", format_kernel("6.13.4"), "6.13.4")
check("kernel/empty", format_kernel(""), "")

# Mirror of SystemInfo.formatShell (services/SystemInfo.qml). The shell comes
# from $SHELL, so the value is the executable's basename.
def format_shell(path):
    if path == "":
        return ""
    return path.rsplit("/", 1)[-1]

check("shell/absolute", format_shell("/usr/bin/fish"), "fish")
check("shell/bin", format_shell("/bin/zsh"), "zsh")
check("shell/bare", format_shell("bash"), "bash")
check("shell/empty", format_shell(""), "")

# Mirror of SystemInfo.formatPackages (services/SystemInfo.qml). Counts under
# 1000 stay exact; larger counts collapse to one decimal and a k suffix.
def format_packages(count):
    if count <= 0:
        return ""
    if count < 1000:
        return f"{count}"
    return f"{count / 1000:.1f}k"

check("packages/fixture", format_packages(942), "942")
check("packages/zero", format_packages(0), "")
check("packages/thousand", format_packages(1000), "1.0k")
check("packages/rounded", format_packages(1819), "1.8k")

# Mirror of SystemInfo.formatUptime (services/SystemInfo.qml).
def format_uptime(ms):
    total = math.floor((ms or 0) / 60000)
    if total <= 0:
        return ""
    days = total // 1440
    hours = (total % 1440) // 60
    minutes = total % 60
    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"

check("uptime/fixture", format_uptime(4980000), "1h 23m")
check("uptime/zero", format_uptime(0), "")
check("uptime/minutes", format_uptime(45 * 60000), "45m")
check("uptime/days", format_uptime(93600000), "1d 2h")

# Mirror of SystemMonitor.parseCpuSample plus the delta in applyCpuSample
# (services/SystemMonitor.qml). idle includes iowait.
def parse_cpu_sample(text):
    lines = str(text).split("\n")
    if not lines:
        return None
    raw = lines[0].strip().split()[1:]
    fields = []
    for item in raw:
        try:
            fields.append(float(item))
        except ValueError:
            fields.append(float("nan"))
    if len(fields) < 4:
        return None
    total = sum(field for field in fields if not math.isnan(field))
    idle = fields[3] + (0 if len(fields) < 5 or math.isnan(fields[4]) else fields[4])
    return {"total": total, "idle": idle}

def cpu_usage(previous, sample):
    if sample is None:
        return None
    if previous is None:
        return None
    delta_total = sample["total"] - previous["total"]
    delta_idle = sample["idle"] - previous["idle"]
    if delta_total <= 0:
        return None
    return max(0.0, min(100.0, (1 - delta_idle / delta_total) * 100))

first = parse_cpu_sample("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3 4")
check("cpu/parse", first, {"total": 1000.0, "idle": 800.0})
check("cpu/first-no-usage", cpu_usage(None, first), None)
second = parse_cpu_sample("cpu  200 0 200 1600 0 0 0 0 0 0")
check("cpu/second-usage", round(cpu_usage(first, second), 6), 20.0)
check("cpu/short", parse_cpu_sample("cpu 1 2 3"), None)

# Mirror of SystemMonitor.parseRamPercent (services/SystemMonitor.qml).
def parse_ram_percent(text):
    total = 0
    available = -1
    for line in str(text).split("\n"):
        parts = line.split(":")
        if len(parts) < 2:
            continue
        key = parts[0].strip()
        try:
            value = int(parts[1].strip().split()[0])
        except ValueError:
            continue
        if key == "MemTotal":
            total = value
        elif key == "MemAvailable":
            available = value
    if total <= 0 or available < 0:
        return 0
    return max(0.0, min(100.0, (total - available) / total * 100))

check("ram/fixture", parse_ram_percent("MemTotal: 1000 kB\nMemAvailable: 250 kB\n"), 75.0)
check("ram/missing-available", parse_ram_percent("MemTotal: 1000 kB\n"), 0)
check("ram/zero-total", parse_ram_percent("MemTotal: 0 kB\nMemAvailable: 0 kB\n"), 0)

# Mirror of SystemMonitor.parseRamSample plus applyRamSample
# (services/SystemMonitor.qml): kB -> bytes, used = total - available.
def parse_ram_sample(text):
    total = 0
    available = -1
    for line in str(text).split("\n"):
        parts = line.split(":")
        if len(parts) < 2:
            continue
        key = parts[0].strip()
        try:
            value = int(parts[1].strip().split()[0])
        except ValueError:
            continue
        if key == "MemTotal":
            total = value
        elif key == "MemAvailable":
            available = value
    if total <= 0 or available < 0:
        return {"usedBytes": 0, "totalBytes": 0}
    return {"usedBytes": (total - available) * 1024, "totalBytes": total * 1024}

check("ram-sample/fixture", parse_ram_sample("MemTotal: 1000 kB\nMemAvailable: 250 kB\n"), {"usedBytes": 750 * 1024, "totalBytes": 1000 * 1024})
check("ram-sample/missing", parse_ram_sample("MemTotal: 1000 kB\n"), {"usedBytes": 0, "totalBytes": 0})

# Mirror of SystemMonitor.parsePercent (services/SystemMonitor.qml): the GPU
# busy percent is a plain integer in sysfs, clamped to 0..100.
def parse_percent(text):
    try:
        value = float(str(text).strip())
    except ValueError:
        return 0
    return max(0.0, min(100.0, value))

check("percent/gpu", parse_percent("37\n"), 37.0)
check("percent/clamp", parse_percent("140"), 100.0)
check("percent/bad", parse_percent("nope"), 0)

# Mirror of SystemMonitor.parseTemp (services/SystemMonitor.qml): hwmon temps
# arrive in millidegrees; a missing or non-positive value reads as 0.
def parse_temp(text):
    try:
        value = float(str(text).strip())
    except ValueError:
        return 0
    return value / 1000 if value > 0 else 0

check("temp/edge", parse_temp("48000\n"), 48.0)
check("temp/zero", parse_temp("0"), 0)
check("temp/bad", parse_temp("nope"), 0)

# Mirror of SystemMonitor.parseNetSample plus applyNetSample
# (services/SystemMonitor.qml): sum rx/tx bytes over every non-loopback
# interface, then divide the delta by the poll interval in seconds.
NET_DEV = """Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000 10 0 0 0 0 0 0 2000 20 0 0 0 0 0 0
enp35s0: 5000 50 0 0 0 0 0 0 8000 80 0 0 0 0 0 0
docker0: 700 7 0 0 0 0 0 0 300 3 0 0 0 0 0 0
"""

def parse_net_sample(text):
    rx = 0
    tx = 0
    for line in str(text).split("\n"):
        colon = line.find(":")
        if colon < 0:
            continue
        iface = line[:colon].strip()
        if iface == "" or iface == "lo":
            continue
        fields = line[colon + 1:].split()
        if len(fields) < 9:
            continue
        try:
            rx += int(fields[0])
            tx += int(fields[8])
        except ValueError:
            continue
    return {"rx": rx, "tx": tx}

def net_rates(previous, sample, seconds):
    if previous is None:
        return {"rx": 0.0, "tx": 0.0}
    return {"rx": max(0.0, (sample["rx"] - previous["rx"]) / seconds),
            "tx": max(0.0, (sample["tx"] - previous["tx"]) / seconds)}

net_first = parse_net_sample(NET_DEV)
check("net/sum", net_first, {"rx": 5700, "tx": 8300})
check("net/first-no-rate", net_rates(None, net_first, 2.0), {"rx": 0.0, "tx": 0.0})
net_second = parse_net_sample(NET_DEV.replace("5000", "6200").replace("8000", "8400"))
check("net/rates", net_rates(net_first, net_second, 2.0), {"rx": 600.0, "tx": 200.0})

# Mirror of SystemMonitor.formatGib plus formatRate (services/SystemMonitor.qml).
def format_gib(nbytes):
    gib = float(nbytes or 0) / (1024 ** 3)
    return str(round(gib)) if gib >= 10 else f"{gib:.1f}"

def format_rate(bps):
    value = float(bps or 0)
    if value >= 1024 * 1024:
        return f"{value / (1024 * 1024):.1f} MB/s"
    if value >= 1024:
        return f"{round(value / 1024)} KB/s"
    return f"{round(value)} B/s"

check("format/gib-large", format_gib(16 * 1024 ** 3), "16")
check("format/gib-small", format_gib(6 * 1024 ** 3), "6.0")
check("format/rate-mb", format_rate(1572864), "1.5 MB/s")
check("format/rate-kb", format_rate(2048), "2 KB/s")
check("format/rate-b", format_rate(700), "700 B/s")

# Mirror of AudioService sink selection (services/AudioService.qml): the one
# catalog drives both the bar cycle and the dashboard list. A node counts only
# when it is a real sink and its label matches a catalog entry; the result
# follows catalog order, so a physical HDMI or virtual filter sink never shows.
def is_sink_node(node):
    return bool(node) and node.get("isSink", False) and not node.get("isStream", False) and node.get("audio") is not None

def raw_label_for(node):
    if not node:
        return ""
    return node.get("description") or node.get("nickname") or node.get("name") or ""

def matches_catalog(node, entry):
    return entry["match"] in raw_label_for(node)

def catalog_label_for(node, catalog):
    for entry in catalog:
        if matches_catalog(node, entry):
            return entry["label"]
    return raw_label_for(node)

CATALOG = [
    {"match": "JadeAudio", "label": "JadeAudio JIEZI"},
    {"match": "AB13X", "label": "AB13X Dongle"},
    {"match": "Pebble", "label": "Creative Pebble V3"},
]

def selected_labels(nodes, catalog=CATALOG):
    out = []
    for entry in catalog:
        for node in nodes:
            if is_sink_node(node) and matches_catalog(node, entry):
                out.append(catalog_label_for(node, catalog))
                break
    return out

HDMI = {"isSink": True, "isStream": False, "audio": {}, "description": "Navi 48 HDMI/DP Audio Controller Digital Stereo (HDMI) [LG ULTRAGEAR]", "name": "alsa_output.pci-0000_28_00.1.hdmi-stereo"}
EASY = {"isSink": True, "isStream": False, "audio": {}, "description": "Easy Effects Sink", "name": "easyeffects_sink"}
JADE = {"isSink": True, "isStream": False, "audio": {}, "description": "JadeAudio JIEZI Analog Stereo"}
AB13X = {"isSink": True, "isStream": False, "audio": {}, "description": "AB13X Headset Adapter Analog Stereo"}
PEBBLE = {"isSink": True, "isStream": False, "audio": {}, "description": "Pebble V3 Analog Stereo"}

check("sink/real", is_sink_node({"isSink": True, "isStream": False, "audio": {}}), True)
check("sink/stream", is_sink_node({"isSink": True, "isStream": True, "audio": {}}), False)
check("sink/source", is_sink_node({"isSink": False, "isStream": False, "audio": {}}), False)
check("sink/no-audio", is_sink_node({"isSink": True, "isStream": False, "audio": None}), False)
check("sink/catalog-order", selected_labels([PEBBLE, AB13X, EASY, HDMI, JADE]), ["JadeAudio JIEZI", "AB13X Dongle", "Creative Pebble V3"])
check("sink/catalog-drops-unmatched", selected_labels([HDMI, EASY]), [])
check("sink/catalog-single", selected_labels([PEBBLE]), ["Creative Pebble V3"])
check("sink/catalog-first-match", selected_labels([JADE, {"isSink": True, "isStream": False, "audio": {}, "description": "JadeAudio JIEZI clone"}]), ["JadeAudio JIEZI"])
check("sink/matches-case", matches_catalog({"description": "jadeaudio jiezi"}, {"match": "JadeAudio"}), False)
check("sink/unmatched-label", catalog_label_for(HDMI, CATALOG), HDMI["description"])

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
# None(0) -> Track(1) -> Playlist(2) -> None.
def next_loop_state(current):
    if current == 1:
        return 2
    if current == 2:
        return 0
    return 1

check("repeat/none", next_loop_state(0), 1)
check("repeat/track", next_loop_state(1), 2)
check("repeat/playlist", next_loop_state(2), 0)
check("repeat/cycle", [next_loop_state(v) for v in (0, 1, 2)], [1, 2, 0])

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
EOF

echo "dashboard-data: all ok"
