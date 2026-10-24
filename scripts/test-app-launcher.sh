#!/usr/bin/env bash
# Headless gate for the app launcher (tickets 02-03).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# keeps the checks that lint and boot-check cannot make, and drops the ones
# that only restated implementation text (property names, binding text,
# function bodies, call counts). What remains:
#   1. structural boundaries: the state-file name, the pure-logic seam, the
#      shared-delegate and active-list rules, the palette boundary, the apps
#      menu seam, and the hanging-menu input-mask block (a past regression);
#   2. node runs of the shipped pure logic (ranking, match ranges, markup,
#      section building, hidden filtering, recent/pin/hide/unhide mutation,
#      menu building, state parsing) through tests/qmljs.js, so a broken
#      AppLogic.js fails the gate instead of a mirror that cannot drift;
#   3. the offscreen qmltestrunner suites for the mode, wheel, and menu-key
#      handlers.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "app-launcher FAIL: $*" >&2; exit 1; }

LOGIC="$ROOT/services/AppLogic.js"
SVC="$ROOT/services/AppService.qml"
VIEW="$ROOT/windows/DashboardAppsView.qml"

# --- 1. pure logic lives in AppLogic.js, imported by AppService ---
test -f "$LOGIC" \
    || fail "services/AppLogic.js is missing"
grep -q '^\.pragma library' "$LOGIC" \
    || fail "AppLogic.js is not a .pragma library"
grep -q '^import "AppLogic.js" as AppLogic' "$SVC" \
    || fail "AppService does not import AppLogic.js"

# --- 2. persistence ---
grep -q 'name: "app-launcher"' "$SVC" \
    || fail "AppService does not persist to the app-launcher state file"

# --- 4. the launcher carries palette tokens only ---
if grep -qnE '#[0-9a-fA-F]{3,8}' "$VIEW" "$SVC"; then
    fail "app launcher carries raw hex; palette tokens only"
fi

# --- 4d. shared context menu plus launcher wiring ---
CTX="$ROOT/components/ContextMenu.qml"
test -f "$CTX" \
    || fail "components/ContextMenu.qml is missing"
grep -q 'AppLogic.menuAction(item, row)' "$SVC" \
    || fail "AppService does not dispatch menu actions through AppLogic.menuAction"

# --- 4e. the hanging menu may grow past the card without resizing it ---
grep -q 'idAppsContextMenu.boundsHeight = root.menuBoundsHeight()' "$VIEW" \
    || fail "the Apps menu cannot hang below a short card"
grep -q 'property real boundsHeight: root.height' "$CTX" \
    || fail "ContextMenu has no boundsHeight override for hanging below the card"
grep -qF 'root.boundsHeight - 2 * Globals.menuMargin' "$CTX" \
    || fail "ContextMenu caps its height at the card instead of boundsHeight"
grep -qF 'root.boundsHeight - root.menuHeight - Globals.menuMargin' "$CTX" \
    || fail "ContextMenu menuY ignores boundsHeight; a hanging menu overshoots"
grep -qF 'root.boundsHeight - root.submenuHeight - Globals.menuMargin' "$CTX" \
    || fail "ContextMenu submenuY ignores boundsHeight; a hanging submenu overshoots"
grep -q 'readonly property Item inputBox: idMenuInputBox' "$CTX" \
    || fail "ContextMenu does not expose its menu bounding box for the input mask"
grep -q 'readonly property Item menuInputBox: idAppsContextMenu.inputBox' "$VIEW" \
    || fail "DashboardAppsView does not forward the menu input box to the dashboard"
if ! grep -A2 'inputOverlay:' "$ROOT/windows/DashboardCenter.qml" | grep -q 'idDashboardAppsView.menuInputBox'; then
    fail "the hanging Apps menu is not in the dashboard input mask"
fi
grep -A1 'item: root.inputOverlay' "$ROOT/components/PanelShell.qml" | grep -q 'intersection: Intersection.Combine' \
    || fail "PanelShell does not join inputOverlay to its mask"
grep -q 'width: !root.opened ? 0' "$CTX" \
    || fail "a closed menu still claims input past the card"
grep -q 'height: !root.opened ? 0' "$CTX" \
    || fail "a closed menu still claims input past the card"
for line in 'hasSubmenu: idSubmenu.visible' 'Math.min(idMenu.x, idSubmenu.x)' \
    'Math.min(idMenu.y, idSubmenu.y)' \
    'Math.max(idMenu.x + idMenu.width, idSubmenu.x + idSubmenu.width)' \
    'Math.max(idMenu.y + idMenu.height, idSubmenu.y + idSubmenu.height)'; do
    grep -qF "$line" "$CTX" \
        || fail "the menu input box lost '$line'; a hanging submenu is visible but dead to clicks"
done
grep -qF 'root.windowRoom - (root.mapToItem(null, 0, 0).y - root.slideOffset)' "$VIEW" \
    || fail "the Apps menu bounds do not reach the settled window bottom"
grep -q 'id: idOverhangScrim' "$CTX" \
    || fail "clicks beside a hanging submenu are swallowed instead of closing the menu"
SCRIM=$(sed -n '/id: idOverhangScrim/,/^    }/p' "$CTX")
for line in 'x: idMenuInputBox.x' 'y: idMenuInputBox.y' 'width: idMenuInputBox.width' \
    'height: idMenuInputBox.height' 'visible: root.opened' 'onPressed: root.closeMenu()'; do
    grep -qF "$line" <<<"$SCRIM" \
        || fail "idOverhangScrim lost '$line'; clicks beside a hanging submenu no longer close the menu"
done
grep -q 'windowRoom: root.windowHeight$' "$ROOT/windows/DashboardCenter.qml" \
    || fail "the Apps menu room is not the dashboard window height"
if grep 'windowRoom:' "$ROOT/windows/DashboardCenter.qml" | grep -q 'panelEdgeMargin'; then
    fail "the Apps menu room subtracts panelEdgeMargin; the menu stops short of the window bottom"
fi
grep -q 'readonly property real slideOffset: idPanel.y' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not expose the slide offset"
grep -q 'slideOffset: root.slideOffset' "$ROOT/windows/DashboardCenter.qml" \
    || fail "DashboardCenter does not pass the slide offset to the Apps view"
grep -q 'property real slideOffset' "$VIEW" \
    || fail "DashboardAppsView has no slideOffset input"

# --- 4f. launcher menu seam ---
grep -q 'import "AppLogic.js" as AppLogic' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus does not import AppLogic.js"
grep -q 'AppService.menuDescriptors(' "$VIEW" \
    || fail "DashboardAppsView does not bind its menu through AppService.menuDescriptors"
grep -q 'AppService.runMenuItem(' "$VIEW" \
    || fail "DashboardAppsView does not trigger its menu through AppService.runMenuItem"
for fn in menuGlyph submenuGlyph runMenuItem; do
    if grep -q "function $fn" "$VIEW"; then
        fail "DashboardAppsView still defines $fn"
    fi
done

# --- 4h. the shared AppIcon owns the row artwork ---
if grep -qE '^[[:space:]]*text:.*charAt' "$VIEW"; then
    fail "DashboardAppsView still paints an inline letter tile"
fi

# --- 4n. the smooth-wheel seam: pure SmoothWheelLogic.js behind SmoothWheel ---
SMOOTH="$ROOT/components/SmoothWheel.qml"
SMOOTHLOGIC="$ROOT/components/SmoothWheelLogic.js"
test -f "$SMOOTH" \
    || fail "components/SmoothWheel.qml is missing"
test -f "$SMOOTHLOGIC" \
    || fail "components/SmoothWheelLogic.js is missing"
grep -q '^\.pragma library' "$SMOOTHLOGIC" \
    || fail "SmoothWheelLogic.js is not a .pragma library"
grep -q 'import "SmoothWheelLogic.js" as SmoothWheelLogic' "$SMOOTH" \
    || fail "SmoothWheel does not import SmoothWheelLogic.js"

# --- 4m. two lists share one delegate and route through the active list ---
DELEGATE_COMPONENTS="$(grep -c 'id: idAppRowDelegate' "$VIEW")"
[ "$DELEGATE_COMPONENTS" -eq 1 ] \
    || fail "the Apps view does not declare exactly one shared delegate Component (found $DELEGATE_COMPONENTS)"
