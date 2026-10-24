#!/usr/bin/env bash
# Headless gate for the dashboard Workspaces tab (tickets 01-03).
#
# A full QML boot needs a compositor, so this gate does not boot one. It keeps
# the checks lint and boot-check cannot make:
#   1. structural boundaries: the pure-logic seam, the singleton registry, the
#      forbidden dashboardWidth dependency, the forbidden legacy workspace
#      dispatcher, and the window menu's input-mask wiring (structure rules, so
#      greps are allowed);
#   2. node runs of the shipped services/WorkspaceLogic.js through
#      tests/qmljs.js: the coordinate normalization, the tile-size math, the
#      per-monitor tile model (state, ordering, urgency, captions, special
#      exclusion), the block membership test, the block builder, the whole
#      model assembly from a plain snapshot (enabled monitors, block
#      membership, fullscreen mode, urgency, class and title normalisation,
#      focused flags), the window selector, the drop hit test and move
#      decision, and the window menu (order, state labels, move targets,
#      action table).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "workspaces FAIL: $*" >&2; exit 1; }

LOGIC="$ROOT/services/WorkspaceLogic.js"
SVC="$ROOT/services/WorkspaceService.qml"
VIEW="$ROOT/windows/DashboardWorkspacesView.qml"

# --- 1. structure ---
test -f "$LOGIC" \
    || fail "services/WorkspaceLogic.js is missing"
grep -q '^\.pragma library' "$LOGIC" \
    || fail "WorkspaceLogic.js is not a .pragma library"
grep -q '^import "WorkspaceLogic.js" as WorkspaceLogic' "$SVC" \
    || fail "WorkspaceService does not import WorkspaceLogic.js"
grep -q '^singleton WorkspaceService 1.0 WorkspaceService.qml' "$ROOT/services/qmldir" \
    || fail "WorkspaceService is not registered in services/qmldir"
test -f "$VIEW" \
    || fail "windows/DashboardWorkspacesView.qml is missing"

# The card reads its own width from layout; the dashboard width is a forbidden
# dependency (tiles shrink to whatever the card gives them).
if grep -qn 'Globals\.dashboardWidth' "$VIEW"; then
    fail "DashboardWorkspacesView reads Globals.dashboardWidth; it must size to its own layout"
fi

# Hyprland >= 0.56 evaluates IPC as Lua; a legacy dispatcher string fails.
# These are the names a move/float/fullscreen/close would be written with when
# handed to the dispatch seam; the socket event list legitimately contains event
# names like "closewindow", so the pattern is scoped to a dispatch()/send()
# argument.
LEGACY_DISPATCH='(dispatch|send)\([^)]*(movetoworkspace(silent)?|togglefloating|fullscreen [0-9]|closewindow|killactive)'
if grep -nE "$LEGACY_DISPATCH" "$SVC" "$VIEW"; then
    fail "a legacy Hyprland dispatcher string is forbidden; use the hl.dsp.* Lua API"
fi

# --- 1b. the window menu (ticket 03) ---
grep -q 'readonly property Item menuInputBox: idWorkspacesContextMenu.inputBox' "$VIEW" \
    || fail "DashboardWorkspacesView does not expose its menu input box"
grep -q 'WorkspaceService.runMenuItem(' "$VIEW" \
    || fail "DashboardWorkspacesView does not dispatch its menu through WorkspaceService.runMenuItem"
grep -q 'idDashboardWorkspacesView.menuInputBox' "$ROOT/windows/DashboardCenter.qml" \
    || fail "the Workspaces window menu is not in the dashboard input mask"
grep -q 'activeTab === "workspaces"' "$ROOT/windows/DashboardCenter.qml" \
    || fail "the dashboard input mask does not switch by active tab"

# --- 2. the pure logic runs under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$SVC" <<'NODEEOF'
const fs = require('fs');
const qmljs = require(process.argv[2]);
const check = qmljs.checker('workspaces');
const ws = qmljs.load(process.argv[3]);
const svcSrc = fs.readFileSync(process.argv[4], 'utf8');

function close(name, got, want, eps) {
  const tolerance = eps === undefined ? 1e-9 : eps;
  if (Math.abs(got - want) > tolerance) {
    console.error('workspaces FAIL: ' + name + ': got ' + got + ', want ' + want);
    process.exit(1);
  }
}

