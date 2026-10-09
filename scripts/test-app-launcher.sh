#!/usr/bin/env bash
# Headless gate for the app launcher (tickets 02-03).
#
# A full QML boot needs a compositor, so this gate does not boot one. It
# checks two things that run anywhere:
#   1. structural assertions over the QML: AppService holds the pure logic in
#      AppLogic.js as one-line delegates, persists to the app-launcher state
#      file, launches terminal entries through the kitty prefix, the view
#      builds highlighted rows from the ranked sections, Escape reaches the
#      search input past the panel Shortcut, stale queries reset on open,
#      section headers paint no tile, and the context menu is generic while
#      the view wires right-click, Right/Menu, hide, actions, and copy;
#   2. node runs of the shipped pure logic (ranking, match ranges, markup,
#      section building, hidden filtering, recent/pin/hide/unhide mutation,
#      menu building, state parsing) through tests/qmljs.js, so a broken
#      AppLogic.js fails the gate instead of a mirror that cannot drift.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "app-launcher FAIL: $*" >&2; exit 1; }

LOGIC="$ROOT/services/AppLogic.js"
SVC="$ROOT/services/AppService.qml"
VIEW="$ROOT/windows/DashboardAppsView.qml"

# --- 1. pure logic lives in AppLogic.js behind one-line AppService delegates ---
test -f "$LOGIC" \
    || fail "services/AppLogic.js is missing"
grep -q '^\.pragma library' "$LOGIC" \
    || fail "AppLogic.js is not a .pragma library"
grep -q '^import "AppLogic.js" as AppLogic' "$SVC" \
    || fail "AppService does not import AppLogic.js"
for fn in rank matchRanges sections browseRows resultRows parseState recordLaunch togglePin visibleEntries hide unhide resolveHidden menuItems shellQuote shellCommand makeRecords runningCounts; do
    grep -q "function $fn" "$LOGIC" \
        || fail "AppLogic.js has no $fn"
    grep -q "AppLogic.$fn" "$SVC" \
        || fail "AppService does not delegate $fn to AppLogic"
done
grep -q 'function markup' "$LOGIC" \
    || fail "AppLogic.js has no markup helper"
grep -q 'AppLogic.markup' "$SVC" \
    || fail "AppService does not delegate markup to AppLogic"
grep -q 'function escapeHtml' "$LOGIC" \
    || fail "AppLogic.js has no escapeHtml helper"

# --- 2. persistence, launch, and terminal prefix ---
grep -q 'name: "app-launcher"' "$SVC" \
    || fail "AppService does not persist to the app-launcher state file"
grep -q 'readonly property var terminalPrefix: \["kitty", "-e"\]' "$SVC" \
    || fail "AppService terminal prefix is not kitty -e"
grep -q 'Quickshell.execDetached' "$SVC" \
    || fail "AppService does not launch through execDetached"
grep -q 'record.runInTerminal' "$SVC" \
    || fail "AppService ignores runInTerminal"
grep -q 'Quickshell.iconPath' "$SVC" \
    || fail "AppService has no iconPath lookup"
grep -q 'root.iconCache' "$SVC" \
    || fail "AppService icon lookups are not cached"
grep -q 'onEntriesChanged: root.iconCache = ({})' "$SVC" \
    || fail "AppService does not clear the icon cache when the snapshot changes"
grep -q 'DesktopEntries.applications.values' "$SVC" \
    || fail "AppService does not snapshot DesktopEntries.applications"
grep -q 'entry.execute()' "$SVC" \
    || fail "AppService launch does not execute the entry"
grep -q 'DashboardService.close()' "$SVC" \
    || fail "AppService launch does not close the dashboard"

# --- 3. tokens: selection role, icon size, tile ink, star and terminal glyphs ---
grep -q 'property color selection' "$ROOT/config/Colors.qml" \
    || fail "Colors has no selection role"
grep -q 'property color tileInk' "$ROOT/config/Colors.qml" \
    || fail "Colors has no tileInk role"
grep -q 'Colors.tileInk' "$ROOT/components/AppIcon.qml" \
    || fail "AppIcon does not paint the letter tile with tileInk"
grep -q 'Colors.tileInk' "$ROOT/components/ContextMenu.qml" \
    || fail "ContextMenu header tile does not paint with tileInk"
grep -q 'contrastRatio(root.accent, root.background) < 3' "$ROOT/config/Colors.qml" \
    || fail "Colors.selection does not branch on accent contrast"
grep -q 'appIconSize' "$ROOT/config/Globals.qml" \
    || fail "Globals has no appIconSize token"
grep -q 'property string star' "$ROOT/config/Icons.qml" \
    || fail "Icons.qml has no star glyph"
grep -q 'property string terminal' "$ROOT/config/Icons.qml" \
    || fail "Icons.qml has no terminal glyph"

# --- 4. the view renders highlighted rows plus the run fallback ---
grep -q 'AppService.browseRows' "$VIEW" \
    || fail "DashboardAppsView does not build the browse rows through AppService"
grep -q 'AppService.resultRows' "$VIEW" \
    || fail "DashboardAppsView does not build the result rows through AppService"
grep -q 'AppService.markup' "$VIEW" \
    || fail "DashboardAppsView does not highlight matched characters"
grep -q 'AppService.runQuery' "$VIEW" \
    || fail "DashboardAppsView has no Run-query row"
grep -q 'Colors.selection' "$VIEW" \
    || fail "DashboardAppsView does not use the selection fill"
grep -q 'Globals.appRailWidth' "$VIEW" \
    || fail "DashboardAppsView does not draw the selection rail"
grep -q 'Globals.appIconSize' "$VIEW" \
    || fail "DashboardAppsView does not size the row icon from Globals"
grep -q 'Icons.star' "$VIEW" \
    || fail "DashboardAppsView does not mark pinned rows with the star"
grep -q 'Globals.reducedMotion' "$VIEW" \
    || fail "DashboardAppsView ignores reduced motion"
for key in Qt.Key_Up Qt.Key_Down Qt.Key_PageUp Qt.Key_PageDown Qt.Key_Tab Qt.Key_Return \
    Qt.AltModifier Qt.Key_P Qt.ControlModifier Qt.Key_Escape Qt.Key_Backtab; do
    grep -q "$key" "$VIEW" \
        || fail "DashboardAppsView missed the $key key"
done
grep -q 'Qt.MiddleButton' "$VIEW" \
    || fail "DashboardAppsView does not keep the dashboard on middle-click"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$VIEW" "$SVC"; then
    fail "app launcher carries raw hex; palette tokens only"
fi

# --- 4b. Esc reaches the view and stale query resets on open ---
grep -q 'Keys.onShortcutOverride' "$VIEW" \
    || fail "search input does not override the Escape shortcut"
grep -qF 'event.key === Qt.Key_Escape && root.query !== ""' "$VIEW" \
    || fail "Escape override does not gate on a non-empty query"
grep -q 'function resetSearch' "$VIEW" \
    || fail "DashboardAppsView has no resetSearch"
grep -q 'root.resetSearch()' "$VIEW" \
    || fail "DashboardAppsView never resets the search on open"