DELEGATE_USES="$(grep -c '^[[:space:]]*delegate: idAppRowDelegate$' "$VIEW")"
[ "$DELEGATE_USES" -eq 2 ] \
    || fail "both Apps lists do not share the one delegate Component (found $DELEGATE_USES)"
if grep -qnE '\bidAppsList\b' "$VIEW"; then
    fail "a list-specific idAppsList reference survives; route through root.activeList"
fi

# --- 4o. offscreen behavioral checks (skip without Qt 6) ---
QMLTESTRUNNER="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
MODE_TEST="$ROOT/tests/app-launcher-mode.qml"
WHEEL_TEST="$ROOT/tests/app-launcher-wheel.qml"
KEYS_TEST="$ROOT/tests/app-launcher-menu-keys.qml"
if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "app-launcher: qmltestrunner not found, skipping the offscreen tests" >&2
else
    if [ ! -f "$MODE_TEST" ]; then
        fail "the offscreen mode test is missing"
    fi
    MODE_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -input "$MODE_TEST" >"$MODE_OUT" 2>&1; then
        rm -f "$MODE_OUT"
    else
        cat "$MODE_OUT" >&2
        rm -f "$MODE_OUT"
        fail "the offscreen mode handler test failed"
    fi
    if [ ! -f "$WHEEL_TEST" ]; then
        fail "the offscreen wheel test is missing"
    fi
    WHEEL_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -input "$WHEEL_TEST" >"$WHEEL_OUT" 2>&1; then
        rm -f "$WHEEL_OUT"
    else
        cat "$WHEEL_OUT" >&2
        rm -f "$WHEEL_OUT"
        fail "the offscreen wheel handler test failed"
    fi
    if [ ! -f "$KEYS_TEST" ]; then
        fail "the offscreen menu-keys test is missing"
    fi
    KEYS_OUT="$(mktemp)"
    if env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
        "$QMLTESTRUNNER" -input "$KEYS_TEST" >"$KEYS_OUT" 2>&1; then
        rm -f "$KEYS_OUT"
    else
        cat "$KEYS_OUT" >&2
        rm -f "$KEYS_OUT"
        fail "the offscreen menu-keys handler test failed"
    fi
fi

# --- 5. ranking, sections, markup, and state run under node ---
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$ROOT/services/MonitorLogic.js" "$ROOT/config/Icons.qml" "$SVC" <<'NODEEOF'
const fs = require('fs');
const qmljs = require(process.argv[2]);
const check = qmljs.checker('app-launcher');
const al = qmljs.load(process.argv[3]);
const ml = qmljs.load(process.argv[4]);
const iconsSrc = fs.readFileSync(process.argv[5], 'utf8');
const svcSrc = fs.readFileSync(process.argv[6], 'utf8');

const RAW = [
  { id: 'firefox.desktop', name: 'Firefox', genericName: 'Web Browser', keywords: ['browser', 'web'], command: ['firefox'], startupClass: 'firefox', icon: 'firefox' },
  { id: 'org.gnome.Files.desktop', name: 'Files', genericName: 'File Manager', keywords: ['file', 'folder'], command: ['nautilus'] },
  { id: 'profile.desktop', name: 'Profile', genericName: 'Account', keywords: [], command: ['profile'] },
  { id: 'code.desktop', name: 'Code', genericName: 'Code Editor', keywords: ['editor', 'programming'], command: ['code'] },
  { id: 'vscode.desktop', name: 'VS Code', genericName: 'Editor', keywords: ['editor'], command: ['code'] },
  { id: 'editor.desktop', name: 'Kakoune', genericName: 'Modal editor', keywords: ['code', 'editor'], command: ['kak'] },
  { id: 'gimp.desktop', name: 'GIMP', genericName: 'Image Editor', keywords: ['image'], command: ['gimp'] },
];
const ENTRIES = al.makeRecords(RAW);
const PINNED = ['code.desktop', 'firefox.desktop'];
const RECENT = ['firefox.desktop', 'gimp.desktop', 'code.desktop', 'editor.desktop'];

// makeRecords: plain records sorted once, with a lowercased name, a search
// haystack (generic name + keywords + id), precomputed window keys, a copied
// command array, mapped plain actions, and the source QObject passthrough.
const handles = { fake: true };
const records = al.makeRecords([
  { id: 'z.desktop', name: 'Zeta', genericName: 'Last', keywords: ['zz'], command: ['zeta'], entry: handles },
  { id: 'org.mozilla.firefox', name: 'Firefox', genericName: 'Web Browser', keywords: ['web', 'browser'], startupClass: 'firefox', runInTerminal: true, command: ['firefox'], actions: [{ name: 'New Window', icon: 'window-new' }] },
]);
check('records/sorted', records.map(r => r.name), ['Firefox', 'Zeta']);
check('records/nameLower', records[0].nameLower, 'firefox');
check('records/meta', records[0].meta, 'web browser web browser org.mozilla.firefox');
check('records/keys', records[0].keys, ['firefox', 'org.mozilla.firefox']);
check('records/terminal', records[0].runInTerminal, true);
check('records/actions', records[0].actions, [{ name: 'New Window', icon: 'window-new', index: 0 }]);
check('records/entry', records[1].entry, handles);
check('records/icon', records[0].icon, '');
check('records/no-entry', records[0].entry, null);
check('records/null', al.makeRecords([null, undefined]).length, 0);
check('records/keywords-string',
      al.makeRecords([{ id: 'a', name: 'A', keywords: 'one two' }])[0].meta.indexOf('one two') !== -1,
      true);
const cmd = ['firefox', '--new'];
const copyRec = al.makeRecords([{ id: 'x', name: 'X', command: cmd }])[0];
cmd.push('mutated');
check('records/command-copy', copyRec.command.join(' '), 'firefox --new');
check('records/array-like-command',
      al.makeRecords([{ id: 'x', name: 'X', command: { length: 2, 0: 'a', 1: 'b' } }])[0].command,
      ['a', 'b']);
check('list/array-like', al.listValues({ length: 2, 0: 'a', 1: 'b' }), ['a', 'b']);
check('list/string', al.listValues('ab'), []);
check('list/none', al.listValues(null), []);
check('listtext/array-like',
      al.listText({ length: 2, 0: 'a', 1: 'b', join: function () { return 'a b'; } }),
      'a b');

// rank: prefix beats substring beats keyword, ties by name; no match is empty.
check('rank/fi', al.rank(ENTRIES, 'fi').map(e => e.name), ['Files', 'Firefox', 'Profile']);
check('rank/code', al.rank(ENTRIES, 'code').map(e => e.name), ['Code', 'VS Code', 'Kakoune']);
check('rank/zzzz', al.rank(ENTRIES, 'zzzz'), []);
check('rank/empty-sorted',
      al.rank(ENTRIES, '').map(e => e.name),
      ['Code', 'Files', 'Firefox', 'GIMP', 'Kakoune', 'Profile', 'VS Code']);

// matchRanges: contiguous substring, mid-name, subsequence, none.
check('match/prefix', al.matchRanges('Firefox', 'fi'), [[0, 2]]);
check('match/middle', al.matchRanges('Profile', 'fi'), [[3, 5]]);
check('match/subsequence', al.matchRanges('Firefox', 'frx'), [[0, 1], [2, 3], [6, 7]]);
check('match/empty', al.matchRanges('Firefox', '   '), []);
check('match/none', al.matchRanges('Firefox', 'zz'), []);

// markup escapes the name and tints only the matched run.
check('markup/highlight', al.markup('Firefox', 'fi', '#abc'), '<font color="#abc">Fi</font>refox');
check('markup/escape', al.markup('A & <b>', 'zz', '#fff'), 'A &amp; &lt;b&gt;');

// parseState: missing or corrupt input loads as empty lists plus an empty
// terminal; the pinned/hidden/recent keys still parse alongside it.
check('state/corrupt', al.parseState('{ not json'), { pinned: [], hidden: [], recent: [], terminal: '' });
check('state/null', al.parseState('null'), { pinned: [], hidden: [], recent: [], terminal: '' });
check('state/array', al.parseState('[1, 2]'), { pinned: [], hidden: [], recent: [], terminal: '' });
check('state/strings',
      al.parseState('{"pinned":["a","b"],"hidden":["c"],"recent":["d","e"]}'),
      { pinned: ['a', 'b'], hidden: ['c'], recent: ['d', 'e'], terminal: '' });