function checkRect(name, got, want) {
  close(name + '/x', got.x, want.x);
  close(name + '/y', got.y, want.y);
  close(name + '/width', got.width, want.width);
  close(name + '/height', got.height, want.height);
}

// relativeRect: fraction of the monitor's logical size, clamped to the unit
// square. Logical size divides by scale and swaps the axes for a 90/270-degree
// transform; the origin is subtracted first.
const scaled = { x: 0, y: 0, width: 2560, height: 1440, scale: 1.25, transform: 0 };
checkRect('rect/scale', ws.relativeRect([256, 144], [256, 144], scaled),
      { x: 0.125, y: 0.125, width: 0.125, height: 0.125 });

const rotated = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 };
checkRect('rect/rotate', ws.relativeRect([270, 480], [540, 960], rotated),
      { x: 0.25, y: 0.25, width: 0.5, height: 0.5 });

const offset = { x: 2560, y: 0, width: 2560, height: 1440, scale: 1, transform: 0 };
checkRect('rect/origin', ws.relativeRect([2816, 144], [256, 144], offset),
      { x: 0.1, y: 0.1, width: 0.1, height: 0.1 });

const plain = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0 };
checkRect('rect/clamp-negative', ws.relativeRect([-96, -54], [384, 216], plain),
      { x: 0, y: 0, width: 0.15, height: 0.15 });
checkRect('rect/clamp-overflow', ws.relativeRect([1800, 0], [240, 100], plain),
      { x: 0.9375, y: 0, width: 0.0625, height: 100 / 1080 });
checkRect('rect/off-monitor', ws.relativeRect([2500, 0], [200, 100], plain),
      { x: 1, y: 0, width: 0, height: 100 / 1080 });
checkRect('rect/no-size', ws.relativeRect([0, 0], [100, 100],
      { x: 0, y: 0, width: 0, height: 0, scale: 1, transform: 0 }),
      { x: 0, y: 0, width: 0, height: 0 });

// tileWidth: n tiles and n-1 gaps fill the view width exactly.
const five = ws.tileWidth(696, 5, 8);
close('tile/one-of-five', five, 132.8);
close('tile/sum-fills-view', five * 5 + 8 * 4, 696);
close('tile/single', ws.tileWidth(100, 1, 8), 100);
check('tile/no-tiles', ws.tileWidth(100, 0, 8), 0);

// monitorTiles: current is the focused monitor's active workspace, shown is
// active on another monitor, and the rest are normal.
const monA = { name: 'DP-1', x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0, activeId: 2 };
const monB = { name: 'DP-2', x: 1920, y: 0, width: 1920, height: 1080, scale: 1, transform: 0, activeId: 7 };
const actives = [2, 7];
function win(address, cls, workspaceId, extra) {
  const base = {
    address: address, cls: cls, title: cls + ' window',
    at: [0, 0], size: [960, 1080],
    floating: false, fullscreen: false, urgent: false, workspaceId: workspaceId
  };
  return Object.assign(base, extra || {});
}
const windows = [
  win('aaa', 'kitty', 2),
  win('bbb', 'firefox', 3),
  win('ccc', 'code', 7),
  win('sss', 'scratch', -99)
];
const tilesA = ws.monitorTiles(monA, 1, 5, windows, actives, 'DP-1', 'aaa');
check('tiles/ids', tilesA.map(t => t.id), [1, 2, 3, 4, 5]);
check('tiles/states-a', tilesA.map(t => t.state), ['normal', 'current', 'normal', 'normal', 'normal']);
check('tiles/windows-a', tilesA[1].windows.map(w => w.cls), ['kitty']);
check('tiles/focused', tilesA[1].windows[0].focused, true);
// Real IPC shape: `at` and `size` are arrays, and the window fills the left half.
check('tiles/window-rect', tilesA[1].windows[0].rect, { x: 0, y: 0, width: 0.5, height: 1 });
check('tiles/caption-a', tilesA[1].caption, 'kitty');
check('tiles/caption-firefox', tilesA[2].caption, 'firefox');
check('tiles/empty', tilesA[0].empty, true);
check('tiles/caption-empty', tilesA[0].caption, 'Empty');
check('tiles/no-special', tilesA.every(t => t.windows.every(w => w.cls !== 'scratch')), true);