# --- 4c. header and app row are exclusive Loader subtrees; actions load on
# the active row only; the reserved trailing width never reflows ---
grep -q 'active: idAppRow.isHeader' "$VIEW" \
    || fail "the header subtree is not gated to header rows"
grep -q 'active: !idAppRow.isHeader' "$VIEW" \
    || fail "the app row subtree is not created exclusively"
grep -q 'active: idAppRow.actionsActive' "$VIEW" \
    || fail "the inline actions are not created only for the active row"
grep -q 'readonly property real actionsWidth' "$VIEW" \
    || fail "the view does not reserve a fixed actions width"
grep -q 'Layout.preferredWidth: root.actionsWidth' "$VIEW" \
    || fail "the trailing actions width is not reserved from a constant"
if grep -q 'idAppRowActions.implicitWidth' "$VIEW"; then
    fail "the trailing width still collapses to the instantiated actions"
fi
grep -q 'reuseItems: true' "$VIEW" \
    || fail "the app list does not reuse delegates"
grep -q 'ListView.onReused' "$VIEW" \
    || fail "reused delegates do not reset their per-row state"
REUSED_BLOCK="$(awk '/ListView.onReused/{flag=1} flag{print} flag && /^[[:space:]]*\}$/{exit}' "$VIEW")"
test -n "$REUSED_BLOCK" || fail "could not extract the ListView.onReused handler"
echo "$REUSED_BLOCK" | grep -q 'idAppRow.killTipShown = false' \
    || fail "the onReused handler does not reset the kill tooltip state"
if echo "$REUSED_BLOCK" | grep -q 'rowHovered'; then
    fail "the onReused handler clears rowHovered instead of following the pointer"
fi
grep -q 'value: idAppRowMouse.containsMouse' "$VIEW" \
    || fail "row hover is not derived from the row MouseArea's containsMouse"
grep -q 'info.record' "$VIEW" \
    || fail "the delegate does not read the row record"
if grep -q 'info\.entry' "$VIEW"; then
    fail "the delegate still reads the removed info.entry"
fi
grep -q 'record: section.items\[i\]' "$LOGIC" \
    || fail "the row-building helper does not carry the app record"

# --- 4d. shared context menu plus launcher wiring ---
CTX="$ROOT/components/ContextMenu.qml"
test -f "$CTX" \
    || fail "components/ContextMenu.qml is missing"
grep -q 'signal triggered' "$CTX" \
    || fail "ContextMenu does not report a triggered item"
grep -q 'property var items' "$CTX" \
    || fail "ContextMenu has no item model"
grep -q 'property var header' "$CTX" \
    || fail "ContextMenu has no header"
grep -q 'Colors.danger' "$CTX" \
    || fail "ContextMenu has no danger style"
grep -q 'submenu' "$CTX" \
    || fail "ContextMenu has no submenu"
grep -qF 'root.opened && event.key === Qt.Key_Escape' "$CTX" \
    || fail "ContextMenu does not override the panel Escape shortcut"
grep -q 'Icons.chevronRight' "$CTX" \
    || fail "ContextMenu does not mark submenus with a chevron"
grep -q 'Globals.reducedMotion' "$CTX" \
    || fail "ContextMenu ignores reduced motion"
grep -q 'Globals.menuWidth' "$CTX" \
    || fail "ContextMenu does not use the menu width token"
for key in Qt.Key_Down Qt.Key_Up Qt.Key_Right Qt.Key_Left Qt.Key_Return; do
    grep -q "$key" "$CTX" \
        || fail "ContextMenu missed the $key key"
done
CTX_HANDLE="$(awk '/^    function handleKey/{flag=1} flag{print} flag && /^    \}$/{exit}' "$CTX")"
test -n "$CTX_HANDLE" || fail "could not extract ContextMenu.handleKey"
echo "$CTX_HANDLE" | grep -A5 'event.key === Qt.Key_Left' | grep -q 'root.leaveSubmenu()' \
    || fail "Left inside a submenu does not return to the parent menu"
echo "$CTX_HANDLE" | grep -A5 'event.key === Qt.Key_Left' | grep -q 'root.closeMenu()' \
    || fail "Left on the top level does not close the menu"

grep -q 'ContextMenu' "$VIEW" \
    || fail "DashboardAppsView does not mount the context menu"
grep -q 'Qt.RightButton' "$VIEW" \
    || fail "DashboardAppsView does not open the menu on right-click"
grep -q 'Qt.Key_Menu' "$VIEW" \
    || fail "DashboardAppsView does not open the menu on the Menu key"
if grep -q 'Qt.Key_F10' "$VIEW"; then
    fail "DashboardAppsView still opens the menu on Shift+F10"
fi
grep -q 'Qt.Key_Right' "$VIEW" \
    || fail "DashboardAppsView does not open the menu on the Right key"
grep -qF 'idAppsSearch.cursorPosition === idAppsSearch.length' "$VIEW" \
    || fail "Right does not gate on the search cursor being at the end"
grep -q 'AppService.hide' "$VIEW" \
    || fail "DashboardAppsView does not hide entries"
grep -q 'AppService.launchAction' "$VIEW" \
    || fail "DashboardAppsView does not run desktop actions"
grep -q 'AppService.copyCommand' "$VIEW" \
    || fail "DashboardAppsView does not copy the launch command"

# --- 4e. menu fits the card without growing it, and forwards typed text ---
grep -q 'acceptedButtons: Qt.AllButtons' "$CTX" \
    || fail "ContextMenu scrim does not accept every mouse button"
grep -q 'signal typedText' "$CTX" \
    || fail "ContextMenu does not forward printable text"
grep -q 'root.availableHeight' "$CTX" \
    || fail "ContextMenu does not cap its height to the view"
grep -q 'idMenuList' "$CTX" \
    || fail "ContextMenu item column is not scrollable"
grep -q 'property int menuMaxWidth' "$ROOT/config/Globals.qml" \
    || fail "Globals has no menuMaxWidth token"
grep -q 'Globals.menuMaxWidth' "$CTX" \
    || fail "ContextMenu does not cap its width to the max token"
grep -q 'FontMetrics' "$CTX" \
    || fail "ContextMenu does not measure its item text"
for fn in itemWidth fittedWidth measureWidths; do
    grep -q "function $fn" "$CTX" \
        || fail "ContextMenu has no $fn"
done
grep -qF 'onItemsChanged: root.measureWidths()' "$CTX" \
    || fail "ContextMenu does not remeasure its width when the items change"
grep -q 'root.mainWidth' "$CTX" \
    || fail "ContextMenu does not size the main menu from its content"
grep -q 'root.submenuWidth' "$CTX" \
    || fail "ContextMenu does not size the submenu from its content"
CTX_MEASURE="$(awk '/^    function measureWidths/{flag=1} flag{print} flag && /^    \}$/{exit}' "$CTX")"
test -n "$CTX_MEASURE" || fail "could not extract ContextMenu.measureWidths"
echo "$CTX_MEASURE" | grep -qF 'root.mainWidth = root.fittedWidth(root.items)' \
    || fail "the main menu width is not measured from its items"