check('state/non-strings',
      al.parseState('{"pinned":["a",7,""],"hidden":"x","recent":null}'),
      { pinned: ['a'], hidden: [], recent: [], terminal: '' });
check('state/recent-cap',
      al.parseState('{"recent":["a","b","c","d","e","f","g","h","i"]}').recent.length,
      8);
check('state/terminal-kept',
      al.parseState('{"pinned":["a"],"hidden":["b"],"recent":["c"],"terminal":"kitty -e"}'),
      { pinned: ['a'], hidden: ['b'], recent: ['c'], terminal: 'kitty -e' });
check('state/terminal-missing', al.parseState('{"pinned":["a"]}').terminal, '');
check('state/terminal-non-string', al.parseState('{"terminal":7}').terminal, '');

// sections: empty query builds Pinned (pin order), Recent (no pins, max 4),
// All apps (A-Z with count); a query collapses to one unsectioned list.
const home = al.sections(ENTRIES, PINNED, RECENT, '');
check('sections/keys', home.map(s => s.key), ['pinned', 'recent', 'all']);
check('sections/pin-order', home.find(s => s.key === 'pinned').items.map(e => e.name), ['Code', 'Firefox']);
check('sections/recent-skips-pinned', home.find(s => s.key === 'recent').items.map(e => e.name), ['GIMP', 'Kakoune']);
check('sections/all-count', home.find(s => s.key === 'all').count, ENTRIES.length);
check('sections/all-sorted',
      home.find(s => s.key === 'all').items.map(e => e.name),
      ['Code', 'Files', 'Firefox', 'GIMP', 'Kakoune', 'Profile', 'VS Code']);
check('sections/recent-cap',
      al.sections(ENTRIES, [], ['gimp.desktop', 'editor.desktop', 'profile.desktop', 'vscode.desktop', 'code.desktop', 'firefox.desktop'], '')
        .find(s => s.key === 'recent').items.length,
      4);
check('sections/stale-pin',
      al.sections(ENTRIES, ['ghost.desktop', 'code.desktop'], [], '').find(s => s.key === 'pinned').items.map(e => e.name),
      ['Code']);

// A hidden (or removed) id is absent from the entries the caller passes in, so
// it renders in no section.
const VISIBLE = ENTRIES.filter(e => e.id !== 'gimp.desktop');
check('sections/hidden-recent',
      al.sections(VISIBLE, PINNED, RECENT, '').find(s => s.key === 'recent').items.map(e => e.name),
      ['Kakoune']);
check('sections/hidden-all',
      al.sections(VISIBLE, [], [], '').find(s => s.key === 'all').items.map(e => e.name).indexOf('GIMP'),
      -1);

check('sections/query-keys', al.sections(ENTRIES, PINNED, RECENT, 'fi').map(s => s.key), ['results']);
check('sections/query-items',
      al.sections(ENTRIES, PINNED, RECENT, 'fi')[0].items.map(e => e.name),
      ['Files', 'Firefox', 'Profile']);
check('sections/query-none', al.sections(ENTRIES, PINNED, RECENT, 'zzzz')[0].items, []);

// browseRows: the empty-query model is the sectioned list, rowIndex and
// appIndex run consecutively, and no Run row exists without a query.
const browse = al.browseRows(ENTRIES, PINNED, RECENT);
check('rows/browse-headers', browse.filter(r => r.kind === 'header').map(r => r.key), ['pinned', 'recent', 'all']);
check('rows/browse-first-apps', browse.filter(r => r.kind === 'app').map(r => r.record.name).slice(0, 2), ['Code', 'Firefox']);
check('rows/browse-rowindex', browse.map(r => r.rowIndex), browse.map((_, i) => i));
check('rows/browse-appindex', browse.filter(r => r.kind === 'app').map(r => r.appIndex), browse.filter(r => r.kind === 'app').map((_, i) => i));
check('rows/browse-header-appindex', browse.filter(r => r.kind === 'header').every(r => r.appIndex === -1), true);
check('rows/browse-no-run', browse.some(r => r.kind === 'run'), false);

// resultRows: empty query is the empty model, a match ranks into app rows with
// no header and no Run row, and no match appends exactly the Run row.
check('rows/result-empty', al.resultRows(ENTRIES, PINNED, RECENT, ''), []);
check('rows/result-whitespace', al.resultRows(ENTRIES, PINNED, RECENT, '   '), []);
check('rows/result-apps',
      al.resultRows(ENTRIES, PINNED, RECENT, 'fi').filter(r => r.kind === 'app').map(r => r.record.name),
      ['Files', 'Firefox', 'Profile']);
check('rows/result-no-header', al.resultRows(ENTRIES, PINNED, RECENT, 'fi').some(r => r.kind === 'header'), false);
check('rows/result-no-run', al.resultRows(ENTRIES, PINNED, RECENT, 'fi').some(r => r.kind === 'run'), false);
check('rows/result-run', al.resultRows(ENTRIES, PINNED, RECENT, 'zzzz'), [{ kind: 'run', query: 'zzzz', rowIndex: 0, appIndex: 0 }]);
check('rows/result-run-trim', al.resultRows(ENTRIES, PINNED, RECENT, '  zzzz ')[0].query, 'zzzz');

// visibleEntries: a hidden id drops out; an unknown id is a no-op and an empty
// hidden list passes the caller's list straight through.
check('visible/filter',
      al.visibleEntries(ENTRIES, ['gimp.desktop']).map(e => e.name).indexOf('GIMP'),
      -1);
check('visible/keep',
      al.visibleEntries(ENTRIES, ['gimp.desktop']).map(e => e.name),
      ['Code', 'Files', 'Firefox', 'Kakoune', 'Profile', 'VS Code']);
check('visible/none', al.visibleEntries(ENTRIES, []).length, ENTRIES.length);
check('visible/stale', al.visibleEntries(ENTRIES, ['ghost.desktop']).length, ENTRIES.length);

// resolveHidden: each hidden id maps to its installed entry, in hidden-list
// order; an id with no installed entry maps to null so the view falls back to
// byId (NoDisplay) then the raw id.
check('hidden/resolved',
      al.resolveHidden(ENTRIES, ['firefox.desktop', 'gimp.desktop']).map(r => r.id + ':' + (r.entry ? r.entry.name : 'null')),
      ['firefox.desktop:Firefox', 'gimp.desktop:GIMP']);
check('hidden/order',
      al.resolveHidden(ENTRIES, ['code.desktop', 'firefox.desktop']).map(r => r.id),
      ['code.desktop', 'firefox.desktop']);
check('hidden/stale',
      al.resolveHidden(ENTRIES, ['ghost.desktop']).map(r => r.id + ':' + (r.entry ? r.entry.name : 'null')),
      ['ghost.desktop:null']);
check('hidden/empty', al.resolveHidden(ENTRIES, []), []);
check('hidden/undefined', al.resolveHidden(ENTRIES, undefined), []);

// The byId maps are prototype-less too, so a `__proto__` id resolves to its
// record instead of mutating the map's prototype.
const protoRecords = al.makeRecords([{ id: '__proto__', name: 'Proto' }]);
check('sections/proto-id',
      al.sections(protoRecords, ['__proto__'], [], '').find(s => s.key === 'pinned').items.map(e => e.name),
      ['Proto']);
check('hidden/proto-id',
      al.resolveHidden(protoRecords, ['__proto__']).map(r => r.id + ':' + (r.entry ? r.entry.name : 'null')),
      ['__proto__:Proto']);

// recordLaunch: prepend the new id, dedup the old copy, cap the tail.
check('recent/new', al.recordLaunch(['b', 'c'], 'a', 8), ['a', 'b', 'c']);
check('recent/dedup', al.recordLaunch(['b', 'a', 'c'], 'a', 8), ['a', 'b', 'c']);
check('recent/cap', al.recordLaunch(['a', 'b', 'c'], 'd', 2), ['d', 'a']);
check('recent/empty', al.recordLaunch([], 'a', 8), ['a']);

// togglePin: add appends, remove drops, order is preserved.
check('pin/add', al.togglePin(['a'], 'b'), ['a', 'b']);
check('pin/remove', al.togglePin(['a', 'b'], 'a'), ['b']);
check('pin/empty', al.togglePin([], 'a'), ['a']);