const tilesB = ws.monitorTiles(monB, 6, 5, windows, actives, 'DP-1', 'aaa');
check('tiles/ids-b', tilesB.map(t => t.id), [6, 7, 8, 9, 10]);
check('tiles/states-b', tilesB.map(t => t.state), ['normal', 'shown', 'normal', 'normal', 'normal']);
check('tiles/caption-b', tilesB[1].caption, 'code');

const tilesFocusedB = ws.monitorTiles(monB, 6, 5, windows, actives, 'DP-2', 'aaa');
check('tiles/current-on-second', tilesFocusedB[1].state, 'current');
check('tiles/all-normal',
      ws.monitorTiles(monA, 1, 5, windows, [], 'DP-2', '').map(t => t.state),
      ['normal', 'normal', 'normal', 'normal', 'normal']);

// An urgent window raises the tile flag and keeps its own.
const urgentTiles = ws.monitorTiles(monA, 1, 5, [win('ddd', 'discord', 1, { urgent: true })],
    actives, 'DP-1', '');
check('tiles/urgent', urgentTiles[0].urgent, true);
check('tiles/urgent-window', urgentTiles[0].windows[0].urgent, true);
check('tiles/not-urgent', urgentTiles[1].urgent, false);

// Floating windows sort after tiled ones and fullscreen windows last.
const ordered = ws.monitorTiles(monA, 1, 5, [
  win('t1', 'tile-a', 4),
  win('f1', 'float', 4, { floating: true }),
  win('fs1', 'full', 4, { fullscreen: true }),
  win('t2', 'tile-b', 4)
], actives, 'DP-1', '');
check('tiles/order', ordered[3].windows.map(w => w.address), ['t1', 't2', 'f1', 'fs1']);
check('tiles/order-flags', ordered[3].windows.map(w => [w.floating, w.fullscreen]),
      [[false, false], [false, false], [true, false], [false, true]]);

// The icon the service resolved for a window's class is carried through.
const iconTiles = ws.monitorTiles(monA, 1, 5, [win('iii', 'kitty', 2, { icon: '/icons/kitty.png' })],
    actives, 'DP-1', '');
check('tiles/icon', iconTiles[1].windows[0].icon, '/icons/kitty.png');
check('tiles/icon-absent', tilesA[1].windows[0].icon, '');

// monitorBlocks is the service's model builder: one entry per enabled monitor,
// its first workspace, and a full row of tiles from there.
const built = ws.monitorBlocks([{ monitor: monA, first: 1 }, { monitor: monB, first: 6 }], 5,
    windows, actives, 'DP-1', 'aaa');
check('blocks/monitors', built.map(b => b.monitor.name), ['DP-1', 'DP-2']);
check('blocks/tile-ids', built.map(b => b.tiles.map(t => t.id)), [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]);
check('blocks/current', built[0].tiles[1].state, 'current');
check('blocks/no-entries', ws.monitorBlocks([], 5, windows, actives, 'DP-1', ''), []);

// model: the whole assembly from one plain snapshot. A disabled monitor and a
// window outside every block drop out, a toplevel with no IPC snapshot yet is
// skipped, the class is normalised, the title falls back, and the fullscreen
// mode rule, urgency, floating, focus, and the array-shaped geometry all land.
function snapMon(name, x, activeId, focused) {
  return {
    name: name, x: x, y: 0, width: 1920, height: 1080, scale: 1, transform: 0,
    logicalWidth: 1920, logicalHeight: 1080, activeId: activeId, focused: focused === true
  };
}
function snapTop(address, cls, workspaceId, extra) {
  const top = {
    address: address,
    title: address + ' fallback',
    urgent: false,
    app: cls ? cls + '-app' : '',
    icon: cls ? '/icons/' + cls + '.png' : '',
    ipc: {
      class: cls,
      title: address + ' ipc',
      workspace: { id: workspaceId },
      at: [0, 0], size: [960, 1080],
      floating: false, fullscreen: 0
    }
  };
  const over = extra || {};
  if (over.top)
    Object.assign(top, over.top);
  if (over.ipc)
    Object.assign(top.ipc, over.ipc);
  return top;
}
const snapshot = {
  monitorNames: ['DP-1', 'DP-2', 'HDMI-A-1', 'eDP-9'],
  enabledNames: ['DP-1', 'DP-2', 'eDP-9'],
  monitors: [
    snapMon('DP-1', 0, 2, true),
    snapMon('DP-2', 1920, 7, false),
    snapMon('HDMI-A-1', 3840, 12, false)
  ],
  firstWorkspace: { 'DP-1': 1, 'DP-2': 6, 'HDMI-A-1': 11, 'eDP-9': 1 },
  perMonitor: 5,
  toplevels: [
    snapTop('aaa', 'kitty', 2),
    snapTop('bbb', 'firefox', 3, { ipc: { at: [960, 0], title: 'Mozilla' } }),
    snapTop('ccc', 'code', 7),
    snapTop('ddd', 'discord', 1, { top: { urgent: true } }),
    snapTop('fff', 'float', 3, { ipc: { floating: true } }),
    snapTop('f0', 'full0', 4),
    snapTop('f1', 'full1', 4, { ipc: { fullscreen: 1 } }),
    snapTop('f2', 'full2', 4, { ipc: { fullscreen: 2 } }),
    snapTop('f3', 'full3', 4, { ipc: { fullscreen: 3 } }),
    snapTop('ft', 'fullt', 4, { ipc: { fullscreen: true } }),
    snapTop('nul', null, 3),
    snapTop('und', 'und', 3, { ipc: { class: undefined } }),
    snapTop('noti', 'noti', 3, { ipc: { title: undefined } }),
    snapTop('dis', 'hdmi', 12),
    snapTop('out', 'outside', 99),
    { address: 'noipc', title: 'no ipc', urgent: false, app: '', icon: '', ipc: undefined },
    null
  ],
  workspaces: [
    { id: 2, active: true },
    { id: 7, active: true },
    { id: 9, active: true },
    { id: 3, active: false },
    null
  ],
  focusedName: 'DP-1',
  focusedAddress: 'aaa'
};

