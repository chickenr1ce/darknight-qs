#!/usr/bin/env bash
# Headless gate for the dashboard Performance tab: the singleton registry, node
# runs of the shipped services/PerformanceLogic.js and the /proc parsers it
# records from in services/SystemLogic.js through tests/qmljs.js, and the
# offscreen qmltestrunner suite that drives the real view with synthetic pointer
# events.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "performance FAIL: $*" >&2; exit 1; }

grep -q '^singleton PerformanceHistory 1.0 PerformanceHistory.qml' "$ROOT/services/qmldir" \
    || fail "PerformanceHistory is not registered in services/qmldir"

node - "$ROOT/tests/qmljs.js" "$ROOT/services/PerformanceLogic.js" "$ROOT/services/SystemLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('performance');
const logic = qmljs.load(process.argv[3]);
const system = qmljs.load(process.argv[4]);

function sample(value) {
  const out = {};
  for (const key of ['cpu', 'cpuPeak', 'cpuTemp', 'gpu', 'gpuTemp', 'ram', 'ramUsed', 'diskRead', 'diskWrite', 'netRx', 'netTx'])
    out[key] = value;
  return out;
}

function ringsOf(values) {
  let rings = logic.emptyRings();
  for (const value of values)
    rings = logic.appendSample(rings, sample(value), values.length);
  return rings;
}

// appendSample: bounded, oldest first, and a new object so bindings refresh.
const empty = logic.emptyRings();
const one = logic.appendSample(empty, sample(5), 3);
check('append/new object', one === empty, false);
check('append/input untouched', empty.cpu.length, 0);
let full = one;
for (const value of [6, 7, 8])
  full = logic.appendSample(full, sample(value), 3);
check('append/capacity', JSON.stringify(full.cpu), '[6,7,8]');
check('append/every key', JSON.stringify(full.netTx), '[6,7,8]');
check('append/junk reads 0', logic.appendSample(empty, {}, 3).gpu[0], 0);

// windowSamples: the oldest sample sits exactly the window behind the newest.
check('window/5m at 2s', logic.windowSamples(300, 2), 151);
check('window/1m at 2s', logic.windowSamples(60, 2), 31);

// readingAt and hasSampleAt: age 0 is the newest; beyond the history is empty.
const rings = ringsOf([10, 20, 30]);
check('reading/newest', logic.readingAt(rings, 0).cpu, 30);
check('reading/oldest', logic.readingAt(rings, 2).netRx, 10);
check('reading/too old', logic.readingAt(rings, 3).cpu, 0);
check('reading/no pointer', logic.readingAt(rings, -1).cpu, 0);
check('reading/empty', logic.readingAt(empty, 0).ram, 0);
check('has/newest', logic.hasSampleAt(rings, 0), true);
check('has/too old', logic.hasSampleAt(rings, 3), false);
check('has/no pointer', logic.hasSampleAt(rings, -1), false);

// windowPeak: only the visible window, across every series named.
const spiky = logic.emptyRings();
spiky.diskRead = [900, 1, 2];
spiky.diskWrite = [3, 40, 5];
check('peak/whole window', logic.windowPeak(spiky, ['diskRead', 'diskWrite'], 3), 900);
check('peak/old spike left the window', logic.windowPeak(spiky, ['diskRead', 'diskWrite'], 2), 40);
check('peak/empty', logic.windowPeak(empty, ['netRx'], 3), 0);
check('scale/floor', logic.autoScale(10, 100), 100);
check('scale/headroom', Math.round(logic.autoScale(1000, 100)), 1100);

// scrubAge: left edge oldest, right edge newest, a stray overshoot clamps.
check('scrub/no pointer', logic.scrubAge(-1, 151), -1);
check('scrub/left edge', logic.scrubAge(0, 151), 150);
check('scrub/right edge', logic.scrubAge(1, 151), 0);
check('scrub/middle', logic.scrubAge(0.5, 151), 75);
check('scrub/overshoot', logic.scrubAge(1.01, 151), 0);

