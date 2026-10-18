#!/usr/bin/env bash
# Headless gate for the bar layout service, its parser, and its positioner.
#
# services/BarLayoutLogic.js and StateParsers.parseBarLayout run for real under
# node through tests/qmljs.js: move, positions, and dropTarget, plus the
# parser's every-key-once rule. Structural greps pin BarLayoutService to its
# delegates (parseBarLayout and BarLayoutLogic), the bar-layout state file, the
# bar IPC target, and the shell's plain-Item positioner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "bar-layout FAIL: $*" >&2; exit 1; }

LOGIC="$ROOT/services/BarLayoutLogic.js"
SVC="$ROOT/services/BarLayoutService.qml"
SLOT="$ROOT/components/BarSlot.qml"
SHELL="$ROOT/shell.qml"
PANELS="$ROOT/services/Panels.qml"

# --- 1. structure ---
test -f "$LOGIC" \
    || fail "services/BarLayoutLogic.js is missing"
grep -q '^\.pragma library' "$LOGIC" \
    || fail "BarLayoutLogic.js is not a .pragma library"
for fn in 'function move(' 'function positions(' 'function dropTarget('; do
    grep -q "$fn" "$LOGIC" \
        || fail "BarLayoutLogic.js does not define $fn"
done
for fn in 'function dragX(' 'function shouldCancelRelease('; do
    grep -q "$fn" "$LOGIC" \
        || fail "BarLayoutLogic.js does not define $fn"
done

test -f "$SVC" \
    || fail "services/BarLayoutService.qml is missing"
grep -q '^pragma Singleton' "$SVC" \
    || fail "BarLayoutService is not a singleton"
grep -q '^singleton BarLayoutService 1.0 BarLayoutService.qml' "$ROOT/services/qmldir" \
    || fail "BarLayoutService is not registered in services/qmldir"
grep -q '^import qs.services' "$SVC" \
    || fail "BarLayoutService is missing its qs.services self-import"
grep -q 'StateParsers.parseBarLayout' "$SVC" \
    || fail "BarLayoutService does not delegate parseBarLayout to StateParsers"
grep -q 'BarLayoutLogic.move' "$SVC" \
    || fail "BarLayoutService does not delegate move to BarLayoutLogic"
grep -q 'StateFile {' "$SVC" \
    || fail "BarLayoutService does not compose StateFile"
grep -q 'name: "bar-layout"' "$SVC" \
    || fail "BarLayoutService does not persist to the bar-layout state file"
grep -q 'createDir: true' "$SVC" \
    || fail "BarLayoutService does not create its state directory"
grep -q 'target: "bar"' "$SVC" \
    || fail "BarLayoutService has no bar IPC target"
for fn in 'function order(' 'function move(' 'function reset('; do
    grep -q "$fn" "$SVC" \
        || fail "BarLayoutService IPC misses $fn"
done
grep -q 'BarVisibilityService.modules' "$SVC" \
    || fail "BarLayoutService does not read the one module registry"

# The reset row lives in Settings → Layout, calls the one service, and reads
# the service's default-order flag to disable itself.
BVIEW="$ROOT/windows/LayoutSettingsView.qml"
test -f "$BVIEW" \
    || fail "windows/LayoutSettingsView.qml is missing"
grep -q 'BarLayoutService.reset' "$BVIEW" \
    || fail "LayoutSettingsView does not reset the bar order through BarLayoutService"
grep -q 'BarLayoutService.isDefaultOrder' "$BVIEW" \
    || fail "LayoutSettingsView does not disable the reset row at the default order"
grep -q 'readonly property bool isDefaultOrder' "$SVC" \
    || fail "BarLayoutService exposes no isDefaultOrder flag"
grep -q 'BarLayoutLogic.sameOrder' "$SVC" \
    || fail "isDefaultOrder does not compare through BarLayoutLogic.sameOrder"

test -f "$PANELS" \
    || fail "services/Panels.qml is missing"
grep -q 'function closeAll(' "$PANELS" \
    || fail "Panels does not close its whole registry"
grep -q 'Panels.closeAll' "$SVC" \
    || fail "a committed drop does not close every panel through Panels.closeAll"
grep -q 'TrayMenuService.dismiss' "$SVC" \
    || fail "a committed drop does not dismiss the tray menu"
for fn in 'function beginDrag(' 'function updateDrag(' 'function endDrag(' 'function cancelDrag('; do
    grep -q "$fn" "$SVC" \
        || fail "BarLayoutService misses $fn"