function modelWindow(m, address) {
  for (let i = 0; i < m.length; i++)
    for (let k = 0; k < m[i].tiles.length; k++) {
      const windows = m[i].tiles[k].windows;
      for (let j = 0; j < windows.length; j++) {
        if (windows[j].address === address)
          return windows[j];
      }
    }
  return null;
}

const builtModel = ws.model(snapshot);
check('model/monitors', builtModel.map(b => b.monitor.name), ['DP-1', 'DP-2']);
check('model/tile-ids', builtModel.map(b => b.tiles.map(t => t.id)),
      [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]);
check('model/monitor-focused', builtModel.map(b => b.monitor.focused), [true, false]);
check('model/disabled-monitor-excluded', modelWindow(builtModel, 'dis'), null);
check('model/outside-block-excluded', modelWindow(builtModel, 'out'), null);
check('model/no-ipc-excluded', modelWindow(builtModel, 'noipc'), null);
check('model/tile-windows-1', builtModel[0].tiles[0].windows.map(w => w.address), ['ddd']);
check('model/tile-windows-2', builtModel[0].tiles[1].windows.map(w => w.address), ['aaa']);
check('model/tile-windows-3', builtModel[0].tiles[2].windows.map(w => w.address),
      ['bbb', 'nul', 'und', 'noti', 'fff']);
check('model/tile-windows-4', builtModel[0].tiles[3].windows.map(w => w.address),
      ['f0', 'f1', 'f2', 'f3', 'ft']);
check('model/tile-windows-5', builtModel[0].tiles[4].windows, []);
check('model/tile-windows-7', builtModel[1].tiles[1].windows.map(w => w.address), ['ccc']);
// The focused monitor's active workspace is current; another monitor's active
// workspace is shown.
check('model/states-a', builtModel[0].tiles.map(t => t.state),
      ['normal', 'current', 'normal', 'normal', 'normal']);
check('model/states-b', builtModel[1].tiles.map(t => t.state),
      ['normal', 'shown', 'normal', 'shown', 'normal']);
// A window's class is a string, an absent class is "", and ipc.title wins over
// the toplevel's own title.
check('model/class-kept', modelWindow(builtModel, 'aaa').cls, 'kitty');
check('model/class-null', modelWindow(builtModel, 'nul').cls, '');
check('model/class-undefined', modelWindow(builtModel, 'und').cls, '');
check('model/title-ipc', modelWindow(builtModel, 'aaa').title, 'aaa ipc');
check('model/title-fallback', modelWindow(builtModel, 'noti').title, 'noti fallback');
check('model/app', modelWindow(builtModel, 'aaa').app, 'kitty-app');
check('model/icon', modelWindow(builtModel, 'aaa').icon, '/icons/kitty.png');
check('model/app-empty-class', modelWindow(builtModel, 'nul').app, '');
check('model/icon-empty-class', modelWindow(builtModel, 'nul').icon, '');
// Hyprland's mode: 0 none, 1 maximized (real geometry), 2 fullscreen, 3 both,
// and the boolean true form.
check('model/fullscreen-modes',
      ['f0', 'f1', 'f2', 'f3', 'ft'].map(address => modelWindow(builtModel, address).fullscreen),
      [false, false, true, true, true]);