echo "$CTX_MEASURE" | grep -qF 'root.submenuWidth = widest' \
    || fail "the submenu width is not measured from its items"
CTX_WIDTH="$(awk '/^    function itemWidth/{flag=1} flag{print} flag && /^    \}$/{exit}' "$CTX")"
test -n "$CTX_WIDTH" || fail "could not extract ContextMenu.itemWidth"
echo "$CTX_WIDTH" | grep -qF '2 * Globals.menuMargin' \
    || fail "the menu width does not account for the column margins"
echo "$CTX_WIDTH" | grep -q 'Globals.menuGlyphWidth' \
    || fail "the menu width does not reserve the glyph column"
echo "$CTX_WIDTH" | grep -q 'Globals.scrollbarWidth' \
    || fail "the menu width does not reserve the scrollbar"
echo "$CTX_WIDTH" | grep -q 'Globals.rowSpacing' \
    || fail "the menu width does not reserve the label and trailing gaps"
grep -q 'onTypedText' "$VIEW" \
    || fail "DashboardAppsView does not handle forwarded text"
if grep -q 'idAppsContextMenu.anchorY\|idAppsContextMenu.contentHeight' "$VIEW"; then
    fail "DashboardAppsView still grows its height for the menu"
fi
grep -q 'implicitHeight: idAppsLayout.implicitHeight' "$VIEW" \
    || fail "DashboardAppsView height is not just the search field plus list"
grep -q 'Icons.openInApp' "$VIEW" \
    || fail "DashboardAppsView does not give open-keep its own glyph"
if grep -q 'Icons.chevronRight' "$VIEW"; then
    fail "DashboardAppsView gives iconless actions a submenu chevron"
fi

grep -q 'function hide' "$SVC" \
    || fail "AppService has no hide action"
grep -q 'AppLogic.hide' "$SVC" \
    || fail "AppService does not delegate hide to AppLogic"
grep -q 'function unhide' "$SVC" \
    || fail "AppService has no unhide action"
grep -q 'AppLogic.unhide' "$SVC" \
    || fail "AppService does not delegate unhide to AppLogic"
UNHIDE_BODY="$(awk '/^    function unhide/{flag=1} flag && /^    }$/{print; exit} flag{print}' "$SVC")"
echo "$UNHIDE_BODY" | grep -q 'setState' \
    || fail "AppService unhide does not write the shared state through setState"
grep -q 'function launchAction' "$SVC" \
    || fail "AppService has no desktop action launch"
grep -q 'function copyCommand' "$SVC" \
    || fail "AppService has no copy launch command"
grep -q 'wl-copy' "$SVC" \
    || fail "AppService does not copy through wl-copy"

for glyph in open openInApp copy eyeOff starOutline; do
    grep -q "property string $glyph" "$ROOT/config/Icons.qml" \
        || fail "Icons.qml has no $glyph glyph"
done
for token in menuWidth menuMaxWidth menuItemHeight menuMargin menuSeparatorHeight menuLabelHeight menuSubmenuGap; do
    grep -q "$token" "$ROOT/config/Globals.qml" \
        || fail "Globals has no $token token"
done

# --- 4f. running windows, inline actions, and the Focus/Kill menu items ---
grep -q 'const ENTRY_KEY_STOPLIST' "$LOGIC" \
    || fail "AppLogic.js has no entry-key stoplist constant"
for fn in entryKeys classMatches windowMatches windowIndexesFor; do
    grep -q "function $fn" "$LOGIC" \
        || fail "AppLogic.js has no $fn"
done
grep -q 'import "AppLogic.js" as AppLogic' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus does not import AppLogic.js"
grep -q 'AppLogic.classMatches' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus.classMatches is not delegated to AppLogic"
grep -q 'toplevel.wayland.appId' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus dropped the Wayland appId source"
grep -q 'function focusAddress' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus has no address focus entry point"
for fn in windowsFor runningCount focusWindows killWindows; do
    grep -q "function $fn" "$SVC" \
        || fail "AppService has no $fn"
done
grep -q 'readonly property var runningMap' "$SVC" \
    || fail "AppService has no running map"
grep -q 'Hyprland.toplevels' "$SVC" \
    || fail "AppService does not read Hyprland.toplevels"
grep -q 'AppLogic.makeRecords' "$SVC" \
    || fail "AppService does not snapshot entries through AppLogic.makeRecords"
grep -q 'AppLogic.runningCounts' "$SVC" \
    || fail "AppService does not count running windows through AppLogic.runningCounts"
BUILDRECORDS_BLOCK="$(awk '/^    function buildRecords/{flag=1} flag{print} flag && /^    \}$/{exit}' "$SVC")"
test -n "$BUILDRECORDS_BLOCK" || fail "could not extract AppService.buildRecords"
echo "$BUILDRECORDS_BLOCK" | grep -q 'index: j' \
    || fail "AppService drops the desktop action's original index"
grep -q 'AppLogic.windowIndexesFor' "$SVC" \
    || fail "AppService does not match windows through AppLogic"
grep -q 'HyprlandFocus.focusAddress' "$SVC" \
    || fail "AppService focus does not focus the matched window address"
FOCUS_BODY="$(awk '/^    function focusWindows/{flag=1} flag && /^    }$/{print; exit} flag{print}' "$SVC")"
echo "$FOCUS_BODY" | grep -q 'DashboardService.close()' \
    || fail "AppService focusWindows does not close the dashboard"
echo "$FOCUS_BODY" | grep -q 'HyprlandFocus.focusAddress' \
    || fail "AppService focusWindows does not use focusAddress"
focus_close_ln="$(echo "$FOCUS_BODY" | grep -n 'DashboardService.close()' | head -1 | cut -d: -f1)"
focus_addr_ln="$(echo "$FOCUS_BODY" | grep -n 'HyprlandFocus.focusAddress' | head -1 | cut -d: -f1)"
[ "$focus_close_ln" -lt "$focus_addr_ln" ] \
    || fail "AppService focusWindows must close the dashboard before focusing"
grep -q 'wayland' "$SVC" \
    || fail "AppService kill does not use the Wayland handle"
grep -q '\.close()' "$SVC" \
    || fail "AppService kill does not close the window"

grep -q 'IconButton' "$VIEW" \
    || fail "DashboardAppsView does not compose IconButton"
grep -q 'Icons.focus' "$VIEW" \
    || fail "DashboardAppsView has no Focus glyph"
grep -q 'Icons.more' "$VIEW" \
    || fail "DashboardAppsView has no More glyph"
grep -q 'hoverColor: Colors.danger' "$VIEW" \
    || fail "DashboardAppsView kill does not hover in Colors.danger"
grep -q 'AppService.runningCount' "$VIEW" \
    || fail "DashboardAppsView does not read the running count"
grep -q 'AppService.focusWindows' "$VIEW" \
    || fail "DashboardAppsView does not focus a running app"
grep -q 'AppService.killWindows' "$VIEW" \
    || fail "DashboardAppsView does not kill a running app"