done

test -f "$SLOT" \
    || fail "components/BarSlot.qml is missing"
grep -q 'id: idHoldTimer' "$SLOT" \
    || fail "BarSlot has no hold timer"
if grep -q 'TapHandler {' "$SLOT"; then
    fail "BarSlot carries a TapHandler; a handler above the module starves its MouseArea"
fi
grep -q 'DragHandler {' "$SLOT" \
    || fail "BarSlot has no drag handler"
grep -q 'property int barDragHoldMs: 300' "$ROOT/config/Globals.qml" \
    || fail "config/Globals.qml has no barDragHoldMs token"
grep -q 'property real barDragLiftScale: 1.05' "$ROOT/config/Globals.qml" \
    || fail "config/Globals.qml has no barDragLiftScale token"

test -f "$SLOT" \
    || fail "components/BarSlot.qml is missing"
grep -q 'Behavior on x' "$SLOT" \
    || fail "BarSlot does not animate x"
grep -q 'Globals.barReorderMs' "$SLOT" \
    || fail "BarSlot does not read Globals.barReorderMs"
grep -q 'property int barReorderMs: 160' "$ROOT/config/Globals.qml" \
    || fail "config/Globals.qml has no barReorderMs token"

grep -q 'BarSlot {' "$SHELL" \
    || fail "shell.qml does not place the modules in a BarSlot"
grep -q 'BarLayoutLogic.positions' "$SHELL" \
    || fail "shell.qml does not position through BarLayoutLogic.positions"
if grep -q 'idBarLayout\|idSpacer' "$SHELL"; then
    fail "shell.qml still carries the removed RowLayout or spacer"
fi
if grep -qnE 'RowLayout|\bRepeater\b' "$SHELL"; then
    fail "shell.qml places the modules with a positioner or Repeater; BarSlot keeps plain Items"
fi

# --- 2. the parser and the pure logic run for real under node ---
node - "$ROOT/tests/qmljs.js" "$ROOT/services/StateParsers.js" "$LOGIC" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('bar-layout');
const sp = qmljs.load(process.argv[3]);
const bl = qmljs.load(process.argv[4]);

const KEYS = ['clock', 'workspaces', 'tray', 'cava', 'media', 'audio', 'notifications', 'power'];
const DEFAULTS = {
    left: ['clock', 'workspaces', 'tray'],
    right: ['cava', 'media', 'audio', 'notifications', 'power']
};
const defaults = () => ({ left: DEFAULTS.left.slice(), right: DEFAULTS.right.slice() });
const parse = text => sp.parseBarLayout(text, KEYS, defaults());

// Every-key-once: malformed input, a non-object, an unknown key, a repeat in
// one section, a repeat across sections, and a missing key at its default index.
check('layout/empty', parse(''), DEFAULTS);
check('layout/malformed', parse('{nope'), DEFAULTS);
check('layout/null', parse('null'), DEFAULTS);
check('layout/number', parse('5'), DEFAULTS);
check('layout/array', parse('[1, 2]'), DEFAULTS);
check('layout/non-array-sections', parse('{"left": "nope", "right": 3}'), DEFAULTS);
check('layout/custom-kept',
      parse('{"left": ["tray", "clock", "workspaces"], "right": ["power", "cava", "media", "audio", "notifications"]}'),
      { left: ['tray', 'clock', 'workspaces'], right: ['power', 'cava', 'media', 'audio', 'notifications'] });
check('layout/unknown-dropped',
      parse('{"left": ["ghost", "tray", "clock"], "right": ["cava", "media", "audio", "notifications", "power"]}'),
      { left: ['tray', 'workspaces', 'clock'], right: DEFAULTS.right });
check('layout/repeat-one-section',
      parse('{"left": ["clock", "clock", "workspaces", "tray"], "right": ["cava", "media", "audio", "notifications", "power"]}'),
      DEFAULTS);
check('layout/repeat-across-sections',
      parse('{"left": ["power", "clock", "workspaces", "tray"], "right": ["cava", "media", "audio", "notifications", "power"]}'),
      { left: ['power', 'clock', 'workspaces', 'tray'], right: ['cava', 'media', 'audio', 'notifications'] });
check('layout/missing-default-index',
      parse('{"left": ["tray", "clock"], "right": ["cava", "media", "audio", "notifications", "power"]}'),
      { left: ['tray', 'workspaces', 'clock'], right: DEFAULTS.right });