check('model/floating', modelWindow(builtModel, 'fff').floating, true);
check('model/not-floating', modelWindow(builtModel, 'aaa').floating, false);
check('model/urgent-window', modelWindow(builtModel, 'ddd').urgent, true);
check('model/urgent-tile', builtModel[0].tiles[0].urgent, true);
check('model/quiet-tile', builtModel[0].tiles[1].urgent, false);
// at/size keep their real IPC array shape on the way to the rect.
checkRect('model/rect-aaa', modelWindow(builtModel, 'aaa').rect,
      { x: 0, y: 0, width: 0.5, height: 1 });
checkRect('model/rect-bbb', modelWindow(builtModel, 'bbb').rect,
      { x: 0.5, y: 0, width: 0.5, height: 1 });
check('model/focused-window', modelWindow(builtModel, 'aaa').focused, true);
check('model/unfocused-window', modelWindow(builtModel, 'bbb').focused, false);

// Focus moving to the second monitor moves the current tile and the window
// flag with it.
const focusedSecond = ws.model(Object.assign({}, snapshot,
    { focusedName: 'DP-2', focusedAddress: 'ccc' }));
check('model/focus-second-current', focusedSecond[1].tiles[1].state, 'current');
check('model/focus-second-shown', focusedSecond[0].tiles[1].state, 'shown');
check('model/focus-address-second', modelWindow(focusedSecond, 'ccc').focused, true);
check('model/focus-address-first-off', modelWindow(focusedSecond, 'aaa').focused, false);

// monitorEntries: ordered, enabled, and present in Hyprland; a name with no
// reported monitor, and a disabled monitor, are left out.
check('model/entries', ws.monitorEntries(snapshot).map(e => [e.monitor.name, e.first]),
      [['DP-1', 1], ['DP-2', 6]]);
check('model/entries-disabled',
      ws.monitorEntries(Object.assign({}, snapshot, { enabledNames: ['DP-1'] })).map(e => e.monitor.name),
      ['DP-1']);
check('model/empty', ws.model(null), []);
check('model/no-monitors', ws.model({}), []);

// caption: distinct app names in first-seen order; no windows is "Empty".
check('caption/distinct', ws.caption([{ cls: 'firefox' }, { cls: 'firefox' }, { cls: 'kitty' }]),
      'firefox, kitty');
check('caption/skip-empty-cls', ws.caption([{ cls: '' }, { cls: 'kitty' }]), 'kitty');
check('caption/app-name', ws.caption([{ cls: 'com.t3tools.T3Code', app: 'T3 Code' }, { cls: 'firefox', app: 'Firefox' }]),
  'T3 Code, Firefox');
check('caption/app-fallback', ws.caption([{ cls: 'kitty', app: '' }]), 'kitty');
check('caption/empty', ws.caption([]), 'Empty');
check('caption/null', ws.caption(null), 'Empty');

// inBlocks: positive ids inside any block; special and named ids outside
// every block are excluded.
const blocks = [{ first: 1, count: 5 }, { first: 6, count: 5 }];
check('blocks/first', ws.inBlocks(1, blocks), true);
check('blocks/inside-second', ws.inBlocks(7, blocks), true);
check('blocks/last', ws.inBlocks(10, blocks), true);
check('blocks/gap-between-blocks', ws.inBlocks(11, blocks), false);
check('blocks/special', ws.inBlocks(-99, blocks), false);
check('blocks/zero', ws.inBlocks(0, blocks), false);
check('blocks/no-blocks', ws.inBlocks(3, []), false);