// hide: a new id appends once, an existing id is a no-op, an empty id is a
// no-op, and a missing list starts empty.
check('hide/add', al.hide(['a'], 'b'), ['a', 'b']);
check('hide/dup', al.hide(['a', 'b'], 'a'), ['a', 'b']);
check('hide/empty-id', al.hide(['a'], ''), ['a']);
check('hide/undefined', al.hide(undefined, 'a'), ['a']);

// unhide: drops the id and keeps the rest of the order, an absent id is a
// no-op, an empty id is a no-op, and a missing list starts empty.
check('unhide/remove', al.unhide(['a', 'b', 'c'], 'b'), ['a', 'c']);
check('unhide/absent', al.unhide(['a', 'b'], 'z'), ['a', 'b']);
check('unhide/empty-id', al.unhide(['a'], ''), ['a']);
check('unhide/undefined', al.unhide(undefined, 'a'), []);

// menuItems: the app menu opens, keeps, pins, hides, and copies, with the
// entry's actions under an Actions label; the Run row only runs and copies.
const noActions = al.makeRecords([{ id: 'firefox.desktop', name: 'Firefox', actions: [] }])[0];
check('menu/app-kinds',
      al.menuItems(noActions, false, false).map(i => i.kind),
      ['item', 'item', 'separator', 'item', 'item', 'separator', 'item']);
check('menu/app-ids',
      al.menuItems(noActions, false, false).filter(i => i.kind === 'item').map(i => i.id),
      ['open', 'open-keep', 'pin', 'hide', 'copy-command']);
check('menu/open-hint',
      al.menuItems(noActions, false, false).find(i => i.id === 'open').hint,
      '↵');
check('menu/keep-hint',
      al.menuItems(noActions, false, false).find(i => i.id === 'open-keep').hint,
      'middle');
check('menu/pinned',
      al.menuItems(noActions, true, false).find(i => i.id === 'unpin').text,
      'Unpin');
check('menu/pin',
      al.menuItems(noActions, false, false).find(i => i.id === 'pin').text,
      'Pin');
check('menu/pin-hint',
      al.menuItems(noActions, false, false).find(i => i.id === 'pin').hint,
      'Ctrl+P');

const withActions = al.makeRecords([{ id: 'firefox.desktop', name: 'Firefox', actions: [
  { name: 'New Window', icon: 'window-new' },
  { name: 'New Private Window', icon: '' },
] }])[0];
const actionMenu = al.menuItems(withActions, false, false);
check('menu/actions-label',
      actionMenu.some(i => i.kind === 'label' && i.text === 'Actions'),
      true);
check('menu/actions-ids',
      actionMenu.filter(i => i.kind === 'item' && i.id.indexOf('action:') === 0).map(i => i.id),
      ['action:0', 'action:1']);
check('menu/actions-index',
      actionMenu.find(i => i.id === 'action:1').actionIndex,
      1);
check('menu/actions-image',
      actionMenu.find(i => i.id === 'action:0').image,
      'window-new');
check('menu/actions-iconless',
      actionMenu.find(i => i.id === 'action:1').image,
      '');

// A record can drop a null desktop action; its surviving descriptors carry the
// original list index, and the menu emits that index so launchAction maps back
// to the uncompacted entry.actions.
const sparseActions = al.makeRecords([{ id: 'sparse.desktop', name: 'Sparse', actions: [
  { name: 'First', icon: '', index: 0 },
  { name: 'Third', icon: '', index: 2 },
] }])[0];
check('menu/actions-sparse-text',
      al.menuItems(sparseActions, false, false).filter(i => i.id.indexOf('action:') === 0).map(i => i.text),
      ['First', 'Third']);
check('menu/actions-sparse-index',
      al.menuItems(sparseActions, false, false).filter(i => i.id.indexOf('action:') === 0).map(i => i.actionIndex),
      [0, 2]);

check('menu/run-kinds',
      al.menuItems(null, false, true).map(i => i.kind),
      ['item', 'item']);
check('menu/run-ids',
      al.menuItems(null, false, true).map(i => i.id),
      ['run', 'copy-command']);

// entryKeys: startupClass, the id, and (only for a reverse-DNS id) the last
// dot-separated segment when it is long enough, non-numeric, and not a generic
// stoplist word; normalized and deduped, so a bare id keeps one key.
check('keys/startup-and-id', al.entryKeys({ id: 'firefox', startupClass: 'Firefox' }), ['firefox']);
check('keys/reverse-dns',
      al.entryKeys({ id: 'org.gnome.Files', startupClass: 'Nautilus' }),
      ['nautilus', 'org.gnome.files', 'files']);
check('keys/startup-only', al.entryKeys({ id: '', startupClass: 'mpv' }), ['mpv']);
check('keys/empty', al.entryKeys({ id: '', startupClass: '' }), []);
check('keys/null', al.entryKeys(null), []);
check('keys/no-dot-keeps-one',
      al.entryKeys({ id: "Baldur's Gate 3" }),
      ["baldur's gate 3"]);
check('keys/stoplist-app', al.entryKeys({ id: 'org.kde.kdeconnect.app' }), ['org.kde.kdeconnect.app']);
check('keys/stoplist-desktop', al.entryKeys({ id: 'ai.opencode.desktop' }), ['ai.opencode.desktop']);
check('keys/stoplist-handler', al.entryKeys({ id: 'com.example.handler' }), ['com.example.handler']);
check('keys/no-dot-url-handler', al.entryKeys({ id: 'code-url-handler' }), ['code-url-handler']);
check('keys/numeric-suffix', al.entryKeys({ id: 'com.example.123' }), ['com.example.123']);
check('keys/short-suffix', al.entryKeys({ id: 'com.example.ab' }), ['com.example.ab']);
check('keys/reverse-dns-two', al.entryKeys({ id: 'org.mozilla.firefox' }), ['org.mozilla.firefox', 'firefox']);

// classMatches: a single-segment key matches any class segment, a reverse-DNS
// key matches the class's last segment only, and a generic prefix never does.
check('match/single', al.classMatches('spotify', 'spotify'), true);
check('match/single-in-reverse', al.classMatches('com.spotify.client', 'spotify'), true);
check('match/reverse-last', al.classMatches('spectacle', 'org.kde.spectacle'), true);
check('match/prefix-guard', al.classMatches('org.kde.okular', 'org.kde.spectacle'), false);
check('match/generic-prefix', al.classMatches('org', 'org.gnome.files'), false);
check('match/none', al.classMatches('firefox', 'spotify'), false);
check('match/empty', al.classMatches('', 'firefox'), false);

// windowMatches: strict normalized equality — no segment, substring, or
// last-part matching — so a generic or numeric key cannot claim a window.
check('wm/exact', al.windowMatches(['firefox'], ['firefox']), true);
check('wm/case-space', al.windowMatches(['Firefox'], ['  firefox  ']), true);
check('wm/substring', al.windowMatches(['firefox'], ['firefox-developer-edition']), false);
check('wm/longer-class', al.windowMatches(['firefox'], ['org.mozilla.firefox']), false);
check('wm/reverse-full',
      al.windowMatches(al.entryKeys({ id: 'org.mozilla.firefox' }), ['org.mozilla.firefox']), true);
check('wm/reverse-last',
      al.windowMatches(al.entryKeys({ id: 'org.mozilla.firefox' }), ['firefox']), true);
check('wm/bare-not-dev-edition',
      al.windowMatches(al.entryKeys({ id: 'firefox' }), ['firefox-developer-edition']), false);
check('wm/startup-class',
      al.windowMatches(al.entryKeys({ id: 'org.gnome.Files', startupClass: 'Nautilus' }), ['nautilus']), true);
check('wm/startup-class-exact',
      al.windowMatches(al.entryKeys({ id: 'org.gnome.Files', startupClass: 'Nautilus' }), ['nautilus-not']), false);
check('wm/numeric-suffix-not-unity',
      al.windowMatches(al.entryKeys({ id: "Baldur's Gate 3" }), ['Unityhub-unity-editor-6000.3.25f1']), false);
check('wm/kdeconnect-not-app',
      al.windowMatches(al.entryKeys({ id: 'org.kde.kdeconnect.app' }), ['app']), false);
check('wm/kdeconnect-not-com-app',
      al.windowMatches(al.entryKeys({ id: 'org.kde.kdeconnect.app' }), ['com.example.app']), false);
check('wm/kdeconnect-exact',
      al.windowMatches(al.entryKeys({ id: 'org.kde.kdeconnect.app' }), ['org.kde.kdeconnect.app']), true);