check('ago/now', logic.agoText(0), 'now');
check('ago/seconds', logic.agoText(48), '-48s');
check('ago/minute', logic.agoText(60), '-1m');
check('ago/mixed', logic.agoText(150), '-2m 30s');

check('temp/hidden when unreadable', logic.tempText(0), '');
check('temp/plain', logic.tempText(74.4), '74°C');
check('temp/warm boundary', logic.tempText(75), 'Warm 75°C');
check('temp/hot boundary', logic.tempText(85), 'Hot 85°C');
check('level/normal', logic.tempLevel(74.9), 'normal');
check('level/warning', logic.tempLevel(84.9), 'warning');
check('level/danger', logic.tempLevel(85), 'danger');

// peakThreadPercent: the busiest thread, not the average line.
const stat0 = 'cpu  100 0 0 900 0 0 0 0 0 0\ncpu0 50 0 0 450 0 0 0 0 0 0\ncpu1 50 0 0 450 0 0 0 0 0 0\nintr 1\n';
const stat1 = 'cpu  190 0 0 1010 0 0 0 0 0 0\ncpu0 140 0 0 460 0 0 0 0 0 0\ncpu1 50 0 0 550 0 0 0 0 0 0\nintr 2\n';
const threads0 = system.parseThreadSamples(stat0);
const threads1 = system.parseThreadSamples(stat1);
check('threads/skips the average and other lines', Object.keys(threads0).join(), 'cpu0,cpu1');
check('threads/fields', threads0.cpu0.total, 500);
check('peak thread/no previous', system.peakThreadPercent({}, threads1), null);
check('peak thread/busiest', system.peakThreadPercent(threads0, threads1), 90);
const offline = system.parseThreadSamples('cpu1 50 0 0 550 0 0 0 0 0 0\n');
check('peak thread/offline thread skipped', system.peakThreadPercent(threads0, offline), 0);

// parseDiskSample: whole disks only, in bytes; a partition would double count.
const diskstats = [
  ' 259 0 nvme0n1 10 0 100 0 20 0 200 0 0 0 0',
  ' 259 1 nvme0n1p1 10 0 100 0 20 0 200 0 0 0 0',
  '   8 0 sda 1 0 10 0 2 0 20 0 0 0 0',
  '   8 1 sda1 1 0 10 0 2 0 20 0 0 0 0',
  ' 179 0 mmcblk0 1 0 1 0 1 0 1 0 0 0 0',
  ' 179 1 mmcblk0p1 1 0 1 0 1 0 1 0 0 0 0',
  ' 202 0 xvda 1 0 1000 0 1 0 1000 0 0 0 0',
  ' 202 1 xvda1 1 0 1000 0 1 0 1000 0 0 0 0',
  ' 254 0 dm-0 1 0 500 0 1 0 500 0 0 0 0',
  '   7 0 loop0 1 0 500 0 1 0 500 0 0 0 0',
  ' 253 0 zram0 1 0 500 0 1 0 500 0 0 0 0',
  'short line'
].join('\n');
const disk = system.parseDiskSample(diskstats);
check('disk/read bytes', disk.read, 1111 * 512);
check('disk/written bytes', disk.written, 1221 * 512);
check('disk/empty', system.parseDiskSample('').read, 0);

check('rate/no previous', system.byteRate(-1, 500, 2), null);
check('rate/per second', system.byteRate(100, 500, 2), 200);
check('rate/counter reset', system.byteRate(500, 100, 2), 0);
NODEEOF

QMLTESTRUNNER="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "performance: qmltestrunner not found, skipping the offscreen view test" >&2
else
    VIEW_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -import "$ROOT/tests/fixtures/performance" -input "$ROOT/tests/performance-view.qml" >"$VIEW_OUT" 2>&1; then
        rm -f "$VIEW_OUT"
    else
        cat "$VIEW_OUT" >&2
        rm -f "$VIEW_OUT"
        fail "the offscreen view test failed"
    fi
fi

echo "performance: ok"