grep -q 'Layout.preferredWidth: root.actionsWidth' "$VIEW" \
    || fail "DashboardAppsView does not reserve the trailing width"
grep -q 'Globals.tooltipDelayMs' "$VIEW" \
    || fail "DashboardAppsView kill tooltip ignores the tooltip delay"
grep -q 'idAppRow.killTipShown' "$VIEW" \
    || fail "DashboardAppsView has no kill tooltip"
grep -q 'AppService.menuItems(record, root.menuPinned, row.kind === "run"' "$VIEW" \
    || fail "DashboardAppsView menu does not pass the running count"
for id in focus-window kill; do
    grep -q "\"$id\"" "$VIEW" \
        || fail "DashboardAppsView menu does not handle $id"
done
for glyph in focus more; do
    grep -q "property string $glyph" "$ROOT/config/Icons.qml" \
        || fail "Icons.qml has no $glyph glyph"
done
grep -q 'appInlineSeparatorHeight' "$ROOT/config/Globals.qml" \
    || fail "Globals has no appInlineSeparatorHeight token"

# --- 4g. open-on-workspace: pure mapping, submenu, Ctrl+digit, Lua dispatch ---
for fn in workspaceFor workspaceKeys firstEmptyWorkspace workspaceMenu; do
    grep -q "function $fn" "$LOGIC" \
        || fail "AppLogic.js has no $fn"
done
grep -q 'AppLogic.workspaceFor' "$SVC" \
    || fail "AppService does not delegate workspaceFor to AppLogic"
grep -q 'function totalWorkspaces' "$SVC" \
    || fail "AppService has no total workspace count"
grep -q 'AppLogic.workspaceKeys' "$SVC" \
    || fail "AppService does not delegate the footer key cap to AppLogic"
grep -q 'AppLogic.workspaceMenu' "$SVC" \
    || fail "AppService does not build the workspace submenu through AppLogic"
grep -q 'function launchOnWorkspace' "$SVC" \
    || fail "AppService has no launchOnWorkspace"
LAUNCH_BODY="$(awk '/^    function launchOnWorkspace/{flag=1} flag && /^    }$/{print; exit} flag{print}' "$SVC")"
echo "$LAUNCH_BODY" | grep -q 'shellCommand' \
    || fail "AppService launchOnWorkspace does not build the command through shellCommand"
grep -q 'MonitorService.firstWorkspaceFor' "$SVC" \
    || fail "AppService workspace mapping does not use MonitorService.firstWorkspaceFor"
grep -q 'MonitorService.workspacesPerMonitor' "$SVC" \
    || fail "AppService workspace mapping does not use MonitorService.workspacesPerMonitor"
grep -q 'MonitorService.enabledMonitors' "$SVC" \
    || fail "AppService workspace menu does not filter to the enabled monitors"
grep -q 'MonitorService.orderedMonitors' "$SVC" \
    || fail "AppService workspace menu does not follow MonitorService.orderedMonitors"
grep -q 'menuItem("label"' "$LOGIC" \
    || fail "AppLogic workspace menu does not emit a monitor label"
grep -q 'Hyprland.monitors' "$SVC" \
    || fail "AppService workspace menu does not read each monitor's activeWorkspace"
grep -q 'DashboardService.anchorScreen' "$SVC" \
    || fail "AppService does not anchor workspaces to the dashboard screen"
grep -q 'Hyprland.dispatch' "$SVC" \
    || fail "AppService does not dispatch the workspace launch through Hyprland"
grep -q 'hl.dsp.exec_cmd' "$SVC" \
    || fail "AppService workspace launch is not a Lua hl.dsp.exec_cmd call"
grep -q 'workspace = ' "$SVC" \
    || fail "AppService workspace launch does not pass the workspace rule"
grep -q 'MonitorLogic.escapeLua' "$SVC" \
    || fail "AppService does not escape the Lua command string"
grep -q 'open-workspace' "$VIEW" \
    || fail "DashboardAppsView menu does not handle open-workspace"
grep -q 'submenuGlyph' "$VIEW" \
    || fail "DashboardAppsView has no submenu glyph mapping"
grep -q 'AppService.launchOnWorkspace' "$VIEW" \
    || fail "DashboardAppsView does not launch on a workspace"
grep -q 'AppService.workspaceFor' "$VIEW" \
    || fail "DashboardAppsView does not resolve the absolute workspace"
grep -q 'ctrl 0' "$LOGIC" \
    || fail "AppLogic workspaceMenu does not hint workspace 10 as ctrl 0"
grep -qF 'disabled: enabledNames.indexOf(monitorName) === -1' "$SVC" \
    || fail "AppService does not tag disabled monitors for AppLogic to filter"
grep -q 'monitor.disabled !== true' "$LOGIC" \
    || fail "AppLogic workspaceMenu does not drop disabled monitors"
grep -qF 'active: root.activeWorkspaceFor(hyprMonitors, monitorName)' "$SVC" \
    || fail "AppService does not resolve each monitor's active workspace"
grep -qF 'AppLogic.workspaceMenu(monitors, MonitorService.workspacesPerMonitor, name, occupied, fallback)' "$SVC" \
    || fail "AppService does not pass the anchor fallback to AppLogic"
grep -q 'firstWorkspaceFor(fallbackName)' "$SVC" \
    || fail "AppService does not fall back to the anchor block when no monitor is enabled"
grep -q 'anchorFallback' "$LOGIC" \
    || fail "AppLogic workspaceMenu has no anchor fallback"
RUNMENU_BLOCK="$(awk '/^    function runMenuItem/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$RUNMENU_BLOCK" || fail "could not extract runMenuItem"
echo "$RUNMENU_BLOCK" | grep -qF 'AppService.launchOnWorkspace(row.record, item.workspace, false);' \
    || fail "the submenu launch does not pass the absolute workspace directly"
if echo "$RUNMENU_BLOCK" | grep -q 'workspaceFor'; then
    fail "the submenu launch still re-resolves the workspace through workspaceFor"
fi
DIGIT_BLOCK="$(awk '/Qt.ControlModifier\) !== 0/{flag=1} flag{print} flag && /event.accepted = true/{exit}' "$VIEW")"
echo "$DIGIT_BLOCK" | grep -q 'AppService.workspaceFor' \
    || fail "Ctrl+digit branch does not resolve the absolute workspace through AppService.workspaceFor"
echo "$DIGIT_BLOCK" | grep -q 'AppService.launchOnWorkspace' \
    || fail "Ctrl+digit branch does not launch on the target workspace"
echo "$DIGIT_BLOCK" | grep -qF 'event.key - Qt.Key_0' \
    || fail "Ctrl+digit branch does not map the key to a workspace number"
if echo "$DIGIT_BLOCK" | grep -q 'slot >= 1'; then
    fail "Ctrl+digit branch still drops Ctrl+0 with a slot floor"
fi
echo "$DIGIT_BLOCK" | grep -q 'event.accepted = true' \
    || fail "Ctrl+digit branch does not consume the key"
for glyph in workspace circle circleOutline; do
    grep -q "property string $glyph" "$ROOT/config/Icons.qml" \
        || fail "Icons.qml has no $glyph glyph"