check('layout/missing-clamped',
      parse('{"left": ["workspaces"], "right": ["cava", "media", "audio", "notifications", "power"]}'),
      DEFAULTS);

// A fixed set of widths for the geometry checks; spacing 10, slab width 1000.
const W = { clock: 60, workspaces: 100, tray: 40, cava: 50, media: 200, audio: 60, notifications: 30, power: 40 };
const ALL = {};
const SPACING = 10;
const WIDTH = 1000;

// Default order reproduces today's RowLayout offsets: the left cluster packs
// from the left inset, the right cluster from the right edge.
const base = bl.positions(defaults(), W, ALL, SPACING, WIDTH);
check('positions/left-offsets', base.x,
      { clock: 0, workspaces: 70, tray: 180, cava: 580, media: 640, audio: 850, notifications: 920, power: 960 });
check('positions/left-end', base.leftEnd, 230);
check('positions/right-start', base.rightStart, 570);

// A hidden key takes no x and no spacing: the right cluster closes over it.
const hidden = bl.positions(defaults(), W, { media: false }, SPACING, WIDTH);
check('positions/hidden-no-x', hidden.x.media, undefined);
check('positions/hidden-closes-gap',
      { cava: hidden.x.cava, audio: hidden.x.audio, notifications: hidden.x.notifications, power: hidden.x.power },
      { cava: 790, audio: 850, notifications: 920, power: 960 });
check('positions/hidden-right-start', hidden.rightStart, 780);

// An empty section yields nothing on that side; leftEnd sits at the left inset
// (0) and rightStart at the right edge (the slab width).
const emptyLeft = bl.positions({ left: [], right: DEFAULTS.right }, W, ALL, SPACING, WIDTH);
check('positions/empty-left-end', emptyLeft.leftEnd, 0);
check('positions/empty-left-no-x', emptyLeft.x.clock, undefined);
const emptyRight = bl.positions({ left: DEFAULTS.left, right: [] }, W, ALL, SPACING, WIDTH);
check('positions/empty-right-start', emptyRight.rightStart, 1000);
check('positions/empty-right-no-x', emptyRight.x.cava, undefined);

// move: within a section, to index 0 and the end, across sections, onto its own
// slot, and the input stays untouched.
check('move/within', bl.move(defaults(), 'tray', 'left', 0),
      { left: ['tray', 'clock', 'workspaces'], right: DEFAULTS.right });
check('move/to-end', bl.move(defaults(), 'clock', 'left', 9),
      { left: ['workspaces', 'tray', 'clock'], right: DEFAULTS.right });
check('move/across-to-front', bl.move(defaults(), 'power', 'left', 0),
      { left: ['power', 'clock', 'workspaces', 'tray'], right: ['cava', 'media', 'audio', 'notifications'] });
check('move/across-to-end', bl.move(defaults(), 'clock', 'right', 99),
      { left: ['workspaces', 'tray'], right: ['cava', 'media', 'audio', 'notifications', 'power', 'clock'] });
check('move/same-slot', bl.move(defaults(), 'media', 'right', 1), DEFAULTS);
check('move/negative-clamps', bl.move(defaults(), 'clock', 'right', -5),
      { left: ['workspaces', 'tray'], right: ['clock', 'cava', 'media', 'audio', 'notifications', 'power'] });
check('move/unknown-section', bl.move(defaults(), 'clock', 'center', 0), DEFAULTS);
const untouched = defaults();
bl.move(untouched, 'power', 'left', 0);
check('move/pure', untouched, DEFAULTS);

// sameOrder drives the reset row's disabled state: the defaults equal
// themselves, any reorder or cross-section move differs, and a shorter list
// differs.
check('same/default', bl.sameOrder(defaults(), defaults()), true);
check('same/same-custom', bl.sameOrder({ left: ['tray', 'clock', 'workspaces'], right: DEFAULTS.right.slice() },
      { left: ['tray', 'clock', 'workspaces'], right: DEFAULTS.right.slice() }), true);
check('same/reordered', bl.sameOrder(defaults(), { left: ['clock', 'tray', 'workspaces'], right: DEFAULTS.right.slice() }), false);
check('same/short-list', bl.sameOrder(defaults(), { left: ['clock', 'workspaces'], right: DEFAULTS.right.slice() }), false);
check('same/cross-section', bl.sameOrder(defaults(), bl.move(defaults(), 'power', 'left', 0)), false);