// dropTarget: the workspace id whose rect contains the point, one shared
// coordinate space, else -1 for a gap or outside every map.
const tileRects = [
  { id: 3, x: 0, y: 0, width: 100, height: 50 },
  { id: 4, x: 108, y: 0, width: 100, height: 50 }
];
check('drop/inside', ws.dropTarget({ x: 40, y: 20 }, tileRects), 3);
check('drop/second', ws.dropTarget({ x: 150, y: 25 }, tileRects), 4);
check('drop/gap', ws.dropTarget({ x: 104, y: 20 }, tileRects), -1);
check('drop/outside', ws.dropTarget({ x: 400, y: 20 }, tileRects), -1);
check('drop/below', ws.dropTarget({ x: 40, y: 60 }, tileRects), -1);
// A point on the window's own workspace still returns that id; the no-op is
// the moveDecision, not the hit test.
check('drop/own-workspace', ws.dropTarget({ x: 40, y: 20 }, tileRects), 3);
check('drop/no-rects', ws.dropTarget({ x: 40, y: 20 }, []), -1);
check('drop/degenerate', ws.dropTarget({ x: 0, y: 0 },
      [{ id: 3, x: 0, y: 0, width: 0, height: 0 }]), -1);

// moveDecision: a drop on the source workspace, or outside every map, is a
// no-op (-1); otherwise the target workspace id.
check('move/other', ws.moveDecision(1, 4), 4);
check('move/own', ws.moveDecision(3, 3), -1);
check('move/outside', ws.moveDecision(3, -1), -1);
check('move/zero', ws.moveDecision(3, 0), -1);

// moveTargets: a label per enabled monitor, then one item per workspace in its
// block, with the window's current workspace shown but inert.
const mvMonitors = [
  { name: 'DP-1' },
  { name: 'DP-2' },
  { name: 'HDMI-A-1' }
];
const mvBlocks = [
  { first: 1, count: 3 },
  { first: 6, count: 3 },
  { first: 11, count: 3 }
];
const mv = ws.moveTargets(mvMonitors, mvBlocks, 7);
check('move/labels', mv.filter(i => i.kind === 'label').map(i => i.text), ['DP-1', 'DP-2', 'HDMI-A-1']);
check('move/item-count', mv.filter(i => i.kind === 'item').length, 9);
check('move/ids', mv.filter(i => i.kind === 'item').map(i => i.id),
      ['move-workspace', 'move-workspace', 'move-workspace', 'move-workspace', 'move-workspace',
       'move-workspace', 'move-workspace', 'move-workspace', 'move-workspace']);
check('move/workspaces', mv.filter(i => i.kind === 'item').map(i => i.workspace), [1, 2, 3, 6, 7, 8, 11, 12, 13]);
check('move/current', mv.filter(i => i.current).map(i => i.workspace), [7]);
check('move/current-inert', mv.find(i => i.workspace === 7).enabled, false);
check('move/current-text', mv.find(i => i.workspace === 7).text, 'Workspace 7 (current)');
check('move/normal-text', mv.find(i => i.workspace === 8).text, 'Workspace 8');
check('move/others-enabled', mv.filter(i => i.kind === 'item' && i.workspace !== 7)
      .every(i => i.enabled === true), true);
check('move/grouped', mv.map(i => i.kind === 'label' ? i.text : i.workspace),
      ['DP-1', 1, 2, 3, 'DP-2', 6, 7, 8, 'HDMI-A-1', 11, 12, 13]);