done

# --- 4h. the shared AppIcon owns the row artwork ---
grep -q 'AppIcon {' "$VIEW" \
    || fail "DashboardAppsView does not compose the shared AppIcon"
grep -q 'source: idAppRow.iconSource' "$VIEW" \
    || fail "DashboardAppsView does not feed AppIcon the resolved source"
if grep -qE '^[[:space:]]*text:.*charAt' "$VIEW"; then
    fail "DashboardAppsView still paints an inline letter tile"
fi

# --- 4i. the Apps tab grows downward, the list and menu scroll smoothly ---
DCENTER="$ROOT/windows/DashboardCenter.qml"
grep -q 'Globals.dashboardAppsMaxFraction' "$DCENTER" \
    || fail "DashboardCenter does not raise the card on the Apps tab"
grep -q 'DashboardService.anchorScreen' "$DCENTER" \
    || fail "DashboardCenter app height does not read the anchor screen"
grep -q 'Globals.dashboardMaxHeight' "$DCENTER" \
    || fail "DashboardCenter app height does not fall back to dashboardMaxHeight"
if grep -q 'appListMaxHeight' "$VIEW" "$ROOT/config/Globals.qml"; then
    fail "the app list is still capped by appListMaxHeight"
fi
for token in 'property real dashboardAppsMaxFraction: 0.8' 'property int scrollbarWidth' \
    'property int scrollbarRadius' 'property int wheelStep' 'property int wheelMs'; do
    grep -q "$token" "$ROOT/config/Globals.qml" \
        || fail "Globals has no $token token"
done
grep -q 'property int wheelStep: 240' "$ROOT/config/Globals.qml" \
    || fail "Globals.wheelStep is not 240"

# --- 4j. the Apps view is bounded by PanelShell, so the list scrolls ---
APPS_MOUNT="$(awk '/^    DashboardAppsView \{/{flag=1} flag{print} flag && /^    \}$/{exit}' "$DCENTER")"
test -n "$APPS_MOUNT" || fail "could not extract the DashboardAppsView mount"
echo "$APPS_MOUNT" | grep -q 'Layout.fillHeight: true' \
    || fail "DashboardCenter does not let the Apps view fill the height it is given"
echo "$APPS_MOUNT" | grep -q 'Layout.fillWidth: true' \
    || fail "DashboardCenter does not let the Apps view fill the width"
APPS_LAYOUT="$(awk '/^    ColumnLayout \{/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
echo "$APPS_LAYOUT" | grep -q 'id: idAppsLayout' \
    || fail "could not extract the idAppsLayout ColumnLayout"
# Only the layout's own (8-space) properties count, not nested children.
echo "$APPS_LAYOUT" | grep -qx '        anchors.fill: parent' \
    || fail "idAppsLayout does not fill the Apps view root"
if echo "$APPS_LAYOUT" | grep -qE '^        anchors( \{$|\.(top|left|right|bottom):)'; then
    fail "idAppsLayout still anchors edge by edge, so the list is never bounded"
fi

SCROLLBAR="$ROOT/components/ScrollBar.qml"
test -f "$SCROLLBAR" \
    || fail "components/ScrollBar.qml is missing"
grep -q 'import QtQuick.Controls as Controls' "$SCROLLBAR" \
    || fail "ScrollBar is not built on QtQuick.Controls"
grep -q 'Controls.ScrollBar' "$SCROLLBAR" \
    || fail "ScrollBar does not root on the Controls ScrollBar"
grep -q 'Colors.border' "$SCROLLBAR" \
    || fail "ScrollBar track is not Colors.border"
grep -q 'Colors.textSubtle' "$SCROLLBAR" \
    || fail "ScrollBar handle is not Colors.textSubtle"
grep -q 'Colors.accent' "$SCROLLBAR" \
    || fail "ScrollBar does not accent on hover or press"
grep -q 'Globals.scrollbarWidth' "$SCROLLBAR" \
    || fail "ScrollBar does not size from Globals.scrollbarWidth"
grep -q 'Globals.scrollbarRadius' "$SCROLLBAR" \
    || fail "ScrollBar does not round from Globals.scrollbarRadius"
grep -q 'root.decrease()' "$SCROLLBAR" \
    || fail "ScrollBar track does not page up"
grep -q 'root.increase()' "$SCROLLBAR" \
    || fail "ScrollBar track does not page down"
grep -q 'visible: root.size < 1' "$SCROLLBAR" \
    || fail "ScrollBar is not shown only on overflow"

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
for fn in clampTarget wheelTarget wheelStep wheelMode; do
    grep -q "function $fn" "$SMOOTHLOGIC" \
        || fail "SmoothWheelLogic.js has no $fn"
done
for fn in clampTarget wheelStep wheelMode; do
    grep -q "SmoothWheelLogic.$fn" "$SMOOTH" \
        || fail "SmoothWheel does not delegate $fn to SmoothWheelLogic"
done
grep -q 'function isContinuousScroll' "$SMOOTH" \
    || fail "SmoothWheel has no continuous-source check"
grep -q 'event.phase' "$SMOOTH" \
    || fail "SmoothWheel does not read the wheel event's scroll phase"
grep -q 'Qt.NoScrollPhase' "$SMOOTH" \
    || fail "SmoothWheel does not treat NoScrollPhase as a discrete wheel"
if grep -q 'event.device\|PointerDevice' "$SMOOTH"; then
    fail "SmoothWheel still keys the scroll path on the pointer device"
fi
if grep -qE 'function (scrollTo|setTarget)\b' "$SMOOTH"; then
    fail "SmoothWheel keeps the dead scrollTo/setTarget entry points"
fi
grep -q 'anchors.fill: root.flickable' "$SMOOTH" \
    || fail "SmoothWheel overlay does not fill its target Flickable"
grep -q 'anchors.fill: parent' "$SMOOTH" \
    || fail "SmoothWheel wheel MouseArea does not fill the overlay"
grep -q 'MouseArea {' "$SMOOTH" \
    || fail "SmoothWheel does not route the wheel through a MouseArea"
grep -q 'onWheel: wheel => {' "$SMOOTH" \
    || fail "SmoothWheel MouseArea has no wheel handler"
grep -q 'wheel.accepted = false' "$SMOOTH" \
    || fail "SmoothWheel does not leave an unhandled wheel for the parent"
grep -q 'root.handleWheel(wheel)' "$SMOOTH" \
    || fail "SmoothWheel MouseArea does not forward onWheel to handleWheel"
grep -q 'acceptedButtons: Qt.NoButton' "$SMOOTH" \
    || fail "SmoothWheel MouseArea intercepts clicks; it must take no buttons"
if grep -q 'WheelHandler' "$SMOOTH"; then
    fail "SmoothWheel still uses a WheelHandler; blocking cannot conditionally forward"
fi
grep -q 'event.pixelDelta' "$SMOOTH" \
    || fail "SmoothWheel ignores the trackpad pixelDelta"
grep -q 'event.angleDelta.y' "$SMOOTH" \
    || fail "SmoothWheel ignores the wheel angleDelta"