check('wm/url-handler-not-handler',
      al.windowMatches(al.entryKeys({ id: 'code-url-handler' }), ['handler']), false);
check('wm/none', al.windowMatches(['firefox'], ['spotify']), false);
check('wm/empty', al.windowMatches([], ['firefox']), false);

// windowIndexesFor: exactly the matching toplevel indexes — never all of them
// and never an unmatched one.
check('windows/one', al.windowIndexesFor(['firefox'], [['firefox'], ['org.kde.okular']]), [0]);
check('windows/multi', al.windowIndexesFor(['mpv'], [['mpv'], ['firefox'], ['mpv']]), [0, 2]);
check('windows/exact-indexes',
      al.windowIndexesFor(['firefox'], [['firefox'], ['spotify'], ['firefox']]),
      [0, 2]);
check('windows/none', al.windowIndexesFor(['firefox'], [['org'], ['org.kde.okular']]), []);
check('windows/empty', al.windowIndexesFor(['firefox'], []), []);
check('windows/prefix-guard',
      al.windowIndexesFor(al.entryKeys({ id: 'org.gnome.Files' }), [['org'], ['org.kde.okular']]),
      []);
check('windows/startup-class',
      al.windowIndexesFor(al.entryKeys({ id: 'org.gnome.Files', startupClass: 'Nautilus' }),
          [['org'], ['nautilus']]),
      [1]);
check('windows/reverse-dns-class',
      al.windowIndexesFor(al.entryKeys({ id: 'org.gnome.Files' }),
          [['org'], ['files'], ['org.gnome.files']]),
      [1, 2]);

// runningCounts: one count per matching window even when several keys of one
// entry match several sources of the same window; strict equality keeps the
// Baldur's Gate 3 / Unity case out.
const ffRec = al.makeRecords([{ id: 'org.mozilla.firefox', name: 'Firefox', startupClass: 'firefox' }]);
const bg3Rec = al.makeRecords([{ id: "Baldur's Gate 3", name: "Baldur's Gate 3", startupClass: 'steam_app_1086940' }]);
check('run/exact', al.runningCounts(ffRec, [['firefox']]), { 'org.mozilla.firefox': 1 });
check('run/count-two', al.runningCounts(ffRec, [['firefox'], ['Firefox'], ['spotify']]), { 'org.mozilla.firefox': 2 });
check('run/dedupe-sources',
      al.runningCounts(ffRec, [['firefox', 'org.mozilla.firefox']]),
      { 'org.mozilla.firefox': 1 });
check('run/bg3-no-unity',
      al.runningCounts(bg3Rec, [['Unityhub-unity-editor-6000.3.25f1']]),
      {});
check('run/no-records', al.runningCounts([], [['firefox']]), {});
check('run/no-windows', al.runningCounts(ffRec, []), {});

// A user-derived id can collide with Object.prototype keys. The hash maps are
// prototype-less, so `constructor` does not resolve to the Object constructor
// (which made a later `.push` throw) and `__proto__` is an own key.
const ctorCounts = al.runningCounts(
    al.makeRecords([{ id: 'org.example.constructor', name: 'Ctor', startupClass: 'org.example.constructor' }]),
    [['constructor']]);
check('run/proto-constructor', ctorCounts['org.example.constructor'], 1);
const protoCounts = al.runningCounts(
    al.makeRecords([{ id: '__proto__', name: 'Proto' }]),
    [['__proto__']]);
check('run/proto-key',
      Object.prototype.hasOwnProperty.call(protoCounts, '__proto__') && protoCounts['__proto__'],
      1);

// wsSnapshot mirrors the plain data AppService hands over: ordered monitor
// names, the enabled subset, each monitor's first workspace, Hyprland's active
// id per monitor, and one workspace id per open window (null for a window with
// no workspace). Every decision below is the pure builder's.
function wsSnapshot(monitors, perMonitor, anchorName, toplevelWorkspaceIds) {
  const orderedNames = [];
  const enabledNames = [];
  const firstWorkspaces = [];
  const hyprMonitors = [];
  for (let i = 0; i < monitors.length; i++) {
    const monitor = monitors[i];
    orderedNames.push(monitor.name);
    if (monitor.disabled !== true)
      enabledNames.push(monitor.name);
    firstWorkspaces.push({ name: monitor.name, first: monitor.first });
    hyprMonitors.push({
      name: monitor.name,
      activeWorkspaceId: monitor.active === undefined ? -1 : monitor.active
    });
  }
  if (anchorName !== '' && orderedNames.indexOf(anchorName) === -1)
    firstWorkspaces.push({ name: anchorName, first: 1 });
  return {
    orderedNames: orderedNames,
    enabledNames: enabledNames,
    firstWorkspaces: firstWorkspaces,
    hyprMonitors: hyprMonitors,
    toplevelWorkspaceIds: toplevelWorkspaceIds || [],
    perMonitor: perMonitor,
    anchorName: anchorName
  };
}

// menuItems with a running count keeps the spec order — Open, Open on
// workspace (only when workspace items exist), Open, keep dashboard, Focus
// window — and Kill last in danger; a zero count adds neither Focus nor Kill.
const runningMenu = al.menuItems(noActions, false, false, 2);
check('menu/focus-running',
      runningMenu.find(i => i.id === 'focus-window').text,
      'Focus window (2 open)');
check('menu/focus-after-open',
      runningMenu.filter(i => i.kind === 'item').map(i => i.id),
      ['open', 'open-keep', 'focus-window', 'pin', 'hide', 'copy-command', 'kill']);
