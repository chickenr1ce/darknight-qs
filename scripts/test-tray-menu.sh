#!/usr/bin/env bash
# Headless gate for the tray context menu.
#
# A full QML boot needs a compositor, so this gate checks two things that run
# anywhere:
#   1. structure rules over the QML: the bar must not fall back to the native Qt
#      popup (QsMenuAnchor), the tray menu has one owner (the bar hands the click
#      to TrayMenuService, which moves the PanelState through the Panels
#      registry), TrayMenu hosts the shared ContextMenu, and PanelGrab keeps the
#      bar in the grab while the menu is open;
#   2. node runs of the shipped pure mapping (TrayMenuLogic.js, consumed through
#      the shared ContextMenu) through tests/qmljs.js.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "tray-menu FAIL: $*" >&2; exit 1; }

TRAY="$ROOT/modules/Tray.qml"
SERVICE="$ROOT/services/TrayMenuService.qml"
LOGIC="$ROOT/services/TrayMenuLogic.js"
WINDOW="$ROOT/windows/TrayMenu.qml"

# --- 1. structure ---
# No return to the platform popup: the menu is drawn in-shell.
if grep -rn --include='*.qml' 'QsMenuAnchor' "$ROOT/modules" "$ROOT/windows" "$ROOT/services" "$ROOT/components" | grep -q .; then
    fail "the native QsMenuAnchor popup is back"
fi
# One owner of the tray menu: the bar hands the click to TrayMenuService, and the
# service moves the PanelState through the registry instead of writing it itself.
grep -q 'TrayMenuService.toggleFor(' "$TRAY" \
    || fail "Tray does not toggle through TrayMenuService"
grep -q 'Panels.toggleAt(idPanelState' "$SERVICE" \
    || fail "TrayMenuService does not toggle through the panel registry"
grep -q 'Panels.openAt(idPanelState' "$SERVICE" \
    || fail "TrayMenuService does not switch items through the panel registry"
# The seam with the shared menu component.
grep -q 'ContextMenu {' "$WINDOW" \
    || fail "TrayMenu does not host the shared ContextMenu"
# Regression guard: the bar stays in the grab, so a bar press does not clear the
# grab at once while the pointer is still on the bar.
if grep -q 'dismissedByBar' "$ROOT/services/PanelGrab.qml"; then
    fail "PanelGrab drops the bar from the grab again; the grab clears at once while the pointer is on the bar"
fi
# Pure mapping module, loadable outside QML.
grep -q '^\.pragma library' "$LOGIC" \
    || fail "TrayMenuLogic.js is not a .pragma library"

# --- 2. descriptor mapping runs under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$ROOT/components/ContextMenuLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('tray-menu');
const tm = qmljs.load(process.argv[3]);

const item = (text, extra) => Object.assign({ isSeparator: false, text, icon: '', enabled: true, buttonType: 0, checkState: 0, hasChildren: false }, extra || {});
const sep = () => ({ isSeparator: true, text: '', icon: '', enabled: true, buttonType: 0, checkState: 0, hasChildren: false });
const shape = list => list.map(d => d.kind === 'separator' ? '-' : d.text);

// plain items keep order and map to full item descriptors
const plain = tm.describe([item('Store'), item('Library')], []);
check('plain/order', shape(plain), ['Store', 'Library']);
check('plain/kind', plain[0].kind, 'item');
check('plain/enabled', plain[0].enabled, true);
check('plain/image-empty', plain[0].image, '');
check('plain/glyph-empty', plain[0].glyph, '');
check('plain/hint-empty', plain[0].hint, '');
check('plain/check-none', plain[0].check, '');
check('plain/entry-passthrough', plain[0].entry.text, 'Store');

// separators: leading, trailing, and doubled ones are dropped
const seps = tm.describe([sep(), item('A'), sep(), sep(), item('B'), sep()], []);
check('separators/tidied', shape(seps), ['A', '-', 'B']);

// items without a label are dropped
check('blank/dropped', shape(tm.describe([item(''), item('A')], [])), ['A']);

// disabled, icon, check and radio state
const state = tm.describe([
  item('Off', { enabled: false }),
  item('Mute', { buttonType: 1, checkState: 2 }),
  item('Deafen', { buttonType: 1, checkState: 0 }),
  item('Online', { buttonType: 2, checkState: 2 }),
  item('Idle', { buttonType: 2, checkState: 0 }),
  item('Open', { icon: 'image://icon/discord' }),
], []);
check('state/disabled', state[0].enabled, false);
check('state/check-on', [state[1].check, state[1].checked], ['check', true]);
check('state/check-off', [state[2].check, state[2].checked], ['check', false]);
check('state/radio-on', [state[3].check, state[3].checked], ['radio', true]);
check('state/radio-off', [state[4].check, state[4].checked], ['radio', false]);
check('state/icon', state[5].image, 'image://icon/discord');

// one submenu level from the aligned child lists; deeper parents stay plain
const nested = tm.describe(
  [item('Audio Output', { hasChildren: true }), item('Quit')],
  [[item('Speakers', { buttonType: 2, checkState: 2 }), sep(), item('More', { hasChildren: true })], []]
);
check('submenu/parent', shape(nested), ['Audio Output', 'Quit']);
check('submenu/children', shape(nested[0].submenu), ['Speakers', '-', 'More']);
check('submenu/leaf-empty', nested[1].submenu, []);
check('submenu/deep-plain', nested[0].submenu[2].submenu, []);

// a parent whose children have not loaded yet has an empty submenu
const pending = tm.describe([item('Later', { hasChildren: true })], [[]]);
check('pending/empty', pending[0].submenu, []);

// missing or null input is an empty menu
check('empty/undefined', tm.describe(undefined, undefined), []);
check('empty/list', tm.describe([], []), []);
check('empty/null-entry', shape(tm.describe([null, item('A')], [])), ['A']);
console.log('tray-menu: mapping ok');

// ContextMenuLogic: the indicator slot exists only while an item carries a check
const cm = qmljs.load(process.argv[4]);
check('indicator/none', cm.hasIndicator([{ kind: 'item', text: 'A', check: '' }, { kind: 'separator' }]), false);
check('indicator/check', cm.hasIndicator([{ kind: 'item', text: 'A' }, { kind: 'item', text: 'B', check: 'check' }]), true);
check('indicator/radio', cm.hasIndicator([{ kind: 'item', text: 'A', check: 'radio', checked: false }]), true);
check('indicator/empty', cm.hasIndicator([]), false);
check('indicator/undefined', cm.hasIndicator(undefined), false);
check('indicator/null-entry', cm.hasIndicator([null, { kind: 'item', check: 'check' }]), true);
check('indicator/width-none', cm.indicatorWidth([{ kind: 'item', text: 'A' }], 16, 8), 0);
check('indicator/width-some', cm.indicatorWidth([{ kind: 'item', text: 'A', check: 'check' }], 16, 8), 24);
check('indicator/width-empty', cm.indicatorWidth(undefined, 16, 8), 0);
console.log('tray-menu: indicator ok');
NODEEOF
echo "tray-menu: all ok"