grep -q 'Globals.wheelStep' "$SMOOTH" \
    || fail "SmoothWheel does not step by the wheel token"
grep -q 'Globals.wheelMs' "$SMOOTH" \
    || fail "SmoothWheel does not glide for the wheel duration"
grep -q 'flickable.moving' "$SMOOTH" \
    || fail "SmoothWheel does not stop on a user drag"

# The notch decision and the move path must stay on the live path: handleWheel
# composes the pure wheelStep result and routes through moveTo, and the
# reduced-motion jump lives inside moveTo, not on unreachable code.
HANDLE_BODY="$(awk '/^    function handleWheel/{flag=1} flag && /^    }$/{print; exit} flag{print}' "$SMOOTH")"
test -n "$HANDLE_BODY" || fail "could not extract SmoothWheel.handleWheel"
echo "$HANDLE_BODY" | grep -q 'SmoothWheelLogic.wheelStep' \
    || fail "handleWheel does not compose the wheel decision in SmoothWheelLogic"
echo "$HANDLE_BODY" | grep -q 'SmoothWheelLogic.wheelMode' \
    || fail "handleWheel does not pick the scroll path through SmoothWheelLogic.wheelMode"
echo "$HANDLE_BODY" | grep -q 'root.isContinuousScroll' \
    || fail "handleWheel does not pick the scroll path by the event's scroll phase"
echo "$HANDLE_BODY" | grep -q 'mode === "pixel"' \
    || fail "handleWheel has no pixel-source branch"
echo "$HANDLE_BODY" | grep -q 'root.moveTo(' \
    || fail "handleWheel does not route the notch through the shared move path"
echo "$HANDLE_BODY" | grep -q 'if (!result.moved)' \
    || fail "handleWheel accepts a notch before checking the position changed"
echo "$HANDLE_BODY" | grep -q 'if (next === root.flickable.contentY)' \
    || fail "the trackpad path accepts a wheel before checking the position changed"
MOVE_BODY="$(awk '/^    function moveTo/{flag=1} flag && /^    }$/{print; exit} flag{print}' "$SMOOTH")"
test -n "$MOVE_BODY" || fail "could not extract SmoothWheel.moveTo"
echo "$MOVE_BODY" | grep -q 'Globals.reducedMotion' \
    || fail "the shared move path does not honor reduced motion"

APPS_SCROLLBARS="$(grep -c 'Controls.ScrollBar.vertical: ScrollBar' "$VIEW")"
[ "$APPS_SCROLLBARS" -eq 2 ] \
    || fail "the two Apps lists do not each have a scrollbar (found $APPS_SCROLLBARS)"
APPS_WHEELS="$(grep -c 'SmoothWheel {' "$VIEW")"
[ "$APPS_WHEELS" -eq 2 ] \
    || fail "the two Apps lists do not each use the smooth wheel (found $APPS_WHEELS)"
grep -q 'flickable: idAppsBrowseList' "$VIEW" \
    || fail "the browse smooth wheel does not target the browse list"
grep -q 'flickable: idAppsResultList' "$VIEW" \
    || fail "the result smooth wheel does not target the result list"
grep -q 'root.activeSmoothWheel.stop()' "$VIEW" \
    || fail "keyboard scroll does not stop the active list's glide"

grep -q 'Controls.ScrollBar.vertical: ScrollBar' "$CTX" \
    || fail "the context menu has no scrollbar"
grep -q 'SmoothWheel {' "$CTX" \
    || fail "the context menu does not use the smooth wheel"
grep -q 'flickable: idMenuList' "$CTX" \
    || fail "the menu smooth wheel does not target the menu list"
grep -q 'flickable: idSubmenuList' "$CTX" \
    || fail "the menu smooth wheel does not target the submenu list"
grep -q 'idMenuSmoothWheel.stop()' "$CTX" \
    || fail "the context menu does not stop the glide before keyboard scroll"

grep -q 'Globals.cardHPadding + Globals.scrollbarWidth' "$VIEW" \
    || fail "app rows do not reserve the scrollbar width"
grep -q 'Globals.pillHPadding + Globals.scrollbarWidth' "$CTX" \
    || fail "menu rows do not reserve the scrollbar width"

# --- 4k. idle-tab cost, icon load, and the apps bench ---
LAUNCHER_DECL="$(grep 'readonly property bool launcherActive' "$VIEW")"
test -n "$LAUNCHER_DECL" || fail "the Apps view has no active-tab gate property"
echo "$LAUNCHER_DECL" | grep -q 'root.visible' \
    || fail "launcherActive ignores the view visibility"
echo "$LAUNCHER_DECL" | grep -q 'DashboardService.dashboardVisible' \
    || fail "launcherActive ignores dashboard visibility"
BROWSE_GATE="$(awk '/readonly property var browseRows/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$BROWSE_GATE" || fail "the Apps view has no browse row model"
echo "$BROWSE_GATE" | grep -q 'if (!root.launcherActive)' \
    || fail "browseRows does not return early while the tab is not visible"
echo "$BROWSE_GATE" | grep -A1 'if (!root.launcherActive)' | grep -qE 'return (rows|\[\]);' \
    || fail "the browseRows active gate does not return an empty row list"
echo "$BROWSE_GATE" | grep -q 'AppService.browseRows' \
    || fail "browseRows does not build from AppService.browseRows"
if echo "$BROWSE_GATE" | grep -q 'query'; then
    fail "browseRows still depends on the query"
fi
RESULT_GATE="$(awk '/readonly property var resultRows/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$RESULT_GATE" || fail "the Apps view has no result row model"
echo "$RESULT_GATE" | grep -q 'if (!root.launcherActive || root.query.trim() === "")' \
    || fail "resultRows is not gated by launcherActive and an empty query"
echo "$RESULT_GATE" | grep -A1 'if (!root.launcherActive' | grep -qE 'return (rows|\[\]);' \
    || fail "the resultRows gate does not return an empty row list"
echo "$RESULT_GATE" | grep -q 'AppService.resultRows' \
    || fail "resultRows does not build from AppService.resultRows"
grep -q 'asynchronous: true' "$ROOT/components/AppIcon.qml" \
    || fail "AppIcon does not load its image asynchronously"
grep -q 'cache: true' "$ROOT/components/AppIcon.qml" \
    || fail "AppIcon does not cache its image"
grep -q 'function appsBench(): string' "$ROOT/dev/DevProbe.qml" \
    || fail "DevProbe has no appsBench"
grep -q 'view.bench()' "$ROOT/dev/DevProbe.qml" \
    || fail "DevProbe appsBench does not call the view's bench"
grep -q 'found: false, reason:' "$ROOT/dev/DevProbe.qml" \
    || fail "appsBench does not report why it found no launcher"
grep -q 'DashboardService.selectTab(priorTab)' "$ROOT/dev/DevProbe.qml" \
    || fail "appsBench does not restore the dashboard tab it changed"
grep -q 'found: false, reason:' "$VIEW" \
    || fail "the apps bench does not report an inactive launcher"