check('menu/workspace-order',
      al.menuItems(noActions, false, false, 2,
        al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1')))
        .filter(i => i.kind === 'item').map(i => i.id),
      ['open', 'open-workspace', 'open-keep', 'focus-window', 'pin', 'hide', 'copy-command', 'kill']);
check('menu/kill-text', runningMenu.find(i => i.id === 'kill').text, 'Kill Firefox');
check('menu/kill-danger', runningMenu.find(i => i.id === 'kill').danger, true);
check('menu/kill-last', runningMenu.filter(i => i.kind === 'item').map(i => i.id).pop(), 'kill');
check('menu/no-focus-idle',
      al.menuItems(noActions, false, false, 0).filter(i => i.kind === 'item').map(i => i.id),
      ['open', 'open-keep', 'pin', 'hide', 'copy-command']);

// workspaceFor: Ctrl+N targets the absolute workspace N (Ctrl+0 is 10), and
// the key does nothing when the workspace is past the total of
// perMonitor × enabled monitors, or on a bad key or total.
check('ws/key-one', al.workspaceFor(1, 10), 1);
check('ws/key-nine', al.workspaceFor(9, 10), 9);
check('ws/key-zero-ten', al.workspaceFor(0, 10), 10);
check('ws/key-at-total', al.workspaceFor(5, 5), 5);
check('ws/out-of-range', al.workspaceFor(6, 5), -1);
check('ws/zero-when-total-one', al.workspaceFor(0, 1), -1);
check('ws/key-ten-out-of-range', al.workspaceFor(10, 10), -1);
check('ws/total-zero', al.workspaceFor(1, 0), -1);
check('ws/total-bad', al.workspaceFor(1, 'x'), -1);
check('ws/nan-key', al.workspaceFor('x', 10), -1);
check('ws/negative-key', al.workspaceFor(-1, 10), -1);

// workspaceKeys: the footer cap reads the reachable range, capped at 9, and
// switches to "ctrl 1–9, 0" once a tenth workspace exists.
check('keys/one', al.workspaceKeys(1), 'ctrl 1–1');
check('keys/five', al.workspaceKeys(5), 'ctrl 1–5');
check('keys/nine', al.workspaceKeys(9), 'ctrl 1–9');
check('keys/ten', al.workspaceKeys(10), 'ctrl 1–9, 0');
check('keys/twelve', al.workspaceKeys(12), 'ctrl 1–9, 0');
check('keys/zero', al.workspaceKeys(0), 'ctrl 1–1');
check('keys/bad', al.workspaceKeys('x'), 'ctrl 1–1');

// firstEmptyWorkspace: the first slot without an occupant, -1 when the block
// is full, and an out-of-range block is -1.
check('empty/none', al.firstEmptyWorkspace(1, 5, []), 1);
check('empty/gap', al.firstEmptyWorkspace(1, 5, [1, 2]), 3);
check('empty/second-monitor', al.firstEmptyWorkspace(6, 5, [6, 7, 8]), 9);
check('empty/full', al.firstEmptyWorkspace(1, 5, [1, 2, 3, 4, 5]), -1);
check('empty/outside-ignored', al.firstEmptyWorkspace(1, 5, [99]), 1);
check('empty/zero-count', al.firstEmptyWorkspace(1, 0, []), -1);

// workspaceMenu: one label per enabled monitor, the anchor first even when it
// is not the primary; one item per slot under each label with the absolute
// workspace number, the active one labelled per monitor, occupied flags, ctrl
// hints by absolute number on every monitor's items, and "New empty workspace"
// from the anchor's block.
const WS = [
  { name: 'DP-1', first: 1, active: 3 },
  { name: 'DP-2', first: 6, active: 8 },
];
const wsMenu = al.workspaceMenu(wsSnapshot(WS, 5, 'DP-1', [1, 2, 3, 6]));
check('wsmenu/labels',
      wsMenu.filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1', 'DP-2']);
check('wsmenu/absolute',
      wsMenu.filter(i => i.id === 'workspace').map(i => i.workspace),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
check('wsmenu/texts',
      wsMenu.filter(i => i.id === 'workspace').map(i => i.text),
      ['Workspace 1', 'Workspace 2', 'Workspace 3 (current)', 'Workspace 4', 'Workspace 5',
       'Workspace 6', 'Workspace 7', 'Workspace 8 (current)', 'Workspace 9', 'Workspace 10']);
check('wsmenu/hints',
      wsMenu.filter(i => i.id === 'workspace').map(i => i.hint),
      ['ctrl 1', 'ctrl 2', 'ctrl 3', 'ctrl 4', 'ctrl 5',
       'ctrl 6', 'ctrl 7', 'ctrl 8', 'ctrl 9', 'ctrl 0']);
check('wsmenu/current',
      wsMenu.filter(i => i.current).map(i => i.workspace),
      [3, 8]);
check('wsmenu/occupied',
      wsMenu.filter(i => i.id === 'workspace').map(i => i.occupied),
      [true, true, true, false, false, true, false, false, false, false]);
const wsAnchorSecond = al.workspaceMenu(wsSnapshot(WS, 5, 'DP-2', [1, 2, 3, 6]));
check('wsmenu/anchor-first',
      wsAnchorSecond.filter(i => i.kind === 'label').map(i => i.text),
      ['DP-2', 'DP-1']);
check('wsmenu/all-hinted',
      wsAnchorSecond.filter(i => i.hint !== '').map(i => i.workspace),
      [6, 7, 8, 9, 10, 1, 2, 3, 4, 5]);
check('wsmenu/new-id', wsMenu[wsMenu.length - 1].id, 'workspace-new');
check('wsmenu/new-workspace', wsMenu[wsMenu.length - 1].workspace, 4);
check('wsmenu/new-separator', wsMenu[wsMenu.length - 2].kind, 'separator');
check('wsmenu/full-hides-new',
      al.workspaceMenu(wsSnapshot(WS, 5, 'DP-1', [1, 2, 3, 4, 5])).some(i => i.id === 'workspace-new'), false);
check('wsmenu/new-from-anchor',
      al.workspaceMenu(wsSnapshot(WS, 5, 'DP-2', [1, 2, 3, 4, 5])).slice(-1)[0].workspace, 6);
check('wsmenu/other-block-does-not-free-anchor',
      al.workspaceMenu(wsSnapshot(WS, 5, 'DP-2', [6, 7, 8, 9, 10])).some(i => i.id === 'workspace-new'), false);
check('wsmenu/single-labels',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1'))
        .filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('wsmenu/single-count',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1'))
        .filter(i => i.id === 'workspace').length,
      5);
check('wsmenu/disabled-excluded',
      al.workspaceMenu(wsSnapshot([
        { name: 'DP-1', first: 1, active: 1 },
        { name: 'DP-2', first: 6, active: 6, disabled: true },
      ], 5, 'DP-1')).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('wsmenu/disabled-not-ordered',
      al.workspaceMenu(wsSnapshot([
        { name: 'DP-1', first: 1, active: 1 },
        { name: 'DP-2', first: 6, active: 6, disabled: true },
      ], 5, 'DP-1')).filter(i => i.id === 'workspace').map(i => i.workspace),
      [1, 2, 3, 4, 5]);
check('wsmenu/no-hint-over-9',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 1 }], 12, 'DP-1'))
        .filter(i => i.id === 'workspace' && i.hint === '').length,
      2);
check('wsmenu/no-monitors', al.workspaceMenu(wsSnapshot([], 5, '')), []);
check('wsmenu/zero-count', al.workspaceMenu(wsSnapshot(WS, 0, 'DP-1')), []);
check('wsmenu/bad-first',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 0, active: 1 }], 5, 'DP-1')).length, 0);

// Duplicate toplevel workspace ids collapse into one occupied set, a window
// with no workspace occupies nothing, and an active id that names no known
// monitor reads as -1, so no slot is labelled current.
check('wsmenu/duplicate-toplevels',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 9 }], 5, 'DP-1', [1, 1, 2, 2]))
        .filter(i => i.id === 'workspace').map(i => i.occupied),
      [true, true, false, false, false]);
check('wsmenu/duplicates-do-not-fill',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 9 }], 5, 'DP-1', [1, 1, 1, 1, 1]))
        .slice(-1)[0].workspace,
      2);
check('wsmenu/null-workspace',
      al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 9 }], 5, 'DP-1', [null, 3]))
        .filter(i => i.id === 'workspace').map(i => i.occupied),
      [false, false, true, false, false]);
check('wsmenu/unknown-active',
      al.workspaceMenu({
        orderedNames: ['DP-1'],
        enabledNames: ['DP-1'],
        firstWorkspaces: [{ name: 'DP-1', first: 1 }],
        hyprMonitors: [{ name: 'HDMI-A-1', activeWorkspaceId: 4 }],
        toplevelWorkspaceIds: [],
        perMonitor: 5,
        anchorName: 'DP-1'
      }).filter(i => i.current),
      []);

// An all-disabled monitor list still offers the anchor block: the fallback
// carries the anchor's first workspace and known active id, so "Open on
// workspace" survives a startup poll gap. The first ordered monitor anchors the
// menu when the anchor name is empty or names no enabled monitor, and a
// disabled anchor yields to the first enabled monitor.
const wsAllDisabled = [
  { name: 'DP-1', first: 1, active: 1, disabled: true },
  { name: 'DP-2', first: 6, active: 7, disabled: true },
];
const wsFallback = al.workspaceMenu(wsSnapshot(wsAllDisabled, 5, 'DP-2', [6]));
check('wsmenu/fallback-labels',
      wsFallback.filter(i => i.kind === 'label').map(i => i.text),
      ['DP-2']);
check('wsmenu/fallback-workspaces',
      wsFallback.filter(i => i.id === 'workspace').map(i => i.workspace),
      [6, 7, 8, 9, 10]);
check('wsmenu/fallback-current',
      wsFallback.filter(i => i.current).map(i => i.workspace),
      [7]);
check('wsmenu/fallback-hints',
      wsFallback.filter(i => i.id === 'workspace').map(i => i.hint),
      ['ctrl 6', 'ctrl 7', 'ctrl 8', 'ctrl 9', 'ctrl 0']);