check('move/disabled-excluded',
      ws.moveTargets([{ name: 'DP-1' }, { name: 'DP-2', disabled: true }],
          [{ first: 1, count: 2 }, { first: 6, count: 2 }], -1)
        .filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('move/first-disabled-keeps-block',
      ws.moveTargets([{ name: 'DP-1', disabled: true }, { name: 'DP-2' }],
          [{ first: 1, count: 2 }, { first: 6, count: 2 }], -1)
        .filter(i => i.kind === 'item').map(i => i.workspace),
      [6, 7]);
check('move/no-current', mv.filter(i => i.current).every(i => i.enabled === false), true);
check('move/no-monitors', ws.moveTargets([], [], 1), []);
check('move/zero-count', ws.moveTargets([{ name: 'DP-1' }], [{ first: 1, count: 0 }], 1), []);
check('move/bad-first', ws.moveTargets([{ name: 'DP-1' }], [{ first: 0, count: 5 }], 1), []);
check('move/nameless', ws.moveTargets([{ first: 1 }], [{ first: 1, count: 2 }], 1), []);
check('move/missing-block', ws.moveTargets([{ name: 'DP-1' }], [], 1), []);
check('move/current-not-in-blocks', ws.moveTargets(mvMonitors, mvBlocks, 99).some(i => i.current), false);

// windowMenuItems: the fixed order (Focus, Move to workspace, Float/Tile,
// Fullscreen, copy class/title, Close last in danger), with the toggle labels
// and the move submenu following the window and its targets; the move item
// drops out when no target is actionable.
const tiled = { floating: false, fullscreen: false };
const tiledMenu = ws.windowMenuItems(tiled, mv);
check('win/kinds', tiledMenu.map(i => i.kind),
      ['item', 'item', 'item', 'item', 'separator', 'item', 'item', 'separator', 'item']);
check('win/ids', tiledMenu.map(i => i.id),
      ['focus', 'move', 'toggle-floating', 'toggle-fullscreen', '', 'copy-class', 'copy-title', '', 'close']);
check('win/focus-text', tiledMenu[0].text, 'Focus window');
check('win/focus-hint', tiledMenu[0].hint, '↵');
check('win/move-text', tiledMenu[1].text, 'Move to workspace');
check('win/move-submenu', tiledMenu[1].submenu, mv);
check('win/float', tiledMenu[2].text, 'Float');
check('win/tile', ws.windowMenuItems({ floating: true, fullscreen: false }, [])
      .find(i => i.id === 'toggle-floating').text, 'Tile');
check('win/fullscreen', tiledMenu[3].text, 'Fullscreen');
check('win/exit-fullscreen',
      ws.windowMenuItems({ floating: false, fullscreen: true }, [])
      .find(i => i.id === 'toggle-fullscreen').text, 'Exit fullscreen');
check('win/close-text', tiledMenu[8].text, 'Close window');
check('win/close-danger', tiledMenu[8].danger, true);
check('win/close-last', tiledMenu.filter(i => i.kind === 'item').map(i => i.id).pop(), 'close');
check('win/copy-texts', [tiledMenu[5].text, tiledMenu[6].text], ['Copy window class', 'Copy window title']);
check('win/no-targets', ws.windowMenuItems(tiled, null).filter(i => i.id === 'move').length, 0);
check('win/labels-only', ws.windowMenuItems(tiled, [{ kind: 'label', text: 'DP-1' }])
      .filter(i => i.id === 'move').length, 0);
check('win/only-current', ws.windowMenuItems(tiled,
      ws.moveTargets([{ name: 'DP-1' }], [{ first: 1, count: 1 }], 1))
      .filter(i => i.id === 'move').length, 0);
check('win/has-target', tiledMenu.filter(i => i.id === 'move').length, 1);
check('win/null-window', ws.windowMenuItems(null, []).filter(i => i.kind === 'item').map(i => i.id),
      ['focus', 'toggle-floating', 'toggle-fullscreen', 'copy-class', 'copy-title', 'close']);
check('win/no-danger-elsewhere', tiledMenu.filter(i => i.kind === 'item' && i.id !== 'close')
      .every(i => i.danger === false), true);

// menuAction: item id to the service call that runs it; a separator, label, or
// unknown id is a no-op.
check('action/focus', ws.menuAction({ kind: 'item', id: 'focus' }), 'focusWindow');
check('action/move', ws.menuAction({ kind: 'item', id: 'move-workspace' }), 'moveWindow');
check('action/float', ws.menuAction({ kind: 'item', id: 'toggle-floating' }), 'toggleFloating');
check('action/fullscreen', ws.menuAction({ kind: 'item', id: 'toggle-fullscreen' }), 'toggleFullscreen');
check('action/copy-class', ws.menuAction({ kind: 'item', id: 'copy-class' }), 'copyWindowClass');
check('action/copy-title', ws.menuAction({ kind: 'item', id: 'copy-title' }), 'copyWindowTitle');
check('action/close', ws.menuAction({ kind: 'item', id: 'close' }), 'closeWindow');
check('action/separator', ws.menuAction({ kind: 'separator', id: '' }), '');
check('action/label', ws.menuAction({ kind: 'label', id: '', text: 'DP-1' }), '');
check('action/null', ws.menuAction(null), '');
check('action/unknown', ws.menuAction({ kind: 'item', id: 'nope' }), '');

// The action names are the contract with WorkspaceService: each must name a
// function it still exposes, so a rename cannot leave a dead menu item.
for (const op of ['focusWindow', 'moveWindow', 'toggleFloating', 'toggleFullscreen',
    'copyWindowClass', 'copyWindowTitle', 'closeWindow'])
  check('action/op-fn-' + op, new RegExp('function ' + op + '\\(').test(svcSrc), true);
NODEEOF