grep -q 'DevGeometry.register("dashboard.apps", root)' "$VIEW" \
    || fail "the Apps view does not register itself for the bench"
for part in snapshotMs emptyMs stepsMs clearMs runningMapMs; do
    grep -q "$part" "$VIEW" \
        || fail "the apps bench does not time $part"
done
grep -q 'idAppsBrowseList.forceLayout()' "$VIEW" \
    || fail "the apps bench does not force the browse layout on the empty/clear steps"
grep -q 'idAppsResultList.forceLayout()' "$VIEW" \
    || fail "the apps bench does not force the result layout after each query step"
grep -q 'appsBench' "$ROOT/docs/dev/debugging-quickshell.md" \
    || fail "the apps bench is not documented in the Dev probe list"
grep -q 'function buildRecords' "$SVC" \
    || fail "AppService has no rebuildable record snapshot"
grep -q 'AppService.buildRecords' "$VIEW" \
    || fail "the apps bench does not rebuild the AppService snapshot"
grep -q 'AppLogic.runningCounts' "$SVC" \
    || fail "AppService runningMap does not use runningCounts"

# --- 4l. the footer hint bar composes KeyHint and binds the workspace key cap ---
grep -q 'idAppsFooter' "$VIEW" \
    || fail "DashboardAppsView has no footer"
FOOTER_COUNT="$(grep -c 'KeyHint {' "$VIEW")"
[ "$FOOTER_COUNT" -eq 3 ] \
    || fail "the Apps footer does not compose KeyHint exactly three times (found $FOOTER_COUNT)"
grep -q 'AppService.workspaceKeys()' "$VIEW" \
    || fail "the footer workspace hint does not come from the pure key cap"
grep -q 'ctrl 1–' "$LOGIC" \
    || fail "the workspace key cap does not use the en-dash range"
grep -q 'ctrl 1–9, 0' "$LOGIC" \
    || fail "the workspace key cap does not cover Ctrl+0 for the tenth workspace"
grep -qF 'key: "→"' "$VIEW" \
    || fail "the footer More key cap is not the right arrow"
if grep -q '⇧F10' "$VIEW"; then
    fail "the footer still shows the Shift+F10 key cap"
fi
grep -q 'qsTr("On workspace")' "$VIEW" \
    || fail "the footer does not label the workspace hint through qsTr"
grep -q 'qsTr("hover a row for actions")' "$VIEW" \
    || fail "the footer has no faint hover hint"
grep -q 'Colors.textFaint' "$VIEW" \
    || fail "the footer hover hint is not Colors.textFaint"
FOOTER_BLOCK="$(awk '/id: idAppsFooter$/{flag=1} flag{print} flag && /^        \}$/{exit}' "$VIEW")"
test -n "$FOOTER_BLOCK" || fail "could not extract the Apps footer"
echo "$FOOTER_BLOCK" | grep -q 'Globals.hairlineHeight' \
    || fail "the footer rule is not a hairline"
echo "$FOOTER_BLOCK" | grep -q 'Colors.border' \
    || fail "the footer rule is not Colors.border"
grep -q 'property int appsFooterGap' "$ROOT/config/Globals.qml" \
    || fail "Globals has no appsFooterGap token"

# --- 4m. two lists share one delegate and route through the active list ---
DELEGATE_COMPONENTS="$(grep -c 'id: idAppRowDelegate' "$VIEW")"
[ "$DELEGATE_COMPONENTS" -eq 1 ] \
    || fail "the Apps view does not declare exactly one shared delegate Component (found $DELEGATE_COMPONENTS)"
DELEGATE_USES="$(grep -c '^[[:space:]]*delegate: idAppRowDelegate$' "$VIEW")"
[ "$DELEGATE_USES" -eq 2 ] \
    || fail "both Apps lists do not share the one delegate Component (found $DELEGATE_USES)"
grep -q 'Controls.ScrollBar.vertical: ScrollBar { id: idAppsBrowseScrollBar }' "$VIEW" \
    || fail "the browse list does not carry its own ScrollBar"
grep -q 'Controls.ScrollBar.vertical: ScrollBar { id: idAppsResultScrollBar }' "$VIEW" \
    || fail "the result list does not carry its own ScrollBar"
if grep -qnE '\bidAppsList\b' "$VIEW"; then
    fail "a list-specific idAppsList reference survives; route through root.activeList"
fi
grep -q 'root.activeList' "$VIEW" \
    || fail "the view has no active-list abstraction"
grep -q 'root.activeRows' "$VIEW" \
    || fail "the view has no active-rows abstraction"
grep -q 'root.activeSmoothWheel' "$VIEW" \
    || fail "the view has no active-wheel abstraction"
grep -q 'readonly property bool querying: root.query.trim() !== ""' "$VIEW" \
    || fail "querying is not derived from the trimmed query"
grep -q 'readonly property var activeRows: root.querying ? root.resultRows : root.browseRows' "$VIEW" \
    || fail "activeRows does not map a query to the result rows"
grep -q 'readonly property var activeList: root.querying ? idAppsResultList : idAppsBrowseList' "$VIEW" \
    || fail "activeList does not map a query to the result list"
grep -q 'readonly property var activeSmoothWheel: root.querying ? idAppsResultSmoothWheel : idAppsBrowseSmoothWheel' "$VIEW" \
    || fail "activeSmoothWheel does not map a query to the result wheel"
grep -q 'visible: !root.querying' "$VIEW" \
    || fail "the browse slot is not visible only on an empty query"
grep -q 'visible: root.querying' "$VIEW" \
    || fail "the result slot is not visible only on a query"
REGISTER_BLOCK="$(awk '/^    function registerLists/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$REGISTER_BLOCK" || fail "could not extract registerLists"
echo "$REGISTER_BLOCK" | grep -q 'root.query.trim() !== ""' \
    || fail "registerLists does not derive the active list from the source query"
if echo "$REGISTER_BLOCK" | grep -q 'root.activeList'; then
    fail "registerLists registers the stale activeList"
fi
echo "$REGISTER_BLOCK" | grep -q 'DevGeometry.register("dashboard.apps.list"' \
    || fail "registerLists does not register the active list"
grep -q 'DevGeometry.register("dashboard.apps.browseList", idAppsBrowseList)' "$VIEW" \
    || fail "the browse list is not registered for the probe"
grep -q 'DevGeometry.register("dashboard.apps.resultList", idAppsResultList)' "$VIEW" \
    || fail "the result list is not registered for the probe"
ONQUERY_BLOCK="$(awk '/^    onQueryChanged:/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$ONQUERY_BLOCK" || fail "could not extract the onQueryChanged handler"
echo "$ONQUERY_BLOCK" | grep -qF 'const querying = root.query.trim() !== ""' \
    || fail "onQueryChanged does not derive the mode from the source query"
if echo "$ONQUERY_BLOCK" | grep -qE 'root\.(querying|activeList)\b'; then
    fail "onQueryChanged reads a stale derived mode instead of the source query"
fi
echo "$ONQUERY_BLOCK" | grep -q 'idAppsBrowseList.selectedIndex = 0' \
    || fail "clearing the query does not reset the browse selection"