check('wsmenu/fallback-new', wsFallback[wsFallback.length - 1].workspace, 7);
check('wsmenu/fallback-first-ordered',
      al.workspaceMenu(wsSnapshot(wsAllDisabled, 5, ''))
        .filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('wsmenu/fallback-anchor-only',
      al.workspaceMenu(wsSnapshot([], 5, 'eDP-1'))
        .filter(i => i.id === 'workspace').map(i => i.workspace),
      [1, 2, 3, 4, 5]);
check('wsmenu/fallback-no-name',
      al.workspaceMenu(wsSnapshot([], 5, '')).filter(i => i.current),
      []);
check('wsmenu/no-anchor-labels',
      al.workspaceMenu(wsSnapshot(WS, 5, '')).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1', 'DP-2']);
check('wsmenu/no-anchor-hints',
      al.workspaceMenu(wsSnapshot(WS, 5, '')).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
check('wsmenu/stray-anchor-labels',
      al.workspaceMenu(wsSnapshot(WS, 5, 'HDMI-A-1')).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1', 'DP-2']);
check('wsmenu/stray-anchor-hints',
      al.workspaceMenu(wsSnapshot(WS, 5, 'HDMI-A-1')).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
check('wsmenu/disabled-anchor-falls-to-first',
      al.workspaceMenu(wsSnapshot([
        { name: 'DP-1', first: 1, active: 1 },
        { name: 'DP-2', first: 6, active: 6, disabled: true },
      ], 5, 'DP-2')).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5]);

// menuItems with workspace items gains Open on workspace right after Open,
// carrying the submenu; without them the item list is unchanged.
const wsItems = al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1'));
const wsMenuItems = al.menuItems(noActions, false, false, 0, wsItems);
check('menu/workspace-after-open',
      wsMenuItems.filter(i => i.kind === 'item').map(i => i.id).indexOf('open-workspace'),
      wsMenuItems.filter(i => i.kind === 'item').map(i => i.id).indexOf('open') + 1);
check('menu/workspace-submenu',
      wsMenuItems.find(i => i.id === 'open-workspace').submenu.length,
      wsItems.length);
check('menu/workspace-absent',
      al.menuItems(noActions, false, false, 0).some(i => i.id === 'open-workspace'), false);

// shellQuote/shellCommand: Hyprland runs the dispatched command through
// /bin/sh -c, so every argv element is wrapped in single quotes — spaces stay
// one argument and shell metacharacters stay literal — and an embedded quote
// breaks out and rejoins. empty argv joins to nothing.
check('quote/plain', al.shellQuote('firefox'), "'firefox'");
check('quote/space', al.shellQuote('C:\\a b\\x.lnk'), "'C:\\a b\\x.lnk'");
check('quote/single', al.shellQuote("it's"), "'it'\\''s'");
check('quote/subshell', al.shellQuote('$(id)'), "'$(id)'");
check('quote/backticks', al.shellQuote('`id`'), "'`id`'");
check('quote/semicolon', al.shellQuote('a;b'), "'a;b'");
check('quote/ampersand', al.shellQuote('a&b'), "'a&b'");
check('quote/redirect', al.shellQuote('a<b>c'), "'a<b>c'");
check('quote/empty', al.shellQuote(''), "''");
check('quote/newline', al.shellQuote('a\nb'), "'a\nb'");
check('command/argv',
      al.shellCommand(['wine', 'C:\\a b\\x.lnk']),
      "'wine' 'C:\\a b\\x.lnk'");
check('command/empty-argv', al.shellCommand([]), '');

// terminalArgv: trim the configured terminal, split on whitespace, and fall to
// an empty argv for a blank or non-string value.
check('terminal/kitty', al.terminalArgv('kitty -e'), ['kitty', '-e']);
check('terminal/trim', al.terminalArgv('  foot  '), ['foot']);
check('terminal/empty', al.terminalArgv(''), []);
check('terminal/undefined', al.terminalArgv(undefined), []);
check('terminal/wezterm', al.terminalArgv('wezterm start --').length, 3);

// The composed dispatch string: shell-join then Lua-escape; backslashes double
// once and the quotes stay single.
check('quote/composed-lua',
      ml.escapeLua(al.shellCommand(['wine', 'C:\\a b\\x.lnk'])),
      "'wine' 'C:\\\\a b\\\\x.lnk'");
check('lua/newline', ml.escapeLua('a\nb'), 'a\\nb');
check('lua/cr', ml.escapeLua('a\rb'), 'a\\rb');

// qmljs String.prototype.arg follows Qt's rule: each call replaces the
// lowest-numbered remaining %N, so chained args fill placeholders by number.
const arg = al.qmlArg;
check('arg/qt-rule',
      arg.call(arg.call('Kill %1 (%2 windows)', 'Firefox'), 3),
      'Kill Firefox (3 windows)');
check('arg/order', arg.call(arg.call('%2 then %1', 'a'), 'b'), 'b then a');
check('arg/marker-not-prefix', arg.call('%10 %1', 'x'), '%10 x');

// menuGlyphKey: every top-level item the menu can emit names a glyph property,
// and every non-empty key (submenu included) exists in Icons.qml, so a missing
// glyph fails here instead of rendering an empty slot. The submenu covers the
// new, current, occupied, and plain workspace items.
const iconNames = (iconsSrc.match(/readonly property string (\w+)/g) || [])
    .map(s => s.replace('readonly property string ', ''));
const glyphWs = al.workspaceMenu(wsSnapshot([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1', [3]));
const glyphSource = al.menuItems(noActions, false, false, 0)
    .concat(al.menuItems(noActions, true, false, 2))
    .concat(al.menuItems(withActions, false, false, 2))
    .concat(al.menuItems(null, false, true))
    .concat(al.menuItems(noActions, false, false, 2, glyphWs));
const topItems = glyphSource.filter(i => i.kind === 'item' && i.id.indexOf('action:') !== 0);
check('glyph/top-nonempty',
      topItems.length > 0 && topItems.every(i => al.menuGlyphKey(i) !== ''),
      true);
const glyphKeys = glyphSource.filter(i => i.kind === 'item').map(i => al.menuGlyphKey(i))
    .concat(glyphWs.map(i => al.menuGlyphKey(i)));
check('glyph/keys-known', glyphKeys.every(k => k === '' || iconNames.indexOf(k) !== -1), true);
check('glyph/submenu-exercised',
      ['workspace-new', 'workspace'].every(id => glyphWs.some(i => i.id === id))
          && glyphWs.some(i => i.current) && glyphWs.some(i => i.occupied)
          && glyphWs.some(i => i.id === 'workspace' && !i.current && !i.occupied),
      true);
check('glyph/open', al.menuGlyphKey({ id: 'open' }), 'open');
check('glyph/open-keep', al.menuGlyphKey({ id: 'open-keep' }), 'openInApp');
check('glyph/pin', al.menuGlyphKey({ id: 'pin' }), 'starOutline');
check('glyph/unpin', al.menuGlyphKey({ id: 'unpin' }), 'star');
check('glyph/hide', al.menuGlyphKey({ id: 'hide' }), 'eyeOff');
check('glyph/copy-command', al.menuGlyphKey({ id: 'copy-command' }), 'copy');
check('glyph/run', al.menuGlyphKey({ id: 'run' }), 'terminal');
check('glyph/focus-window', al.menuGlyphKey({ id: 'focus-window' }), 'focus');
check('glyph/kill', al.menuGlyphKey({ id: 'kill' }), 'close');
check('glyph/open-workspace', al.menuGlyphKey({ id: 'open-workspace' }), 'workspace');
check('glyph/workspace-new', al.menuGlyphKey({ id: 'workspace-new' }), 'plus');
check('glyph/workspace-current',
      al.menuGlyphKey({ id: 'workspace', current: true, occupied: true }), 'circle');
check('glyph/workspace-occupied',
      al.menuGlyphKey({ id: 'workspace', current: false, occupied: true }), 'circleOutline');
check('glyph/workspace-plain',
      al.menuGlyphKey({ id: 'workspace', current: false, occupied: false }), '');
check('glyph/action-none', al.menuGlyphKey({ id: 'action:0' }), '');
check('glyph/null', al.menuGlyphKey(null), '');

// menuAction: the id-to-service table. Every item maps to one AppService call
// with the row's record, the submenu item carries its absolute workspace, the
// run row copies its query, and a separator, label, or unknown id is a no-op.
const runRow = { kind: 'run', query: 'zzzz' };
const appRow = { kind: 'app', record: noActions };
const wsItem = glyphWs.find(i => i.id === 'workspace');
const wsNew = glyphWs.find(i => i.id === 'workspace-new');
const actionCases = [
  ['open', { kind: 'item', id: 'open' }, appRow, { op: 'launch', args: [noActions, false] }],
  ['open-keep', { kind: 'item', id: 'open-keep' }, appRow, { op: 'launchKeep', args: [noActions] }],
  ['open-workspace', { kind: 'item', id: 'open-workspace' }, appRow, null],
  ['workspace', wsItem, appRow, { op: 'launchOnWorkspace', args: [noActions, wsItem.workspace, false] }],
  ['workspace-new', wsNew, appRow, { op: 'launchOnWorkspace', args: [noActions, wsNew.workspace, false] }],
  ['pin', { kind: 'item', id: 'pin' }, appRow, { op: 'togglePin', args: ['firefox.desktop'] }],
  ['unpin', { kind: 'item', id: 'unpin' }, appRow, { op: 'togglePin', args: ['firefox.desktop'] }],
  ['hide', { kind: 'item', id: 'hide' }, appRow, { op: 'hide', args: ['firefox.desktop'] }],
  ['run', { kind: 'item', id: 'run' }, runRow, { op: 'runQuery', args: ['zzzz'] }],
  ['focus-window', { kind: 'item', id: 'focus-window' }, appRow, { op: 'focusWindows', args: [noActions] }],
  ['kill', { kind: 'item', id: 'kill' }, appRow, { op: 'killWindows', args: [noActions] }],
  ['copy-command-app', { kind: 'item', id: 'copy-command' }, appRow, { op: 'copyCommand', args: [noActions] }],
  ['copy-command-run', { kind: 'item', id: 'copy-command' }, runRow, { op: 'copyText', args: ['zzzz'] }],
  ['action', { kind: 'item', id: 'action:1', actionIndex: 1 }, appRow, { op: 'launchAction', args: [noActions, 1] }],
];
for (const c of actionCases)
  check('action/' + c[0], al.menuAction(c[1], c[2]), c[3]);
check('action/null-item', al.menuAction(null, appRow), null);
check('action/null-row', al.menuAction({ kind: 'item', id: 'open' }, null), null);
check('action/separator', al.menuAction({ kind: 'separator', id: '' }, appRow), null);
check('action/label', al.menuAction({ kind: 'label', id: '', text: 'Actions' }, appRow), null);
check('action/unknown', al.menuAction({ kind: 'item', id: 'nope' }, appRow), null);

// The table's ops are the contract with the service: each must name a function
// AppService still exposes, so a rename cannot leave a dead menu item.
const actionOps = [];
for (const c of actionCases) {
  if (c[3] && actionOps.indexOf(c[3].op) === -1)
    actionOps.push(c[3].op);
}
check('action/ops', actionOps.slice().sort(),
      ['copyCommand', 'copyText', 'focusWindows', 'hide', 'killWindows', 'launch',
       'launchAction', 'launchKeep', 'launchOnWorkspace', 'runQuery', 'togglePin']);
for (const op of actionOps)
  check('action/op-fn-' + op, new RegExp('function ' + op + '\\(').test(svcSrc), true);
NODEEOF

# --- 6. smooth-wheel math runs under node ---
node - "$ROOT/tests/qmljs.js" "$ROOT/components/SmoothWheelLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('smooth-wheel');
const sl = qmljs.load(process.argv[3]);

// clampTarget: inside the bounds passes through, past either edge clamps, a
// short list pins to originY, and a non-numeric target falls to originY.
check('clamp/inside', sl.clampTarget(0, 1000, 200, 300), 300);
check('clamp/top', sl.clampTarget(0, 1000, 200, -50), 0);
check('clamp/bottom', sl.clampTarget(0, 1000, 200, 5000), 800);
check('clamp/no-overflow', sl.clampTarget(0, 150, 200, 400), 0);
check('clamp/origin-low', sl.clampTarget(-100, 1000, 200, -5000), -100);
check('clamp/origin-high', sl.clampTarget(-100, 1000, 200, 5000), 700);
check('clamp/nan', sl.clampTarget(0, 1000, 200, NaN), 0);
check('clamp/undefined', sl.clampTarget(0, 1000, 200, undefined), 0);

// wheelTarget: the raw notch step — a notch down (negative angleDelta)
// increases contentY, a notch up decreases it — before any bound is applied.
check('wheel/down', sl.wheelTarget(0, -120, 144), 144);
check('wheel/up', sl.wheelTarget(144, 120, 144), 0);
check('wheel/undefined-from', sl.wheelTarget(undefined, -120, 144), 144);

// wheelMode: pick the path by scroll phase. A discrete wheel (isContinuous
// false) steps on angleDelta even when Wayland also attaches a pixelDelta; a
// continuous source (isContinuous true) takes the pixel path even with a small
// angleDelta; an event with no usable delta is "none".
check('mode/wheel-angle', sl.wheelMode(120, 15, false), 'angle');
check('mode/wheel-coalesced', sl.wheelMode(600, 15, false), 'angle');
check('mode/continuous-pixel', sl.wheelMode(0, 12, true), 'pixel');
check('mode/continuous-small-angle', sl.wheelMode(8, 3, true), 'pixel');
check('mode/pixel-fallback', sl.wheelMode(0, 15, false), 'pixel');
check('mode/continuous-no-pixel-angle', sl.wheelMode(120, 0, true), 'angle');
check('mode/none', sl.wheelMode(0, 0, true), 'none');
check('mode/none-unknown', sl.wheelMode(0, 0, false), 'none');

// isContinuousPhase: the pure phase decision. Every non-NoScrollPhase value is
// continuous, NoScrollPhase is not, and a missing or non-numeric phase is not
// (so a malformed event falls back to the stepped path).
check('phase/discrete', sl.isContinuousPhase(0, 0), false);
check('phase/begin', sl.isContinuousPhase(1, 0), true);
check('phase/update', sl.isContinuousPhase(2, 0), true);
check('phase/end', sl.isContinuousPhase(3, 0), true);
check('phase/momentum', sl.isContinuousPhase(4, 0), true);
check('phase/missing', sl.isContinuousPhase(undefined, 0), false);
check('phase/nan', sl.isContinuousPhase(NaN, 0), false);

// wheelStep: the composed decision. It seeds from the in-flight target while
// the glide runs and from contentY otherwise, clamps against the view bounds,
// and reports whether the position actually moves so the caller leaves the
// event unaccepted at a pinned edge or on a view that does not overflow.
// Bounds 0..800 model a 1000-high content in a 200 view.
check('step/inside', sl.wheelStep(0, 0, false, -120, 144, 0, 800), { target: 144, moved: true });
check('step/accumulate', sl.wheelStep(0, 144, true, -120, 144, 0, 800), { target: 288, moved: true });
check('step/running-seeds-target', sl.wheelStep(50, 144, true, 120, 144, 0, 800), { target: 0, moved: true });
check('step/bottom-clamp', sl.wheelStep(700, 700, false, -120, 144, 0, 800), { target: 800, moved: true });
check('step/top-clamp', sl.wheelStep(50, 50, false, 120, 144, 0, 800), { target: 0, moved: true });
check('step/reverse-after-overshoot', sl.wheelStep(800, 800, false, 120, 144, 0, 800), { target: 656, moved: true });
check('step/pinned-bottom', sl.wheelStep(800, 800, false, -120, 144, 0, 800), { target: 800, moved: false });
check('step/pinned-top', sl.wheelStep(0, 0, false, 120, 144, 0, 800), { target: 0, moved: false });
check('step/no-overflow', sl.wheelStep(0, 0, false, -120, 144, 0, 0), { target: 0, moved: false });
check('step/running-pinned', sl.wheelStep(0, 800, true, -120, 144, 0, 800), { target: 800, moved: false });

// The step scales by |angleDelta| / 120 against the caller's step (240 live):
// one notch moves one step, a 240 delta (two coalesced notches) two, a
// high-resolution 15- or 30-unit chunk a proportional fraction, a reverse
// notch subtracts, and a scaled step still clamps and accumulates.
check('scale/notch', sl.wheelStep(0, 0, false, -120, 240, 0, 800), { target: 240, moved: true });
check('scale/two-notches', sl.wheelStep(0, 0, false, -240, 240, 0, 1200), { target: 480, moved: true });
check('scale/high-res-15', sl.wheelStep(0, 0, false, -15, 240, 0, 800), { target: 30, moved: true });
check('scale/high-res-30', sl.wheelStep(100, 100, false, 30, 240, 0, 800), { target: 40, moved: true });
check('scale/reverse', sl.wheelStep(480, 480, false, 120, 240, 0, 800), { target: 240, moved: true });
check('scale/accumulate', sl.wheelStep(0, 240, true, -120, 240, 0, 800), { target: 480, moved: true });
check('scale/bottom-clamp', sl.wheelStep(700, 700, false, -240, 240, 0, 800), { target: 800, moved: true });
check('scale/top-clamp', sl.wheelStep(10, 10, false, 30, 240, 0, 800), { target: 0, moved: true });
NODEEOF

echo "app-launcher: all ok"