// dropTarget: the slot whose neighbours' midpoints bracket the pointer, in the
// section the pointer's side of the slab center names. Dropping onto a module's
// own slot then committing leaves the order unchanged.
const drop = (key, x) => bl.dropTarget(defaults(), W, ALL, SPACING, WIDTH, key, x);
check('drop/within-section', drop('media', 870), { section: 'right', index: 1 });
check('drop/to-front', drop('media', 600), { section: 'right', index: 0 });
check('drop/to-end', drop('media', 990), { section: 'right', index: 4 });
check('drop/past-center-switches', drop('power', 400), { section: 'left', index: 3 });
check('drop/left-index', drop('power', 100), { section: 'left', index: 1 });
check('drop/center-is-right', drop('media', 500), { section: 'right', index: 0 });
const own = drop('media', 740);
check('drop/own-slot', own, { section: 'right', index: 1 });
check('drop/own-slot-commits-unchanged', bl.move(defaults(), 'media', own.section, own.index), DEFAULTS);
// A key in neither section is not inserted; a missing width counts as 0, not NaN.
check('move/ghost-key', bl.move(defaults(), 'ghost', 'left', 0), DEFAULTS);
const noPowerWidth = Object.assign({}, W);
delete noPowerWidth.power;
check('positions/missing-width', bl.positions(defaults(), noPowerWidth, ALL, SPACING, WIDTH).rightStart, 610);

// Hidden keys count toward the index without taking space; a key dragged in from
// the other section lands between the bracketing midpoints.
const dropHidden = bl.dropTarget(defaults(), W, { media: false }, SPACING, WIDTH, 'audio', 855);
check('drop/hidden-neighbour', dropHidden, { section: 'right', index: 2 });
check('drop/hidden-commits-unchanged', bl.move(defaults(), 'audio', dropHidden.section, dropHidden.index), DEFAULTS);
check('drop/cross-section-dragged', drop('clock', 800), { section: 'right', index: 2 });
check('drop/cross-section-commit', bl.move(defaults(), 'clock', 'right', 2),
      { left: ['workspaces', 'tray'], right: ['cava', 'media', 'clock', 'audio', 'notifications', 'power'] });

// dragX keeps the module's center under the pointer, clamped to the bar.
check('drag/follow', bl.dragX(500, 100, 1000), 450);
check('drag/clamp-start', bl.dragX(20, 100, 1000), 0);
check('drag/clamp-end', bl.dragX(990, 100, 1000), 900);
check('drag/wider-than-bar', bl.dragX(10, 1200, 1000), 0);
// A release more than a bar height below the bar cancels; nearer commits.
check('cancel/inside-bar', bl.shouldCancelRelease(16, 28, 4), false);
check('cancel/at-threshold', bl.shouldCancelRelease(60, 28, 4), false);
check('cancel/below-bar', bl.shouldCancelRelease(61, 28, 4), true);
NODEEOF

PREVIEW="$ROOT/components/BarDropPreview.qml"
test -f "$PREVIEW" \
    || fail "components/BarDropPreview.qml is missing"
grep -q 'BarDropPreview {' "$ROOT/shell.qml" \
    || fail "shell.qml does not place the drop preview"
grep -q 'property bool tracking' "$PREVIEW" \
    || fail "the drop preview lost its tracking gate, so it would slide in from a stale x"
grep -q 'armedSlot' "$ROOT/shell.qml" \
    || fail "shell.qml does not key the drop preview on the armed slot"
grep -q 'readonly property bool wouldCancel' "$SVC" \
    || fail "BarLayoutService has no wouldCancel preview state"
grep -q '!root.wouldCancel' "$SVC" \
    || fail "previewOrder does not fall back to the committed order in the cancel zone"

QMLTESTRUNNER="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
HANDLER_TEST="$ROOT/tests/bar-slot-handlers.qml"
if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "bar-layout: qmltestrunner not found, skipping the offscreen handler test" >&2
else
    HANDLER_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -input "$HANDLER_TEST" >"$HANDLER_OUT" 2>&1; then
        rm -f "$HANDLER_OUT"
    else
        cat "$HANDLER_OUT" >&2
        rm -f "$HANDLER_OUT"
        fail "the offscreen slot handler test failed"
    fi
fi

echo "bar-layout: all ok"