echo "$ONQUERY_BLOCK" | grep -q 'idAppsBrowseList.positionViewAtBeginning()' \
    || fail "clearing the query does not restore the browse list to the top"
echo "$ONQUERY_BLOCK" | grep -q 'idAppsResultList.selectedIndex = 0' \
    || fail "a query change does not select the first result"
echo "$ONQUERY_BLOCK" | grep -q 'idAppsResultList.positionViewAtBeginning()' \
    || fail "entering a query does not restore the results list to the top"
ONQUERYING_BLOCK="$(awk '/^    onQueryingChanged:/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$ONQUERYING_BLOCK" || fail "could not extract the onQueryingChanged handler"
echo "$ONQUERYING_BLOCK" | grep -q 'idAppsBrowseSmoothWheel.stop()' \
    || fail "a mode change does not stop the hidden browse wheel"
echo "$ONQUERYING_BLOCK" | grep -q 'idAppsResultSmoothWheel.stop()' \
    || fail "a mode change does not stop the hidden result wheel"
grep -q 'idAppRow.useMarkup' "$VIEW" \
    || fail "the row name has no markup gate"
grep -q 'idAppRow.useMarkup ? Text.StyledText : Text.PlainText' "$VIEW" \
    || fail "the row name is not StyledText only when it has markup"

# --- 4n. closing the menu drops the menu-only state, after the trigger runs ---
grep -qF 'onClosed: root.onMenuClosed()' "$VIEW" \
    || fail "the context menu does not route close through onMenuClosed"
MENUCLOSE_BLOCK="$(awk '/^    function onMenuClosed/{flag=1} flag{print} flag && /^    \}$/{exit}' "$VIEW")"
test -n "$MENUCLOSE_BLOCK" || fail "could not extract onMenuClosed"
echo "$MENUCLOSE_BLOCK" | grep -q 'root.focusSearch()' \
    || fail "closing the menu does not restore search focus"
echo "$MENUCLOSE_BLOCK" | grep -q 'root.menuRow = null' \
    || fail "closing the menu does not clear the menu row"
echo "$MENUCLOSE_BLOCK" | grep -q 'root.menuPinned = false' \
    || fail "closing the menu does not clear the menu pin state"

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
node - "$ROOT/tests/qmljs.js" "$LOGIC" "$ROOT/services/MonitorLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('app-launcher');
const al = qmljs.load(process.argv[3]);
const ml = qmljs.load(process.argv[4]);

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

// parseState: missing or corrupt input loads as empty lists.
check('state/corrupt', al.parseState('{ not json'), { pinned: [], hidden: [], recent: [] });
check('state/null', al.parseState('null'), { pinned: [], hidden: [], recent: [] });
check('state/array', al.parseState('[1, 2]'), { pinned: [], hidden: [], recent: [] });
check('state/strings',
      al.parseState('{"pinned":["a","b"],"hidden":["c"],"recent":["d","e"]}'),
      { pinned: ['a', 'b'], hidden: ['c'], recent: ['d', 'e'] });
check('state/non-strings',
      al.parseState('{"pinned":["a",7,""],"hidden":"x","recent":null}'),
      { pinned: ['a'], hidden: [], recent: [] });
check('state/recent-cap',
      al.parseState('{"recent":["a","b","c","d","e","f","g","h","i"]}').recent.length,
      8);

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
        al.workspaceMenu([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1', []))
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
const wsMenu = al.workspaceMenu(WS, 5, 'DP-1', [1, 2, 3, 6]);
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
const wsAnchorSecond = al.workspaceMenu(WS, 5, 'DP-2', [1, 2, 3, 6]);
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
      al.workspaceMenu(WS, 5, 'DP-1', [1, 2, 3, 4, 5]).some(i => i.id === 'workspace-new'), false);
check('wsmenu/new-from-anchor',
      al.workspaceMenu(WS, 5, 'DP-2', [1, 2, 3, 4, 5]).slice(-1)[0].workspace, 6);
check('wsmenu/other-block-does-not-free-anchor',
      al.workspaceMenu(WS, 5, 'DP-2', [6, 7, 8, 9, 10]).some(i => i.id === 'workspace-new'), false);
check('wsmenu/single-labels',
      al.workspaceMenu([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1', [])
        .filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('wsmenu/single-count',
      al.workspaceMenu([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1', [])
        .filter(i => i.id === 'workspace').length,
      5);
check('wsmenu/disabled-excluded',
      al.workspaceMenu([
        { name: 'DP-1', first: 1, active: 1 },
        { name: 'DP-2', first: 6, active: 6, disabled: true },
      ], 5, 'DP-1', []).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1']);
check('wsmenu/no-hint-over-9',
      al.workspaceMenu([{ name: 'DP-1', first: 1, active: 1 }], 12, 'DP-1', [])
        .filter(i => i.id === 'workspace' && i.hint === '').length,
      2);
check('wsmenu/no-monitors', al.workspaceMenu([], 5, '', []), []);
check('wsmenu/zero-count', al.workspaceMenu(WS, 0, 'DP-1', []), []);
check('wsmenu/bad-first',
      al.workspaceMenu([{ name: 'DP-1', first: 0, active: 1 }], 5, 'DP-1', []).length, 0);

// Empty or stale monitor data still offers the anchor block: the fallback
// carries the anchor's first workspace and known active id, so "Open on
// workspace" survives a startup poll gap. The first monitor anchors the menu
// when the anchor name is empty or names no enabled monitor, and a disabled
// anchor yields to the first enabled monitor.
const wsFallback = al.workspaceMenu([], 5, 'DP-2', [6], { name: 'DP-2', first: 6, active: 7 });
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
check('wsmenu/fallback-name',
      al.workspaceMenu([], 5, '', [], { name: 'eDP-1', first: 1, active: -1 })
        .filter(i => i.kind === 'label').map(i => i.text),
      ['eDP-1']);
check('wsmenu/no-anchor-labels',
      al.workspaceMenu(WS, 5, '', []).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1', 'DP-2']);
check('wsmenu/no-anchor-hints',
      al.workspaceMenu(WS, 5, '', []).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
check('wsmenu/stray-anchor-labels',
      al.workspaceMenu(WS, 5, 'HDMI-A-1', []).filter(i => i.kind === 'label').map(i => i.text),
      ['DP-1', 'DP-2']);
check('wsmenu/stray-anchor-hints',
      al.workspaceMenu(WS, 5, 'HDMI-A-1', []).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
check('wsmenu/disabled-anchor-falls-to-first',
      al.workspaceMenu([
        { name: 'DP-1', first: 1, active: 1 },
        { name: 'DP-2', first: 6, active: 6, disabled: true },
      ], 5, 'DP-2', []).filter(i => i.hint !== '').map(i => i.workspace),
      [1, 2, 3, 4, 5]);

// menuItems with workspace items gains Open on workspace right after Open,
// carrying the submenu; without them the item list is unchanged.
const wsItems = al.workspaceMenu([{ name: 'DP-1', first: 1, active: 2 }], 5, 'DP-1', []);
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
