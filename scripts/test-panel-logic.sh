#!/usr/bin/env bash
# Headless logic gate for the panel architecture (review #07, Q4).
#
# A full QML boot needs a compositor, so this gate does not boot one.
# Instead it checks two things that run anywhere:
#   1. structural assertions over the QML: the one-panel rule, the monitor
#      policy, the invoke path, and the cava formula each live in exactly
#      one place, so the mesh cannot silently grow back;
#   2. python oracles mirroring the pure QML helpers that still live inline
#      (anchor clamp, debounce, focus queue bound to timers) at their boundary
#      values. Each oracle cites its QML source; change the source and update
#      the mirror in the same commit. Pure logic in a .pragma library JS file
#      (ThemeParsers.js, StateParsers.js, and the per-service *Logic.js
#      modules) runs for real under node through tests/qmljs.js instead of a
#      mirror.
#
# Section index: grep -n '^# --- ' scripts/test-panel-logic.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "panel-logic FAIL: $*" >&2; exit 1; }

# --- 1. one-panel rule lives in services/Panels.qml only ---
# The registry holds the four services' PanelState instances and iterates
# that list: it closes every non-target entry and derives anyOpen from the
# list. A return to pairwise visibility toggles, or any module or window
# writing a panel's visibility, means the mesh is growing back.
PANELS="$ROOT/services/Panels.qml"
for entry in CalendarService NotificationServer CavaService PowerService; do
    grep -q "$entry.panelState" "$PANELS" \
        || fail "Panels does not hold $entry.panelState in its list"
done
grep -q 'readonly property var panels' "$PANELS" \
    || fail "Panels has no panels list"
grep -q 'for (let i = 0; i < root.panels.length; i++)' "$PANELS" \
    || fail "Panels does not iterate its panel list"
grep -q 'root.panels\[i\]\.visible = false' "$PANELS" \
    || fail "Panels does not close non-target entries via its list"
test "$(grep -c 'root.panels\[i\]' "$PANELS")" -ge 2 \
    || fail "Panels does not read and write its list entries"
grep -q 'readonly property bool anyOpen' "$PANELS" \
    || fail "Panels exposes no anyOpen"
if ! grep -A8 'readonly property bool anyOpen' "$PANELS" | grep -q 'root\.panels'; then
    fail "anyOpen does not derive from the panel list"
fi
# The per-service panel API is gone: the four visibility aliases, the eight
# toggle/open entry points, and the four outside-close wrappers no longer
# exist, so the registry and PanelShell own the mesh.
DEAD_PANEL_API="$(grep -rn --include='*.qml' -E '(calendarVisible|centerVisible|cavaVisible|powerVisible)|toggle(Calendar|Center|Cava|Power)At|open(Calendar|Center|Cava|Power)At|close(Calendar|Center|Cava|Power)FromOutside' "$ROOT/modules" "$ROOT/windows" "$ROOT/services" "$ROOT/dev" || true)"
test -z "$DEAD_PANEL_API" \
    || fail "deleted per-service panel API is back: $DEAD_PANEL_API"
grep -q 'function toggleAt(panel' "$PANELS" \
    || fail "Panels has no generic toggleAt(panel, …)"
grep -q 'function openAt(panel' "$PANELS" \
    || fail "Panels has no generic openAt(panel, …)"
if grep -q 'PowerService\.cancel' "$PANELS"; then
    fail "Panels still cancels PowerService; power resets from its own panel visibility"
fi
# The registry is the only writer of a panel's PanelState visibility.
if grep -rn --include='*.qml' -E 'panelState\.visible[[:space:]]*=' "$ROOT/modules" "$ROOT/windows" "$ROOT/services" | grep -v 'services/Panels.qml' | grep -q .; then
    fail "a module, window, or sibling service writes a panel's PanelState visibility directly"
fi
# The per-service debounce alias and the uncalled plain toggles stay dead.
for dead in calendarLastOutsideCloseAt centerLastOutsideCloseAt cavaLastOutsideCloseAt powerLastOutsideCloseAt dashboardLastOutsideCloseAt; do
    if grep -rn --include='*.qml' "$dead" "$ROOT/services" | grep -q .; then
        fail "$dead is back; PanelState owns the debounce stamp"
    fi
done
for dead in 'function toggleCalendar(' 'function toggleCenter(' 'function toggleCava(' 'function togglePower(' 'function toggleDashboard('; do
    if grep -rn --include='*.qml' "$dead" "$ROOT/services" | grep -q .; then
        fail "dead wrapper ${dead} is back"
    fi
done

# Toasts hide while ANY panel is open (toasts-over-cava was the leak).
grep -q 'Panels.anyOpen' "$ROOT/windows/NotificationPopups.qml" \
    || fail "NotificationPopups does not gate on Panels.anyOpen"

# Triggers call the registry instead of each other's services.
for trigger in "Clock.qml:Panels.toggleAt(CalendarService.panelState" "Notifications.qml:Panels.toggleAt(NotificationServer.panelState" "Cava.qml:Panels.toggleAt(CavaService.panelState" "PowerMenu.qml:Panels.toggleAt(PowerService.panelState"; do
    file="${trigger%%:*}"
    call="${trigger##*:}"
    grep -q "$call" "$ROOT/modules/$file" \
        || fail "$file does not call $call"
done

# --- 2. monitor policy is data in Globals, composed in modules ---
# The primary resolves at runtime from Quickshell.screens plus a persisted
# override; no source hardcodes DP-1 and no module branches on the name.
grep -q 'monitorName === "DP-1"' "$ROOT/shell.qml" \
    && fail "shell.qml still gates modules by monitor name directly"
grep -q 'property string monitorName: modelData ? modelData.name : ""' "$ROOT/shell.qml" \
    || fail "shell.qml does not null-guard modelData.name, so removing a screen logs a TypeError"
if grep -q '"DP-1"' "$ROOT/config/Globals.qml"; then
    fail "Globals still hardcodes DP-1; resolve the primary from the screens"
fi
grep -q 'import Quickshell' "$ROOT/config/Globals.qml" \
    || fail "Globals does not import Quickshell for the screen list"
grep -q 'Quickshell.screens' "$ROOT/config/Globals.qml" \
    || fail "Globals does not resolve the primary from Quickshell.screens"
grep -q 'readonly property var screensByPosition' "$ROOT/config/Globals.qml" \
    || fail "Globals has no screensByPosition ordering"
grep -q 'property string primaryMonitorOverride' "$ROOT/config/Globals.qml" \
    || fail "Globals has no persisted primaryMonitorOverride"
grep -q 'function onPrimaryMonitor' "$ROOT/config/Globals.qml" \
    || fail "Globals has no onPrimaryMonitor helper"
for module in Tray Media Audio PowerMenu Cava Notifications; do
    grep -q 'property string monitorName' "$ROOT/modules/$module.qml" \
        || fail "$module.qml declares no monitorName"
    grep -q 'Globals.onPrimaryMonitor(root.monitorName)' "$ROOT/modules/$module.qml" \
        || fail "$module.qml does not compose Globals.onPrimaryMonitor"
done
# Workspaces assigns each monitor a contiguous block from MonitorService; no
# name literal and no fixed count.
if grep -q '"DP-2"' "$ROOT/modules/Workspaces.qml"; then
    fail "Workspaces still hardcodes DP-2; use MonitorService.firstWorkspaceFor"
fi
grep -q 'MonitorService.firstWorkspaceFor(root.monitorName)' "$ROOT/modules/Workspaces.qml" \
    || fail "Workspaces does not derive its first workspace from MonitorService"
grep -q 'model: MonitorService.workspacesPerMonitor' "$ROOT/modules/Workspaces.qml" \
    || fail "Workspaces does not size its row from MonitorService.workspacesPerMonitor"

# --- 3. one focus module, thin call sites ---
grep -q 'function focusByTokens' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus has no focusByTokens"
grep -q 'requestQueue' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus has no request queue"
grep -q 'dispatchImpl' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus dispatch is not injectable"
grep -q 'idFocusWatchdog' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus has no snapshot watchdog"
grep -q 'snapshotPending' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus does not guard stale snapshots"
grep -q 'focusWatchdogMs' "$ROOT/config/Globals.qml" \
    || fail "Globals has no focusWatchdogMs"
grep -q 'idFocusRetryTimer' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus does not wait for toplevel data"
grep -q 'focusRetryMs' "$ROOT/config/Globals.qml" \
    || fail "Globals has no focusRetryMs"
grep -q 'focusRetryTicks' "$ROOT/config/Globals.qml" \
    || fail "Globals has no focusRetryTicks"
grep -q 'panelSettleMs' "$ROOT/config/Globals.qml" \
    || fail "Globals has no panelSettleMs"
# Hyprland's Lua IPC leaves lastIpcObject empty, so class matching must also
# read the Wayland appId or nothing ever matches.
grep -q 'toplevel.wayland.appId' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus class matching does not read the Wayland appId"
# A panel closing restores the previously focused window, so a focus request
# must wait for the close to finish or the restore overrides it.
grep -q 'PanelGrab.closing' "$ROOT/services/HyprlandFocus.qml" \
    || fail "HyprlandFocus does not wait for a closing panel before focusing"
grep -q 'readonly property bool closing' "$ROOT/services/PanelGrab.qml" \
    || fail "PanelGrab does not expose the closing state"
for site in "modules/Tray.qml" "services/NotificationServer.qml" "windows/DashboardPlayerBlock.qml"; do
    grep -q 'HyprlandFocus.focusByTokens' "$ROOT/$site" \
        || fail "$site does not delegate to HyprlandFocus"
done
if grep -rn --include='*.qml' 'lastIpcObject' "$ROOT/modules/Tray.qml" "$ROOT/services/NotificationServer.qml" "$ROOT/windows/DashboardPlayerBlock.qml" | grep -q .; then
    fail "matcher logic leaked back into a call site"
fi
# Focusing another window needs the dashboard's focus grab released first,
# so the cover-art click closes the dashboard before it dispatches focus.
grep -q 'DashboardService.close()' "$ROOT/windows/DashboardPlayerBlock.qml" \
    || fail "DashboardPlayerBlock does not close the dashboard before focusing"

# --- 3b. module siblings resolve only through a self-import ---
# qmllint resolves same-directory siblings, the runtime does not when the
# directory is a qmldir module: every service file that names a sibling
# type must import qs.services, and every sibling component must be in qmldir.
for svc in CalendarService NotificationServer CavaService Panels PowerService SettingsService BarVisibilityService HyprlandFocus; do
    grep -q '^import qs.services' "$ROOT/services/$svc.qml" \
        || fail "$svc.qml is missing its qs.services self-import"
done
grep -q '^PanelState 1.0 PanelState.qml' "$ROOT/services/qmldir" \
    || fail "PanelState is not registered in services/qmldir"
grep -q '^singleton PowerService 1.0 PowerService.qml' "$ROOT/services/qmldir" \
    || fail "PowerService is not registered in services/qmldir"
grep -q 'PowerService.panelState' "$ROOT/services/Panels.qml" \
    || fail "Panels does not hold the power PanelState"

# --- 4. single invoke path for notification actions ---
for pill in components/NotificationToast.qml components/NotificationRow.qml; do
    grep -q 'invokeAction' "$ROOT/$pill" \
        || fail "$pill does not use invokeAction"
    if grep -q 'focusApp(' "$ROOT/$pill"; then
        fail "$pill calls focusApp directly instead of invokeAction"
    fi
    if grep -q '\.invoke()' "$ROOT/$pill"; then
        fail "$pill invokes the action directly instead of invokeAction"
    fi
done

# --- 5. single cava height formula and style array ---
test "$(grep -c 'root.barDrawHeight(index)' "$ROOT/modules/Cava.qml")" -eq 4 \
    || fail "expected 4 barDrawHeight call sites in Cava.qml"
if grep -q 'CavaService.levels\[index\]' "$ROOT/modules/Cava.qml"; then
    fail "inline bar-height math remains in Cava.qml"
fi
grep -q 'styleComponents\[CavaService.styleMode\]' "$ROOT/modules/Cava.qml" \
    || fail "Cava style loader does not index styleComponents by styleMode"
if grep -q 'styleMode === 0 ?' "$ROOT/modules/Cava.qml"; then
    fail "style ternary is back in Cava.qml"
fi
CAVASVC="$ROOT/services/CavaService.qml"
test "$(grep -c 'if (idSettingsState.loading || !idSettingsState.loaded)' "$CAVASVC")" -eq 5 \
    || fail "CavaService does not guard all five change handlers on the StateFile loading/loaded flags"
if grep -qE 'if \(idSettingsState\.loading\)' "$CAVASVC"; then
    fail "CavaService has a change handler guarded on loading alone"
fi
grep -A1 'onBarCountChanged: {' "$CAVASVC" | grep -q 'root.levels = root.flatLevels();' \
    || fail "CavaService onBarCountChanged no longer resets levels before the guard"

# --- 6. python oracles for the pure helpers ---
python3 - <<'EOF'
import re
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

# Mirror of CalendarService.isStale (services/CalendarService.qml).
# eventsStaleAfterMs is 30 * 60 * 1000 there.
AFTER = 30 * 60 * 1000
def is_stale(now_ms, fetched_ms, failed):
    if failed:
        return True
    if not (fetched_ms > 0):
        return False
    return (now_ms - fetched_ms) > AFTER

check("stale/failed", is_stale(1000, 500, True), True)
check("stale/never", is_stale(1000, 0, False), False)
check("stale/fresh", is_stale(1000, 900, False), False)
check("stale/29m", is_stale(29 * 60 * 1000, 0, False), False)
check("stale/exact", is_stale(30 * 60 * 1000, 0, False), False)
check("stale/31m", is_stale(31 * 60 * 1000, 1000, False), True)

# Mirror of PanelShell.anchorLeft (components/PanelShell.qml):
# panelWidth = min(centerWidth=380, screenW - 2*edge), edge = panelEdgeMargin = 10.
def anchor_left(screen_w, center_x):
    panel_w = min(380, screen_w - 20)
    raw = center_x - panel_w / 2
    max_left = screen_w - panel_w - 10
    return min(max(raw, 10), max(max_left, 10))

check("clamp/centered", anchor_left(1920, 200), 10)
check("clamp/left-edge", anchor_left(1920, 100), 10)
check("clamp/right-edge", anchor_left(1920, 1900), 1530)
check("clamp/bell-case", anchor_left(1920, 1700), 1510)
check("clamp/narrow", anchor_left(400, 200), 10)
check("clamp/tiny", anchor_left(300, 150), 10)

# Mirror of Globals.screensByPosition and Globals.primaryMonitor
# (config/Globals.qml): the screens sort by x, then y, then name; the stored
# override wins only when it names a connected screen, otherwise the first
# screen, otherwise "". onPrimaryMonitor still treats an empty name as primary.
def resolve_primary(screens, override):
    ordered = sorted(screens, key=lambda s: (s["x"], s["y"], s["name"]))
    names = [s["name"] for s in ordered]
    if override in names:
        return override
    return names[0] if names else ""

def on_primary(monitor, primary):
    return monitor == "" or monitor == primary

SCREENS = [
    {"name": "DP-2", "x": 1920, "y": 0},
    {"name": "DP-1", "x": 0, "y": 0},
]
check("monitor/override-wins", resolve_primary(SCREENS, "DP-2"), "DP-2")
check("monitor/auto-first", resolve_primary(SCREENS, ""), "DP-1")
check("monitor/unknown-falls-back", resolve_primary(SCREENS, "HDMI-A-1"), "DP-1")
check("monitor/x-order", resolve_primary([{"name": "B", "x": 1, "y": 0}, {"name": "A", "x": 0, "y": 0}], ""), "A")
check("monitor/y-order", resolve_primary([{"name": "B", "x": 0, "y": 1}, {"name": "A", "x": 0, "y": 0}], ""), "A")
check("monitor/name-order", resolve_primary([{"name": "B", "x": 0, "y": 0}, {"name": "A", "x": 0, "y": 0}], ""), "A")
check("monitor/no-screens", resolve_primary([], ""), "")
check("monitor/no-screens-unknown", resolve_primary([], "DP-1"), "")
check("monitor/empty-primary", on_primary("", resolve_primary(SCREENS, "")), True)
check("monitor/override-primary", on_primary("DP-2", resolve_primary(SCREENS, "DP-2")), True)
check("monitor/other-hides", on_primary("DP-1", resolve_primary(SCREENS, "DP-2")), False)
# A stored override for a screen that is away is kept, not cleared; the bar
# falls back to the first screen and the choice returns on reconnect.
RECONNECTED = SCREENS + [{"name": "HDMI-A-1", "x": 3840, "y": 0}]
check("monitor/override-falls-back", resolve_primary(SCREENS, "HDMI-A-1"), "DP-1")
check("monitor/override-returns", resolve_primary(RECONNECTED, "HDMI-A-1"), "HDMI-A-1")

# Mirror of PanelState.toggle debounce (services/PanelState.qml): 300 ms.
def toggle(visible, last_close_at, now):
    if not visible and now - last_close_at < 300:
        return visible
    return not visible

check("debounce/swallowed", toggle(False, 1000, 1100), False)
check("debounce/boundary", toggle(False, 1000, 1300), True)
check("debounce/open-toggles", toggle(True, 1000, 1100), False)

# Mirror of HyprlandFocus queueing (services/HyprlandFocus.qml): concurrent
# clicks queue behind the in-flight read and dispatch in order.
queue = []
dispatched = []
queue = queue + ["0xaaa"]
queue = queue + ["0xbbb"]
while queue:
    active = queue[0]
    queue = queue[1:]
    dispatched.append(f"focus {active}")
    dispatched.append("restore cursor")
check("queue/order", dispatched,
      ["focus 0xaaa", "restore cursor", "focus 0xbbb", "restore cursor"])

# Mirror of HyprlandFocus.keysFor/classMatches (services/HyprlandFocus.qml): the
# token is kept whole (never collapsed to its first segment), a single-segment
# token matches any class segment, and a reverse-DNS token matches the class's
# last segment so it cannot collapse to a generic prefix.
def keys_for(tokens):
    keys = []
    for token in tokens:
        norm = str(token or "").lower().strip()
        if norm and norm not in keys:
            keys.append(norm)
    return keys

def class_matches(source, key):
    source_parts = [part for part in re.split(r"[^a-z0-9]+", source.lower()) if part]
    key_parts = [part for part in re.split(r"[^a-z0-9]+", key.lower()) if part]
    if not source_parts or not key_parts:
        return False
    if len(key_parts) == 1:
        return key_parts[0] in source_parts
    return source_parts[-1] == key_parts[-1]

check("focus/keys-whole", keys_for(["org.kde.spectacle", "Spectacle"]), ["org.kde.spectacle", "spectacle"])
check("focus/single-segment", class_matches("spotify", "spotify"), True)
check("focus/single-in-reverse-dns", class_matches("com.spotify.client", "spotify"), True)
check("focus/reverse-dns", class_matches("org.kde.spectacle", "org.kde.spectacle"), True)
check("focus/reverse-dns-last", class_matches("spectacle", "org.kde.spectacle"), True)
check("focus/reverse-dns-prefix-guard", class_matches("org.kde.okular", "org.kde.spectacle"), False)
check("focus/no-match", class_matches("firefox", "spotify"), False)
EOF

# Monitor logic runs under node: MonitorLogic.parseMonitorSettings and
# clampWorkspacesPerMonitor keep a string primary verbatim (a disconnected
# choice survives), ignore a non-string one, and clamp the count to 1..20.
# orderMonitors and firstWorkspaceFor give the primary the first block; modeFor,
# positionFor and scaleFor rebuild a disabled output's geometry; setEnabledSpec
# returns no spec for a no-op, a last display or an unknown output.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/MonitorLogic.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const ml = qmljs.load(process.argv[3]);

check('settings/primary-kept', ml.parseMonitorSettings('{"primary":"HDMI-A-1"}', 5).primary, 'HDMI-A-1');
check('settings/primary-nonstring', ml.parseMonitorSettings('{"primary":7}', 5).primary, null);
check('settings/count-kept', ml.parseMonitorSettings('{"primary":"DP-2"}', 5).workspacesPerMonitor, 5);
check('settings/count-clamped', ml.parseMonitorSettings('{"workspacesPerMonitor":50}', 5).workspacesPerMonitor, 20);
check('settings/count-low', ml.parseMonitorSettings('{"workspacesPerMonitor":0}', 5).workspacesPerMonitor, 1);
check('settings/count-rounds', ml.parseMonitorSettings('{"workspacesPerMonitor":7.5}', 5).workspacesPerMonitor, 8);
check('settings/malformed', ml.parseMonitorSettings('{nope', 5), null);
check('settings/null', ml.parseMonitorSettings('null', 5), null);
check('settings/number', ml.parseMonitorSettings('5', 5), null);
check('settings/array-ignores', ml.parseMonitorSettings('[1,2]', 5), { primary: null, workspacesPerMonitor: 5 });

check('clamp/high', ml.clampWorkspacesPerMonitor(50, 5), 20);
check('clamp/low', ml.clampWorkspacesPerMonitor(0, 5), 1);
check('clamp/round', ml.clampWorkspacesPerMonitor(7.5, 5), 8);
check('clamp/numeric-text', ml.clampWorkspacesPerMonitor('12', 5), 12);
check('clamp/text', ml.clampWorkspacesPerMonitor('nope', 5), 5);
check('clamp/missing', ml.clampWorkspacesPerMonitor(undefined, 5), 5);

check('order/primary', ml.orderMonitors('DP-1', ['DP-1', 'DP-2', 'DP-3']), ['DP-1', 'DP-2', 'DP-3']);
check('order/override', ml.orderMonitors('DP-2', ['DP-1', 'DP-2', 'DP-3']), ['DP-2', 'DP-1', 'DP-3']);
check('order/auto', ml.orderMonitors('', ['DP-1', 'DP-2']), ['DP-1', 'DP-2']);
check('order/disconnected-primary', ml.orderMonitors('HDMI-A-1', ['DP-1', 'DP-2']), ['HDMI-A-1', 'DP-1', 'DP-2']);

const ordered = ['DP-1', 'DP-2', 'DP-3'];
check('workspaces/first-primary', ml.firstWorkspaceFor(ordered, 'DP-1', 5), 1);
check('workspaces/first-second', ml.firstWorkspaceFor(ordered, 'DP-2', 5), 6);
check('workspaces/first-third', ml.firstWorkspaceFor(ordered, 'DP-3', 5), 11);
check('workspaces/first-unknown', ml.firstWorkspaceFor(ordered, 'HDMI-A-1', 5), 1);
check('workspaces/first-empty', ml.firstWorkspaceFor(ordered, '', 5), 1);
check('workspaces/count-three', ml.firstWorkspaceFor(ordered, 'DP-3', 3), 7);
check('workspaces/override-order', ml.firstWorkspaceFor(ml.orderMonitors('DP-2', ['DP-1', 'DP-2', 'DP-3']), 'DP-1', 5), 6);

const norm = m => ({
    name: m.name,
    disabled: m.disabled === true,
    mode: ml.modeFor(m),
    position: ml.positionFor(m),
    scale: ml.scaleFor(m)
});
const TWO = [
    { name: 'DP-1', disabled: false, x: 0, y: 0, width: 2560, height: 1440, refreshRate: 179.96, scale: 1 },
    { name: 'DP-2', disabled: false, x: 2560, y: 100, width: 1920, height: 1080, refreshRate: 165.003, scale: 1 }
];
const ONE = [TWO[0]];
const OFF = [TWO[0], Object.assign({}, TWO[1], { disabled: true })];
const NODATA = { name: 'DP-9', disabled: false, width: 0, height: 0, refreshRate: 0, scale: 0 };

check('display/mode-rounds', ml.modeFor(TWO[0]), '2560x1440@180');
check('display/mode-disabled-kept', ml.modeFor(OFF[1]), '1920x1080@165');
check('display/mode-half-up', ml.modeFor({ width: 100, height: 50, refreshRate: 59.5 }), '100x50@60');
check('display/mode-no-geometry', ml.modeFor(NODATA), 'preferred');
check('display/position', ml.positionFor(OFF[1]), '2560x100');
check('display/position-missing', ml.positionFor(NODATA), 'auto');
check('display/scale-fallback', ml.scaleFor(NODATA), 1);
check('display/escape', ml.escapeLua('DP"1'), 'DP\\"1');
check('display/disable-spec', ml.setEnabledSpec(ml.escapeLua('DP-1'), norm(TWO[0]), false, true),
      'hl.monitor({ output = "DP-1", disabled = true })');
check('display/enable-spec', ml.setEnabledSpec(ml.escapeLua('DP-2'), norm(OFF[1]), true, true),
      'hl.monitor({ output = "DP-2", disabled = false, mode = "1920x1080@165", position = "2560x100", scale = 1 })');
check('display/refuse-last', ml.setEnabledSpec(ml.escapeLua('DP-1'), norm(ONE[0]), false, false), null);
check('display/refuse-noop-off', ml.setEnabledSpec(ml.escapeLua('DP-2'), norm(OFF[1]), false, true), null);
check('display/refuse-noop-on', ml.setEnabledSpec(ml.escapeLua('DP-1'), norm(TWO[0]), true, true), null);
check('display/refuse-unknown', ml.setEnabledSpec(ml.escapeLua('HDMI-A-1'), null, true, true), null);

check('screen/focused', ml.pickScreenName('DP-2', 'DP-1', ['DP-1', 'DP-2']), 'DP-2');
check('screen/no-focus-primary', ml.pickScreenName('', 'DP-2', ['DP-1', 'DP-2']), 'DP-2');
check('screen/focused-missing-primary', ml.pickScreenName('HDMI-A-1', 'DP-1', ['DP-1', 'DP-2']), 'DP-1');
check('screen/both-missing-first', ml.pickScreenName('HDMI-A-1', 'HDMI-A-2', ['DP-1', 'DP-2']), 'DP-1');
check('screen/disconnected-primary-first', ml.pickScreenName('HDMI-A-2', 'HDMI-A-1', ['DP-1', 'DP-2']), 'DP-1');
check('screen/empty', ml.pickScreenName('DP-1', 'DP-1', []), '');
NODEEOF

# --- 7. power confirm loop:.argv mapping verified without firing ---
# Destructive commands never run in CI; assert the mapping statically.
PSVC="$ROOT/services/PowerService.qml"
PCENTER="$ROOT/windows/PowerCenter.qml"
grep -q 'command -v hyprlock' "$PSVC" \
    || fail "PowerService lock has no hyprlock fallback chain"
grep -q 'betterlockscreen' "$PSVC" \
    || fail "PowerService lock misses betterlockscreen fallback"
grep -q 'i3lock' "$PSVC" \
    || fail "PowerService lock misses i3lock fallback"
grep -q 'playerctl pause -a' "$PSVC" \
    || fail "PowerService suspend does not pause media first"
grep -q 'systemctl suspend' "$PSVC" \
    || fail "PowerService suspend misses systemctl suspend"
grep -q '"hyprctl", "dispatch", "exit"' "$PSVC" \
    || fail "PowerService logout does not dispatch Hyprland exit"
grep -q '"systemctl", "reboot"' "$PSVC" \
    || fail "PowerService reboot misses systemctl reboot"
grep -q '"systemctl", "poweroff"' "$PSVC" \
    || fail "PowerService shutdown misses systemctl poweroff"
grep -q 'pkexec efibootmgr -n 0000' "$PSVC" \
    || fail "PowerService winboot misses pkexec efibootmgr one-shot"
grep -q 'actionId === "winboot"' "$PSVC" \
    || fail "PowerService has no winboot branch"
# Lock fires at once; the other five only arm.
grep -q 'if (actionId === "lock")' "$PSVC" \
    || fail "PowerService.arm has no lock fast path"
# Confirm is inert with nothing armed.
grep -q 'if (root.armedAction === "")' "$PSVC" \
    || fail "PowerService.confirmArmed has no empty guard"
# Footer never reflows: buttons stay laid out via disabled, never visible toggles.
if grep -n 'armedAction' "$PCENTER" | grep -q 'visible:'; then
    fail "PowerCenter footer toggles visibility on armed state (reflows)"
fi
grep -q 'disabled: PowerService.armedAction === ""' "$PCENTER" \
    || fail "PowerCenter footer does not hold Confirm/Cancel slots while disarmed"
# Keyboard flow without a pointer.
for key in '"1"' '"2"' '"3"' '"4"' '"5"' '"6"' '"Return"' '"Enter"'; do
    grep -q "sequence: $key" "$PCENTER" \
        || fail "PowerCenter misses keyboard sequence $key"
done
# Monochrome is deliberate: no red color anywhere in the panel or its
# service (the `dangerous` model flag is data for label plus confirm only).
if grep -qnE 'Colors\.(danger|red)|#ff5252' "$PCENTER" "$PSVC"; then
    fail "power panel carries red; danger travels by label plus confirm only"
fi
# Slow poll skips while a run is in flight.
grep -q 'idRunProcess.running' "$PSVC" \
    || fail "PowerService info poll does not skip while a run is in flight"
# Reduced motion has a project-level switch and the panel honors it.
grep -q 'reducedMotion' "$ROOT/config/Globals.qml" \
    || fail "Globals has no reducedMotion switch"
grep -q 'reducedMotion' "$PCENTER" \
    || fail "PowerCenter ignores Globals.reducedMotion"
grep -q 'reducedMotion' "$ROOT/components/PressScale.qml" \
    || fail "PressScale ignores Globals.reducedMotion"

# --- 8. dashboard shell: standalone visibility outside the exclusive registry ---
DSVC="$ROOT/services/DashboardService.qml"
test -f "$DSVC" \
    || fail "services/DashboardService.qml is missing"
grep -q 'property alias dashboardVisible' "$DSVC" \
    || fail "DashboardService has no dashboardVisible alias"
grep -q 'function toggleDashboardAt' "$DSVC" \
    || fail "DashboardService has no toggleDashboardAt"
grep -q 'function closeDashboardFromOutside' "$DSVC" \
    || fail "DashboardService has no closeDashboardFromOutside"
grep -q '^import qs.services' "$DSVC" \
    || fail "DashboardService.qml is missing its qs.services self-import"
grep -q '^PanelState 1.0 PanelState.qml' "$ROOT/services/qmldir" \
    || fail "PanelState is not registered in services/qmldir"
grep -q '^singleton DashboardService 1.0 DashboardService.qml' "$ROOT/services/qmldir" \
    || fail "DashboardService is not registered in services/qmldir"
if grep -q 'DashboardService' "$ROOT/services/Panels.qml"; then
    fail "Panels owns DashboardService; the dashboard stays open beside quick panels"
fi

# Dashboard trigger lives on the bar center title, outside the registry.
if grep -q 'Panels\.' "$ROOT/modules/ActiveWindow.qml"; then
    fail "ActiveWindow calls the exclusive registry; the dashboard stays beside quick panels"
fi
grep -q 'DashboardService.toggleDashboardAt' "$ROOT/modules/ActiveWindow.qml" \
    || fail "ActiveWindow.qml does not call DashboardService.toggleDashboardAt"
if grep -q 'enableHover: *false' "$ROOT/modules/ActiveWindow.qml" || grep -q 'enableMouseArea: *false' "$ROOT/modules/ActiveWindow.qml"; then
    fail "ActiveWindow.qml disables hover or mouse input; the title is the dashboard toggle"
fi
grep -q 'property ShellScreen triggerScreen' "$ROOT/modules/ActiveWindow.qml" \
    || fail "ActiveWindow.qml declares no triggerScreen"
grep -q 'triggerScreen: idPanelWindow.modelData' "$ROOT/shell.qml" \
    || fail "shell.qml does not pass the clicked screen to ActiveWindow"
# The trigger stays mounted when no window is focused, so an empty workspace
# still has a hit target; the title hairlines follow the real title.
if grep -q 'visible: *root.title !== ""' "$ROOT/modules/ActiveWindow.qml"; then
    fail "ActiveWindow hides on an empty title; the dashboard trigger disappears"
fi
grep -q 'readonly property bool hasTitle' "$ROOT/modules/ActiveWindow.qml" \
    || fail "ActiveWindow has no hasTitle gate for the placeholder"
grep -q 'idActiveWindow.hasTitle' "$ROOT/shell.qml" \
    || fail "shell.qml hairlines do not follow the focused title"

# Dashboard card is a centered PanelShell on the clicked screen, wider than
# the standard panel, palette tokens only.
DCENTER="$ROOT/windows/DashboardCenter.qml"
test -f "$DCENTER" \
    || fail "windows/DashboardCenter.qml is missing"
grep -q 'DashboardService.dashboardVisible' "$DCENTER" \
    || fail "DashboardCenter does not bind DashboardService.dashboardVisible"
grep -q 'DashboardService.anchorScreen' "$DCENTER" \
    || fail "DashboardCenter does not anchor to DashboardService.anchorScreen"
grep -q 'DashboardService.closeDashboardFromOutside' "$DCENTER" \
    || fail "DashboardCenter does not close from outside via DashboardService"
grep -q 'PanelShell' "$DCENTER" \
    || fail "DashboardCenter does not reuse PanelShell behavior"
grep -q 'Globals.dashboardWidth' "$DCENTER" \
    || fail "DashboardCenter does not size from Globals.dashboardWidth"
grep -q 'property int dashboardWidth' "$ROOT/config/Globals.qml" \
    || fail "Globals has no dashboardWidth token"
grep -q 'property int dashboardMaxHeight' "$ROOT/config/Globals.qml" \
    || fail "Globals has no dashboardMaxHeight token"
grep -q 'DashboardCenter' "$ROOT/shell.qml" \
    || fail "shell.qml does not instantiate DashboardCenter"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$DCENTER"; then
    fail "DashboardCenter carries raw hex; palette tokens only"
fi
if grep -qiE 'cream|peach' "$DCENTER" "$ROOT/config/Globals.qml" "$ROOT/config/Colors.qml"; then
    fail "dashboard carries reference cream/peach; palette tokens only"
fi

# Dashboard card attaches to the bar: top edge on the bar bottom edge.
grep -q 'property bool attachedToBar: false' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell attachedToBar switch is missing or defaults wrong; quick panels keep their gap"
grep -q 'attachedToBar: true' "$DCENTER" \
    || fail "DashboardCenter does not attach to the bar"
grep -q 'attachedToBar ? -Globals.panelSeamOverlap : Globals.panelTopGap' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell top margin does not branch on attachedToBar; attached underlaps the bar to hide the seam"

# Dashboard junction is a concave fillet: opt-in radius, shaped chrome,
# shaped mask, and a service-owned value the settings window can adjust.
grep -q 'property int junctionRadius: 0' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell junctionRadius switch is missing or defaults wrong; quick panels keep the plain rectangle"
grep -q 'Shape.CurveRenderer' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not render the concave junction chrome"
grep -q 'junctionBorderPath' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell junction stroke is missing; the border must drop the top segment"
grep -q 'RegionShape.Ellipse' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell mask does not shape the junction notches"
grep -q 'property int junctionRadius: Globals.junctionRadiusDefault' "$DSVC" \
    || fail "DashboardService junctionRadius is missing or does not default to the token"
grep -q 'property int junctionRadiusDefault' "$ROOT/config/Globals.qml" \
    || fail "Globals has no junctionRadiusDefault token"
grep -q 'property int junctionRadiusMax' "$ROOT/config/Globals.qml" \
    || fail "Globals has no junctionRadiusMax; the settings range is unbounded"
grep -q 'junctionRadiusDefault: 16' "$ROOT/config/Globals.qml" \
    || fail "Globals junctionRadiusDefault is not the agreed 16"
grep -q 'junctionRadiusMax: 32' "$ROOT/config/Globals.qml" \
    || fail "Globals junctionRadiusMax is not the agreed 32"
grep -q 'property int panelSeamOverlap' "$ROOT/config/Globals.qml" \
    || fail "Globals has no panelSeamOverlap token"
grep -q 'junctionRadius: DashboardService.junctionRadius' "$DCENTER" \
    || fail "DashboardCenter does not bind the junction radius to DashboardService"

# Dashboard card layout follows the reference card: tab row plus block grid
# with stub content in palette tokens. Live data arrives in later tickets.
for block in DashboardWeatherBlock DashboardSystemBlock DashboardCpuBlock DashboardVolumeBlock DashboardPlayerBlock DashboardThemeBlock; do
    test -f "$ROOT/windows/$block.qml" \
        || fail "windows/$block.qml is missing"
    grep -q 'qsTr(' "$ROOT/windows/$block.qml" \
        || fail "$block.qml has no qsTr user-visible strings"
    if grep -qnE '#[0-9a-fA-F]{3,8}' "$ROOT/windows/$block.qml"; then
        fail "$block.qml carries raw hex; palette tokens only"
    fi
    if grep -q 'Process\|XmlHttpRequest\|fetch(' "$ROOT/windows/$block.qml"; then
        fail "$block.qml reaches the network; stubs stay fixed with no traffic"
    fi
done
test -f "$ROOT/windows/DashboardTabs.qml" \
    || fail "windows/DashboardTabs.qml is missing"
grep -qF 'qsTr("Dashboard")' "$ROOT/services/DashboardService.qml" \
    || fail "DashboardService tab titles are not translated"
grep -q 'DashboardTabs' "$DCENTER" \
    || fail "DashboardCenter does not compose the tab row"
grep -q 'DashboardPlayerBlock' "$DCENTER" \
    || fail "DashboardCenter does not compose the player block"
if grep -qiE 'cream|peach' "$ROOT"/windows/Dashboard*.qml; then
    fail "dashboard blocks carry reference cream/peach; palette tokens only"
fi

# --- 9. settings tab: dashboard tab host, section registry, search ---
# Settings is the dashboard's Settings tab (ADR 0012), not a separate window.
# DashboardService.activeTab picks the page; windows/SettingsView.qml holds
# the search field, the section rail, and the card-wrapped section body. The
# SettingsService singleton keeps the section registry and a deep link.
SSVC="$ROOT/services/SettingsService.qml"
SCENTER="$ROOT/windows/SettingsView.qml"
CSV="$ROOT/windows/CavaSettingsView.qml"
DTABS="$ROOT/windows/DashboardTabs.qml"

test -f "$SSVC" \
    || fail "services/SettingsService.qml is missing"
grep -q 'property string targetSection' "$SSVC" \
    || fail "SettingsService has no targetSection deep link"
grep -q '^import qs.services' "$SSVC" \
    || fail "SettingsService.qml is missing its qs.services self-import"
grep -q '^singleton SettingsService 1.0 SettingsService.qml' "$ROOT/services/qmldir" \
    || fail "SettingsService is not registered in services/qmldir"

# The category rail is always alphabetical: the rail renders `sections`, the
# derived list sorted by title, never the literal insertion order.
grep -qF 'readonly property var sectionRegistry: [' "$SSVC" \
    || fail "SettingsService has no sectionRegistry"
grep -qF 'readonly property var sections: [...root.sectionRegistry].sort' "$SSVC" \
    || fail "SettingsService sections are not derived by sorting sectionRegistry"
grep -q 'a.title.localeCompare(b.title)' "$SSVC" \
    || fail "SettingsService sections are not sorted alphabetically by title"

if grep -q 'SettingsService' "$ROOT/services/Panels.qml"; then
    fail "Panels owns SettingsService; settings opens from the dashboard, not the registry"
fi

# The toplevel window is gone: no FloatingWindow, no title selector, no
# dependency on the external Hyprland float rule.
if grep -rqE 'FloatingWindow|settingsWindowTitle' "$ROOT/windows" "$ROOT/shell.qml" "$ROOT/services"; then
    fail "settings is still a FloatingWindow; the dashboard tab owns it now"
fi
if grep -q 'SettingsCenter' "$ROOT/shell.qml"; then
    fail "shell.qml still instantiates the removed SettingsCenter"
fi
test -f "$ROOT/windows/SettingsCenter.qml" \
    && fail "windows/SettingsCenter.qml still exists"
if grep -qE 'grabEnabled|extraGrabWindows' "$ROOT/components/PanelShell.qml"; then
    fail "PanelShell still carries the settings shared-grab switches"
fi

# Tab host: the row renders DashboardService.tabs, marks and switches the
# active key, and every tab is an accessible button.
test -f "$DTABS" \
    || fail "windows/DashboardTabs.qml is missing"
grep -q 'DashboardService.tabs' "$DTABS" \
    || fail "DashboardTabs does not render DashboardService.tabs"
grep -q 'DashboardService.activeTab' "$DTABS" \
    || fail "DashboardTabs does not mark the active tab"
grep -q 'DashboardService.selectTab' "$DTABS" \
    || fail "DashboardTabs does not switch tabs"
grep -q 'Accessible.role: Accessible.Button' "$DTABS" \
    || fail "tabs are not accessible buttons"
grep -q 'property string activeTab' "$DSVC" \
    || fail "DashboardService has no activeTab"
grep -qF 'function selectTab(key: string)' "$DSVC" \
    || fail "DashboardService has no selectTab(key)"
grep -qF 'function openSettings(sectionKey: string)' "$DSVC" \
    || fail "DashboardService has no openSettings(sectionKey)"
grep -q 'SettingsView' "$DCENTER" \
    || fail "DashboardCenter does not host SettingsView"
grep -q 'DashboardService.activeTab' "$DCENTER" \
    || fail "DashboardCenter does not gate pages on activeTab"
grep -qF 'qsTr("Coming soon")' "$DCENTER" \
    || fail "DashboardCenter has no placeholder for the empty tabs"
grep -q 'DashboardService.openSettings' "$DCENTER" \
    || fail "DashboardCenter gear does not open the settings tab"

# Settings view: search plus rail plus the card-wrapped section body.
test -f "$SCENTER" \
    || fail "windows/SettingsView.qml is missing"
grep -qF 'qsTr("Search settings…")' "$SCENTER" \
    || fail "SettingsView has no search field"
grep -qF 'qsTr("No match")' "$SCENTER" \
    || fail "SettingsView has no no-match note"
grep -q 'NavItem' "$SCENTER" \
    || fail "SettingsView does not compose the sidebar NavItem"
grep -q 'Globals.settingsSidebarWidth' "$SCENTER" \
    || fail "SettingsView does not size the sidebar from Globals.settingsSidebarWidth"
grep -q 'Card' "$SCENTER" \
    || fail "SettingsView does not wrap the section body in a Card"
grep -q 'Globals.settingsBodyMaxHeight' "$SCENTER" \
    || fail "SettingsView does not cap the section body height"
grep -q 'onTargetSectionChanged' "$SCENTER" \
    || fail "SettingsView does not re-apply a later targetSection (M5)"
grep -A4 'function onTargetSectionChanged' "$SCENTER" | grep -q 'SettingsService.sections\[0\].key' \
    || fail "SettingsView does not reset to the first section when targetSection clears"
grep -q 'SettingsService.requestSection' "$SCENTER" \
    || fail "SettingsView rail does not sync the shared section target"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$SCENTER" "$CSV" "$SSVC" "$ROOT/components/NavItem.qml"; then
    fail "settings surface carries raw hex; palette tokens only"
fi

# The dashboard gear and the theme block switch to the Settings tab; the
# dashboard stays open, and the theme block deep-links to its section.
grep -q 'DashboardService.openSettings' "$DCENTER" \
    || fail "DashboardCenter gear does not open the settings tab"
grep -qF 'accessibleName: qsTr("Settings")' "$DCENTER" \
    || fail "DashboardCenter has no settings gear"
grep -qF 'DashboardService.activeTab === "settings" ? Colors.accent' "$DCENTER" \
    || fail "DashboardCenter gear does not mark the settings page active"
if grep -qF '{ key: "settings"' "$DSVC"; then
    fail "DashboardService.tabs still carries a Settings row tab; the gear owns settings"
fi
grep -qF 'DashboardService.openSettings("theme")' "$ROOT/windows/DashboardThemeBlock.qml" \
    || fail "DashboardThemeBlock does not deep-link to the theme section"
if grep -q 'SettingsService.close()' "$DSVC"; then
    fail "DashboardService still closes settings when the dashboard opens"
fi

# Cava editor is one component shared by the quick panel and settings, so the
# mirror is the same binding, not a copy.
test -f "$CSV" \
    || fail "windows/CavaSettingsView.qml is missing"
grep -q 'CavaSettingsView' "$ROOT/windows/CavaCenter.qml" \
    || fail "CavaCenter does not compose the shared CavaSettingsView"
grep -q 'CavaSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the shared CavaSettingsView"
grep -q 'property string filter' "$CSV" \
    || fail "CavaSettingsView has no filter property"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Style"))' "$CSV" \
    || fail "CavaSettingsView does not filter the Style option"
for label in "Sensitivity" "Auto sensitivity" "Bars" "Max height"; do
    grep -qF "SettingsFilter.matches(root.filter, qsTr(\"$label\"))" "$CSV" \
        || fail "CavaSettingsView does not filter the $label option"
    grep -qF "qsTr(\"$label\")" "$SSVC" \
        || fail "SettingsService sections do not list $label for search"
done
grep -qF 'qsTr("Style")' "$SSVC" \
    || fail "SettingsService sections do not list Style for search"

# Settings tokens: the dashboard width carries the surface, so the window
# width/height tokens are gone; the rail width and body cap remain.
grep -q 'property int settingsSidebarWidth' "$ROOT/config/Globals.qml" \
    || fail "Globals has no settingsSidebarWidth token"
grep -q 'property int settingsBodyMaxHeight' "$ROOT/config/Globals.qml" \
    || fail "Globals has no settingsBodyMaxHeight cap"
if grep -q 'property int settingsWidth' "$ROOT/config/Globals.qml"; then
    fail "Globals still has the removed settingsWidth token"
fi
if grep -q 'property int settingsHeight' "$ROOT/config/Globals.qml"; then
    fail "Globals still has the removed settingsHeight token"
fi
test -f "$ROOT/components/NavItem.qml" \
    || fail "components/NavItem.qml is missing"

# --- 10. settings domains: calendar zones plus feeds, DND mirror, motion ---
CAL="$ROOT/windows/CalendarSettingsView.qml"
WZE="$ROOT/windows/WorldClockEditor.qml"
NOTIF="$ROOT/windows/NotificationSettingsView.qml"
MOTION="$ROOT/windows/MotionSettingsView.qml"

# World clock add plus remove is one editor shared by the quick panel and
# settings, so the mirror is the same binding to CalendarService, not a copy.
test -f "$WZE" \
    || fail "windows/WorldClockEditor.qml is missing"
grep -q 'CalendarService.worldZones' "$WZE" \
    || fail "WorldClockEditor does not list CalendarService.worldZones"
grep -q 'CalendarService.addZone' "$WZE" \
    || fail "WorldClockEditor cannot add zones"
grep -q 'CalendarService.removeZone' "$WZE" \
    || fail "WorldClockEditor cannot remove zones"
grep -q 'CalendarService.isValidZoneName' "$WZE" \
    || fail "WorldClockEditor dropped the zone name validation"
grep -q 'CalendarService.maxZones' "$WZE" \
    || fail "WorldClockEditor dropped the zone cap"
grep -q 'WorldClockEditor' "$ROOT/windows/CalendarCenter.qml" \
    || fail "CalendarCenter does not compose the shared WorldClockEditor"

# Calendar settings section: zones plus feed toggles, filterable for search.
test -f "$CAL" \
    || fail "windows/CalendarSettingsView.qml is missing"
grep -q 'WorldClockEditor' "$CAL" \
    || fail "CalendarSettingsView does not compose the shared WorldClockEditor"
grep -q 'property string filter' "$CAL" \
    || fail "CalendarSettingsView has no filter property"
grep -q 'CalendarService.eventCalendars' "$CAL" \
    || fail "CalendarSettingsView does not list feeds"
grep -q 'CalendarService.setCalendarHidden' "$CAL" \
    || fail "CalendarSettingsView cannot toggle feeds"
grep -q 'CalendarSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Calendar section"

# DND switch mirrors the notification center: both bind NotificationServer.
test -f "$NOTIF" \
    || fail "windows/NotificationSettingsView.qml is missing"
grep -q 'NotificationServer.dndEnabled' "$NOTIF" \
    || fail "NotificationSettingsView does not read the shared DND state"
grep -q 'NotificationServer.toggleDnd' "$NOTIF" \
    || fail "NotificationSettingsView does not write the shared DND state"
grep -q 'NotificationServer.dndEnabled' "$ROOT/windows/NotificationCenter.qml" \
    || fail "NotificationCenter no longer reads the shared DND state"
grep -q 'NotificationSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Notifications section"

# Reduced motion switch gates the same Globals property every animation reads.
test -f "$MOTION" \
    || fail "windows/MotionSettingsView.qml is missing"
grep -q 'Globals.reducedMotion' "$MOTION" \
    || fail "MotionSettingsView does not switch Globals.reducedMotion"
grep -q 'Globals.reducedMotion' "$ROOT/components/Dropdown.qml" \
    || fail "Dropdown ignores Globals.reducedMotion; panel selects stay animated"
grep -q 'MotionSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Motion section"

# Weather city search writes the same WeatherService location the block reads.
WV="$ROOT/windows/WeatherSettingsView.qml"
test -f "$WV" \
    || fail "windows/WeatherSettingsView.qml is missing"
grep -q 'property string filter' "$WV" \
    || fail "WeatherSettingsView has no filter property"
grep -q 'WeatherService.locationName' "$WV" \
    || fail "WeatherSettingsView does not show the current city"
grep -q 'WeatherService.searchLocations' "$WV" \
    || fail "WeatherSettingsView cannot search cities"
grep -q 'WeatherService.selectLocation' "$WV" \
    || fail "WeatherSettingsView cannot select a city"
grep -q 'WeatherService.locationResults' "$WV" \
    || fail "WeatherSettingsView does not list search results"
grep -q 'WeatherSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Weather section"
grep -q 'weather-location' "$ROOT/services/WeatherService.qml" \
    || fail "WeatherService does not persist the city"

# Monitors section: a dropdown picks the primary from the connected screens,
# writes the one MonitorService, and the choice persists behind its StateFile.
MSVC="$ROOT/services/MonitorService.qml"
MVIEW="$ROOT/windows/MonitorSettingsView.qml"
test -f "$MSVC" \
    || fail "services/MonitorService.qml is missing"
test -f "$MVIEW" \
    || fail "windows/MonitorSettingsView.qml is missing"
grep -q '^singleton MonitorService 1.0 MonitorService.qml' "$ROOT/services/qmldir" \
    || fail "MonitorService is not registered in services/qmldir"
grep -q '^import qs.services' "$MSVC" \
    || fail "MonitorService.qml is missing its qs.services self-import"
grep -q 'name: "monitor-settings"' "$MSVC" \
    || fail "MonitorService does not persist to the monitor-settings state file"
STATEFILE="$ROOT/services/StateFile.qml"
grep -q 'if (!root.inCache && (root.loading || !root.loaded))' "$STATEFILE" \
    && grep -q 'function saveJson' "$STATEFILE" \
    || fail "StateFile does not own the save guard and the saveJson helper"
if grep -rn --include='*.qml' '\.save(JSON\.stringify(' "$ROOT/services" \
    | grep -v 'services/StateFile.qml' | grep -q .; then
    fail "a service still serializes JSON inline instead of going through saveJson"
fi
grep -q 'function setPrimary' "$MSVC" \
    || fail "MonitorService has no setPrimary"
grep -q 'function applySettings' "$MSVC" \
    || fail "MonitorService has no applySettings"
grep -q 'function saveSettings' "$MSVC" \
    || fail "MonitorService has no saveSettings"
grep -q 'property var screenNames' "$MSVC" \
    || fail "MonitorService exposes no screenNames"
grep -q 'Globals.screensByPosition' "$MSVC" \
    || fail "MonitorService does not derive its names from Globals.screensByPosition"
grep -q 'property var monitors' "$MSVC" \
    || fail "MonitorService exposes no monitor list"
grep -q 'function applyMonitors' "$MSVC" \
    || fail "MonitorService has no applyMonitors"
grep -q 'function setEnabled' "$MSVC" \
    || fail "MonitorService has no setEnabled"
grep -q '"monitors", "all", "-j"' "$MSVC" \
    || fail "MonitorService does not read the full hyprctl monitor list"
grep -q '"hyprctl", "eval"' "$MSVC" \
    || fail "MonitorService does not toggle through hyprctl eval"
grep -q 'MonitorLogic.setEnabledSpec' "$MSVC" \
    || fail "MonitorService does not build the Lua monitor spec through MonitorLogic"
grep -q 'import "MonitorLogic.js" as MonitorLogic' "$MSVC" \
    || fail "MonitorService does not import MonitorLogic.js"
grep -q 'MonitorLogic.orderMonitors' "$MSVC" \
    || fail "MonitorService does not derive the monitor order from MonitorLogic"
grep -q 'MonitorLogic.parseMonitorSettings' "$MSVC" \
    || fail "MonitorService does not parse its settings through MonitorLogic"
grep -q 'parsed.primary !== null' "$MSVC" \
    || fail "MonitorService lost the non-string primary guard"
if grep -q 'hyprctl", "keyword"' "$MSVC"; then
    fail "MonitorService uses hyprctl keyword, which the Lua config parser rejects"
fi
grep -q 'readonly property bool multiMonitor' "$MSVC" \
    || fail "MonitorService does not expose the last-display guard"
grep -q 'readonly property bool toggleBusy' "$MSVC" \
    || fail "MonitorService has no in-flight guard for rapid toggles"
grep -q 'property bool toggleSettling' "$MSVC" \
    || fail "MonitorService does not hold the guard through the post-command poll"
grep -q 'property int toggleEpoch' "$MSVC" \
    || fail "MonitorService does not epoch-guard the post-command settling clear"
grep -q 'idCommandWatchdog' "$MSVC" \
    || fail "MonitorService has no watchdog for a hung hyprctl command"
grep -q 'property bool pendingRefresh' "$MSVC" \
    || fail "MonitorService drops a refresh that lands mid-poll"
grep -q 'function escapeLua' "$MSVC" \
    || fail "MonitorService does not escape the output name for the Lua spec"
grep -q 'property bool monitorsLoaded' "$MSVC" \
    || fail "MonitorService does not track whether the first poll completed"
grep -q 'MonitorService.monitorsLoaded' "$MVIEW" \
    || fail "MonitorSettingsView can flash its empty note before the first poll"
grep -q 'MonitorService.toggleBusy' "$MVIEW" \
    || fail "MonitorSettingsView does not hold rows inert through a toggle"

grep -qF 'key: "monitors"' "$SSVC" \
    || fail "SettingsService has no monitors section"
grep -qF 'qsTr("Primary monitor")' "$SSVC" \
    || fail "SettingsService monitors options do not list Primary monitor"
grep -qF 'MonitorService.screenNames' "$SSVC" \
    || fail "SettingsService monitors options do not derive from MonitorService"
if grep -qE 'key: "monitors".*comingSoon: true' "$SSVC"; then
    fail "monitors section is still coming soon"
fi
grep -q 'property string filter' "$MVIEW" \
    || fail "MonitorSettingsView has no filter property"
grep -q 'Dropdown' "$MVIEW" \
    || fail "MonitorSettingsView does not use the shared Dropdown"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Primary monitor"))' "$MVIEW" \
    || fail "MonitorSettingsView does not match its Primary monitor search label, so searching it shows an empty body"
grep -q 'MonitorService.screenNames' "$MVIEW" \
    || fail "MonitorSettingsView does not list the connected screens"
grep -q 'MonitorService.setPrimary' "$MVIEW" \
    || fail "MonitorSettingsView does not write the primary through MonitorService"
grep -q 'SettingsToggleRow' "$MVIEW" \
    || fail "MonitorSettingsView does not compose the shared toggle row for displays"
grep -q 'model: MonitorService.monitorNames' "$MVIEW" \
    || fail "MonitorSettingsView keys its Repeater on the stable name list so a toggle does not rebuild the rows"
grep -q 'MonitorService.setEnabled' "$MVIEW" \
    || fail "MonitorSettingsView does not toggle a display through MonitorService"
grep -q 'MonitorService.rowState' "$MVIEW" \
    || fail "MonitorSettingsView does not read a consistent per-row display state"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Displays"))' "$MVIEW" \
    || fail "MonitorSettingsView does not match its Displays search label, so searching it shows an empty body"
grep -q 'property var monitorNames' "$MSVC" \
    || fail "MonitorService exposes no stable monitor name list"
grep -q 'property bool locked' "$ROOT/components/SettingsToggleRow.qml" \
    || fail "SettingsToggleRow cannot keep a true-state pill inert without dimming it"
grep -q 'property bool locked' "$ROOT/components/PillButton.qml" \
    || fail "PillButton cannot be locked without losing its highlight fill"
grep -q 'locked: MonitorService.toggleBusy || idMonitorToggle.lastDisplay' "$MVIEW" \
    || fail "MonitorSettingsView does not lock the last display (and busy rows) instead of dimming them"
grep -q 'onTextChanged: idHintSwapAnimation.restart()' "$ROOT/components/SettingsToggleRow.qml" \
    || fail "SettingsToggleRow does not animate a hint text swap"
grep -q 'readonly property var orderedMonitors' "$MSVC" \
    || fail "MonitorService has no orderedMonitors"
grep -q 'function firstWorkspaceFor' "$MSVC" \
    || fail "MonitorService has no firstWorkspaceFor"
grep -q 'function setWorkspacesPerMonitor' "$MSVC" \
    || fail "MonitorService has no setWorkspacesPerMonitor"
grep -q 'function clampWorkspacesPerMonitor' "$MSVC" \
    || fail "MonitorService does not clamp the workspace count"
grep -qF 'qsTr("Workspaces per monitor")' "$SSVC" \
    || fail "SettingsService monitors options do not list Workspaces per monitor"
grep -qF 'qsTr("Displays")' "$SSVC" \
    || fail "SettingsService monitors options do not list Displays"
grep -q 'MonitorService.monitors.map' "$SSVC" \
    || fail "SettingsService monitors options do not derive from MonitorService.monitors"
grep -q 'SettingsSliderRow' "$MVIEW" \
    || fail "MonitorSettingsView does not use the shared slider row for the workspace count"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Workspaces per monitor"))' "$MVIEW" \
    || fail "MonitorSettingsView does not match its Workspaces per monitor search label, so searching it shows an empty body"
grep -q 'value: MonitorService.workspacesPerMonitor' "$MVIEW" \
    || fail "MonitorSettingsView does not read the workspace count from MonitorService"
grep -q 'MonitorService.setWorkspacesPerMonitor' "$MVIEW" \
    || fail "MonitorSettingsView does not write the workspace count through MonitorService"
grep -q 'MonitorSettingsView' "$SCENTER" \
    || fail "SettingsView does not compose the Monitors section"
grep -qF 'root.currentSection.key === "monitors"' "$SCENTER" \
    || fail "SettingsView does not gate the Monitors section"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$MVIEW" "$MSVC"; then
    fail "monitors settings surface carries raw hex; palette tokens only"
fi

# Media section: one toggle per seen MPRIS app, persisted behind the
# MprisPlayers StateFile so the dashboard player and the bar share the filter.
MEDVIEW="$ROOT/windows/MediaSettingsView.qml"
MPLAYERS="$ROOT/services/MprisPlayers.qml"
test -f "$MEDVIEW" \
    || fail "windows/MediaSettingsView.qml is missing"
grep -q 'property string filter' "$MEDVIEW" \
    || fail "MediaSettingsView has no filter property"
grep -q 'MprisPlayers.seenPlayers' "$MEDVIEW" \
    || fail "MediaSettingsView does not list the seen players"
grep -q 'MprisPlayers.setAllowed' "$MEDVIEW" \
    || fail "MediaSettingsView cannot toggle a player"
grep -q 'SettingsToggleRow' "$MEDVIEW" \
    || fail "MediaSettingsView does not compose the shared toggle row"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Player"))' "$MEDVIEW" \
    || fail "MediaSettingsView does not match its Player search label, so searching it shows an empty body"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Apps"))' "$MEDVIEW" \
    || fail "MediaSettingsView does not match its Apps search label, so searching it shows an empty body"
grep -q 'MediaSettingsView' "$SCENTER" \
    || fail "SettingsView does not compose the Media section"
grep -qF 'root.currentSection.key === "media"' "$SCENTER" \
    || fail "SettingsView does not gate the Media section"
grep -qF 'key: "media"' "$SSVC" \
    || fail "SettingsService has no media section"
grep -qF 'qsTr("Apps")' "$SSVC" \
    || fail "SettingsService media options do not list Apps"
grep -qF 'MprisPlayers.seenPlayers.map' "$SSVC" \
    || fail "SettingsService media options do not derive from MprisPlayers.seenPlayers"
grep -q 'name: "mpris-players"' "$MPLAYERS" \
    || fail "MprisPlayers does not persist the media filter behind a StateFile"
grep -q 'const BROWSER_TOKENS' "$ROOT/services/MprisLogic.js" \
    || fail "MprisPlayers does not seed the browsers as hidden"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$MEDVIEW"; then
    fail "media settings surface carries raw hex; palette tokens only"
fi

# Dashboard junction radius: a slider writes the service across the whole
# range and the service persists it behind the StateFile load guard.
DJUNC="$ROOT/services/DashboardService.qml"
DVIEW="$ROOT/windows/DashboardSettingsView.qml"
test -f "$DVIEW" \
    || fail "windows/DashboardSettingsView.qml is missing"
grep -q 'property string filter' "$DVIEW" \
    || fail "DashboardSettingsView has no filter property"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Seam radius"))' "$DVIEW" \
    || fail "DashboardSettingsView does not match its Seam radius search label, so searching it shows an empty body"
grep -q 'from: 0' "$DVIEW" \
    || fail "DashboardSettingsView slider does not start at the square join"
grep -q 'to: Globals.junctionRadiusMax' "$DVIEW" \
    || fail "DashboardSettingsView slider does not span the junction radius range"
grep -q 'value: DashboardService.junctionRadius' "$DVIEW" \
    || fail "DashboardSettingsView slider does not read the shared radius"
grep -q 'DashboardService.setJunctionRadius' "$DVIEW" \
    || fail "DashboardSettingsView slider does not write the shared radius"
grep -q 'DashboardSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Dashboard section"
grep -qF 'key: "dashboard"' "$SSVC" \
    || fail "SettingsService has no dashboard section"
grep -qF 'qsTr("Seam radius")' "$SSVC" \
    || fail "SettingsService dashboard options do not list Seam radius"
grep -q 'name: "dashboard-junction"' "$DJUNC" \
    || fail "DashboardService does not persist the junction radius behind a StateFile"
grep -q 'function saveJunctionRadius' "$DJUNC" \
    || fail "DashboardService has no saveJunctionRadius"
grep -q 'function clampJunctionRadius' "$DJUNC" \
    || fail "DashboardService does not clamp the junction radius to its range"
test -f "$ROOT/components/SettingsSliderRow.qml" \
    || fail "components/SettingsSliderRow.qml is missing"
grep -q 'SettingsSliderRow' "$DVIEW" \
    || fail "DashboardSettingsView does not compose the shared slider row"
grep -q 'SettingsSliderRow' "$CSV" \
    || fail "CavaSettingsView does not compose the shared slider row"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$DVIEW" "$ROOT/components/SettingsSliderRow.qml"; then
    fail "dashboard settings surface carries raw hex; palette tokens only"
fi

# Oracle for DashboardService.clampJunctionRadius: round, clamp to 0..max,
# and keep the fallback when the value is not numeric. JS Number(null) is 0.
python3 - <<'EOF'
import math
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

def clamp_radius(value, fallback, maximum=32):
    if value is None or (isinstance(value, str) and value.strip() == ""):
        value = 0
    try:
        n = float(value)
    except (TypeError, ValueError):
        return fallback
    if math.isnan(n):
        return fallback
    if math.isinf(n):
        return 0 if n < 0 else maximum
    n = math.floor(n + 0.5)
    return max(0, min(maximum, n))

check("radius/high", clamp_radius(40, 16), 32)
check("radius/low", clamp_radius(-3, 16), 0)
check("radius/round", clamp_radius(7.5, 16), 8)
check("radius/zero", clamp_radius(0, 16), 0)
check("radius/numeric-text", clamp_radius("20", 16), 20)
check("radius/text", clamp_radius("nope", 16), 16)
check("radius/empty", clamp_radius("", 16), 0)
check("radius/whitespace", clamp_radius("  ", 16), 0)
check("radius/null", clamp_radius(None, 16), 0)
check("radius/infinite", clamp_radius(float("inf"), 16), 32)
check("radius/negative-infinite", clamp_radius(float("-inf"), 16), 0)
check("radius/missing", clamp_radius(float("nan"), 16), 16)
EOF

# Audio section: every detected output is listed with a visibility toggle and
# reorder arrows, all through AudioService. The dashboard list and the bar
# cycle read the same service.
AUDIOVIEW="$ROOT/windows/AudioSettingsView.qml"
AUDIOSVC="$ROOT/services/AudioService.qml"
test -f "$AUDIOVIEW" \
    || fail "windows/AudioSettingsView.qml is missing"
grep -q 'property string filter' "$AUDIOVIEW" \
    || fail "AudioSettingsView has no filter property"
grep -q 'AudioService.sinkNodes' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not list the detected outputs"
grep -q 'AudioService.setHidden' "$AUDIOVIEW" \
    || fail "AudioSettingsView cannot hide an output"
grep -q 'AudioService.moveOutput' "$AUDIOVIEW" \
    || fail "AudioSettingsView cannot reorder outputs"
if grep -q 'AudioService.setLabel\|labelOverrides' "$AUDIOVIEW"; then
    fail "AudioSettingsView still offers rename"
fi
grep -q 'SettingsFilter.matches' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not filter through the shared SettingsFilter"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Audio outputs"))' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not match its Audio outputs search label, so searching it shows an empty body"
grep -q 'AudioSettingsView' "$SCENTER" \
    || fail "SettingsView does not compose the Audio section"
grep -qF 'root.currentSection.key === "audio"' "$SCENTER" \
    || fail "SettingsView does not gate the Audio section"
grep -qF 'key: "audio"' "$SSVC" \
    || fail "SettingsService has no audio section"
grep -qF 'qsTr("Audio outputs")' "$SSVC" \
    || fail "SettingsService audio options do not list Audio outputs"
grep -qF 'AudioService.sinkNodes.map' "$SSVC" \
    || fail "SettingsService audio options do not derive from the detected outputs"
grep -q 'name: "audio-outputs"' "$AUDIOSVC" \
    || fail "AudioService does not persist curated outputs behind a StateFile"
grep -q 'function setHidden' "$AUDIOSVC" \
    || fail "AudioService has no setHidden"
grep -q 'function moveOutput' "$AUDIOSVC" \
    || fail "AudioService has no moveOutput"
grep -q 'function applySettings' "$AUDIOSVC" \
    || fail "AudioService has no applySettings"
grep -q 'function persist' "$AUDIOSVC" \
    || fail "AudioService has no persist"
if grep -q 'function setLabel\|labelOverrides' "$AUDIOSVC"; then
    fail "AudioService still carries rename state"
fi

# Volume OSD: one switch on AudioService, filtered and registered, read by the
# OSD window and written back with the same persist path as the output state.
grep -q 'property bool osdEnabled' "$AUDIOSVC" \
    || fail "AudioService has no osdEnabled state"
grep -q 'function setOsdEnabled' "$AUDIOSVC" \
    || fail "AudioService has no setOsdEnabled"
grep -q 'payload\["osdEnabled"\]' "$AUDIOSVC" \
    || fail "AudioService does not persist osdEnabled"
grep -q 'AudioService.osdEnabled' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not bind AudioService.osdEnabled"
grep -q 'AudioService.setOsdEnabled' "$AUDIOVIEW" \
    || fail "AudioSettingsView cannot toggle the volume OSD"
grep -q 'SettingsToggleRow' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not compose the shared toggle row"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Volume OSD"))' "$AUDIOVIEW" \
    || fail "AudioSettingsView does not match its Volume OSD search label, so searching it shows an empty body"
grep -qF 'qsTr("Volume OSD")' "$SSVC" \
    || fail "SettingsService audio options do not list Volume OSD"
grep -q 'AudioService.osdEnabled' "$ROOT/windows/VolumeOsd.qml" \
    || fail "VolumeOsd does not check AudioService.osdEnabled"
osd_off="$(awk '/function onOsdEnabledChanged/,/^        }$/' "$ROOT/windows/VolumeOsd.qml")"
test -n "$osd_off" || fail "VolumeOsd does not react to the Volume OSD setting turning off"
printf '%s\n' "$osd_off" | grep -q 'root.shown = false' \
    || fail "VolumeOsd does not hide when the Volume OSD setting turns off"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$AUDIOVIEW" "$AUDIOSVC"; then
    fail "audio settings surface carries raw hex; palette tokens only"
fi

# Both toggle sections share one row component, so On/Off plus hint cannot drift.
test -f "$ROOT/components/SettingsToggleRow.qml" \
    || fail "components/SettingsToggleRow.qml is missing"
grep -q 'SettingsToggleRow' "$NOTIF" \
    || fail "NotificationSettingsView does not compose the shared toggle row"
grep -q 'SettingsToggleRow' "$MOTION" \
    || fail "MotionSettingsView does not compose the shared toggle row"

# Sections surface in settings search through the options list.
grep -qF 'qsTr("World clock")' "$SSVC" \
    || fail "SettingsService Calendar options do not list World clock"
grep -qF 'qsTr("Feeds")' "$SSVC" \
    || fail "SettingsService Calendar options do not list Feeds"
grep -qF 'qsTr("Do not disturb")' "$SSVC" \
    || fail "SettingsService Notifications options do not list Do not disturb"
grep -qF 'qsTr("Reduced motion")' "$SSVC" \
    || fail "SettingsService Motion options do not list Reduced motion"
grep -qF 'qsTr("City")' "$SSVC" \
    || fail "SettingsService Weather options do not list City"
grep -qF 'qsTr("Location")' "$SSVC" \
    || fail "SettingsService Weather options do not list Location"

# Theme section: the catalog renders as one repeated selectable row per theme,
# the active theme is marked, and selection writes the shared ThemeService the
# bar repaints from with no restart.
THEMEVIEW="$ROOT/windows/ThemeSettingsView.qml"
test -f "$THEMEVIEW" \
    || fail "windows/ThemeSettingsView.qml is missing"
grep -q 'property string filter' "$THEMEVIEW" \
    || fail "ThemeSettingsView has no filter property"
grep -q 'Repeater' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not render the catalog through a repeater"
grep -q 'NavItem' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not compose the shared row component"
grep -q 'ThemeService.catalog' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not list the catalog"
grep -q 'ThemeService.activeTheme' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not mark the active theme"
grep -q 'ThemeService.selectTheme' "$THEMEVIEW" \
    || fail "ThemeSettingsView cannot switch themes"
grep -q 'modelData.swatches' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not render each theme's preview swatches"
grep -q 'readonly property var themeSwatches' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not guard the delegate's modelData"
grep -q 'Globals.themeSwatchChipSize' "$THEMEVIEW" \
    || fail "ThemeSettingsView swatches do not use the shared chip size"
grep -q 'trailingWidth' "$ROOT/components/NavItem.qml" \
    || fail "NavItem has no trailing slot for the theme swatches"
grep -q 'themeSwatchChipSize' "$ROOT/config/Globals.qml" \
    || fail "Globals has no themeSwatchChipSize token"
grep -q 'SettingsFilter.matches' "$THEMEVIEW" \
    || fail "ThemeSettingsView does not filter through the shared SettingsFilter"
grep -q 'ThemeService' "$ROOT/config/Colors.qml" \
    || fail "Colors no longer mirrors ThemeService; a section switch cannot repaint the bar"
grep -q 'ThemeSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Theme section"
grep -qF 'key: "theme"' "$SSVC" \
    || fail "SettingsService has no theme section"
grep -qF 'ThemeService.catalog' "$SSVC" \
    || fail "SettingsService theme options do not derive from the catalog"
grep -qF 'ThemeService.catalog.map(theme => theme.name)' "$SSVC" \
    || fail "SettingsService theme options do not list the catalog slugs"
grep -qF 'ThemeService.catalog.map(theme => theme.displayName)' "$SSVC" \
    || fail "SettingsService theme options do not list the catalog display names"
grep -qF 'options: [qsTr("Theme")]' "$SSVC" \
    || fail "SettingsService theme options do not list Theme"

# Settings filtering lives once: every view delegates to the shared
# SettingsFilter rather than copying the predicate into its own matches().
FILTER="$ROOT/services/SettingsFilter.qml"
test -f "$FILTER" \
    || fail "services/SettingsFilter.qml is missing"
grep -q '^singleton SettingsFilter 1.0 SettingsFilter.qml' "$ROOT/services/qmldir" \
    || fail "SettingsFilter is not registered in services/qmldir"
grep -q 'function matches' "$FILTER" \
    || fail "SettingsFilter has no matches()"
grep -q 'function filtering' "$FILTER" \
    || fail "SettingsFilter has no filtering()"
for view in "$CSV" "$CAL" "$WV" "$ROOT/windows/LayoutSettingsView.qml" "$NOTIF" "$MOTION" "$THEMEVIEW" "$AUDIOVIEW"; do
    grep -q 'SettingsFilter' "$view" \
        || fail "$(basename "$view") does not filter through the shared SettingsFilter"
done
if grep -rn --include='*.qml' 'includes(root.filter' "$ROOT/windows" "$ROOT/services" | grep -q .; then
    fail "a settings view copies the filter predicate instead of using SettingsFilter"
fi

# Zones plus feeds persist through the CalendarService state files; the parse
# validation is unchanged. WeatherService delegates its location parsers to
# WeatherLogic.js, which runs under node here; StateParsers follows.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/WeatherLogic.js" <<'NODEEOF'
// WeatherLogic.parseLocations: geocoding results map to name plus label plus
// coordinates, capped at 5, dropping blank names and out-of-range coordinates.
// isValidLocation is the validation applyLocation runs on a saved city.
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const wl = qmljs.load(process.argv[3]);

const GEOCODE = '{"results": [{"name": "Berlin", "admin1": "Berlin", "country": "Germany", "latitude": 52.52, "longitude": 13.41}, {"name": "", "latitude": 0, "longitude": 0}, {"name": "Nowhere", "latitude": 91, "longitude": 0}]}';
check('locations/fixture', wl.parseLocations(GEOCODE),
      [{ name: 'Berlin', label: 'Berlin, Berlin (Germany)', latitude: 52.52, longitude: 13.41 }]);
check('locations/malformed', wl.parseLocations('{nope'), []);
check('locations/no-results', wl.parseLocations('{"results": []}'), []);
check('locations/missing-results', wl.parseLocations('{}'), []);

check('location/valid', wl.isValidLocation({ name: 'Paris', latitude: 48.85, longitude: 2.35 }), true);
check('location/blank-name', wl.isValidLocation({ name: '  ', latitude: 48.85, longitude: 2.35 }), false);
check('location/bad-lat', wl.isValidLocation({ name: 'Paris', latitude: 91, longitude: 2.35 }), false);
check('location/bad-lon', wl.isValidLocation({ name: 'Paris', latitude: 48.85, longitude: 200 }), false);
check('location/malformed', wl.isValidLocation({ name: 'Paris' }), false);
NODEEOF

node - "$ROOT/tests/qmljs.js" "$ROOT/services/StateParsers.js" <<'NODEEOF'
// StateParsers.parseZones: trim, reject names failing the regex, drop
// duplicates, cap at CalendarService.maxZones = 6. parseCavaSettings clamps
// each setting into the [min, max, fallback] range CavaService passes;
// parseAudioSettings and parseFontSettings keep only well-typed fields.
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const sp = qmljs.load(process.argv[3]);
const zones = text => sp.parseZones(text, 6);
check('zones/trim-dedupe', zones(' UTC \nUTC\nEurope/Berlin\n'), ['UTC', 'Europe/Berlin']);
check('zones/reject-invalid', zones('UTC\nbad name\nAsia/Tokyo\n'), ['UTC', 'Asia/Tokyo']);
check('zones/cap', zones(Array.from({ length: 10 }, (_, i) => 'Z' + i).join('\n')), ['Z0', 'Z1', 'Z2', 'Z3', 'Z4', 'Z5']);
check('zones/empty', zones(''), []);

const LIMITS = {
    sensitivity: [100, 5000, 1200],
    barCount: [4, 32, 14],
    styleMode: [0, 5, 0],
    maxHeight: [6, 20, 20]
};
const cava = value => sp.parseCavaSettings(typeof value === 'string' ? value : JSON.stringify(value), LIMITS);
check('cava/in-range', cava({ sensitivity: 800, autoSensitivity: true, barCount: 20, styleMode: 3, maxHeight: 12 }),
      { sensitivity: 800, autoSensitivity: true, barCount: 20, styleMode: 3, maxHeight: 12 });
check('cava/upper-clamp', cava({ sensitivity: 9999, barCount: 99, styleMode: 9, maxHeight: 50 }),
      { sensitivity: 5000, autoSensitivity: false, barCount: 32, styleMode: 5, maxHeight: 20 });
check('cava/lower-clamp', cava({ sensitivity: 1, barCount: 0, styleMode: -3, maxHeight: 1 }),
      { sensitivity: 100, autoSensitivity: false, barCount: 4, styleMode: 0, maxHeight: 6 });
check('cava/missing-falls-back', cava({}),
      { sensitivity: 1200, autoSensitivity: false, barCount: 14, styleMode: 0, maxHeight: 20 });
check('cava/non-numeric-falls-back', cava({ sensitivity: 'loud', barCount: 'many' }).barCount, 14);
check('cava/rounds', cava({ barCount: 13.6 }).barCount, 14);
check('cava/numeric-string', cava({ sensitivity: '900' }).sensitivity, 900);
check('cava/auto-one', cava({ autoSensitivity: 1 }).autoSensitivity, true);
check('cava/auto-string', cava({ autoSensitivity: 'true' }).autoSensitivity, false);
check('cava/malformed', cava('{nope'), null);
check('cava/null', cava('null'), null);
check('cava/number', cava('5'), null);

const audio = text => sp.parseAudioSettings(text);
check('audio/lists', audio('{"hidden": ["a", 1, "b"], "order": ["c", null]}'), { hidden: ['a', 'b'], order: ['c'], osdEnabled: true });
check('audio/missing', audio('{}'), { hidden: [], order: [], osdEnabled: true });
check('audio/not-a-list', audio('{"hidden": "a", "order": {"x": 1}}'), { hidden: [], order: [], osdEnabled: true });
check('audio/osd-missing', audio('{}').osdEnabled, true);
check('audio/osd-false', audio('{"osdEnabled": false}').osdEnabled, false);
check('audio/osd-true', audio('{"osdEnabled": true}').osdEnabled, true);
check('audio/osd-non-bool', audio('{"osdEnabled": "no"}').osdEnabled, true);
check('audio/osd-existing-shape', audio('{"hidden": ["a"], "order": ["b"]}'), { hidden: ['a'], order: ['b'], osdEnabled: true });
check('audio/array', audio('["a"]'), null);
check('audio/malformed', audio('{nope'), null);
check('audio/null', audio('null'), null);

const font = text => sp.parseFontSettings(text);
check('font/all', font('{"uiFamily": "Geist", "monoFamily": "Iosevka", "iconFamily": "Symbols"}'),
      { uiFamily: 'Geist', monoFamily: 'Iosevka', iconFamily: 'Symbols' });
check('font/drops-non-string-and-unknown', font('{"uiFamily": 3, "monoFamily": "Iosevka", "other": "x"}'),
      { monoFamily: 'Iosevka' });
check('font/empty', font('{}'), {});
check('font/array', font('["Geist"]'), null);
check('font/malformed', font('{nope'), null);

// parseNotificationSettings: a missing or non-bool dnd counts as off (the
// default), while malformed input and non-objects return null so the caller
// keeps its current state.
const notify = text => sp.parseNotificationSettings(text);
check('notify/true', notify('{"dnd": true}'), { dnd: true });
check('notify/false', notify('{"dnd": false}'), { dnd: false });
check('notify/missing-key', notify('{}'), { dnd: false });
check('notify/non-bool', notify('{"dnd": "yes"}'), { dnd: false });
check('notify/null-value', notify('{"dnd": null}'), { dnd: false });
check('notify/malformed', notify('{nope'), null);
check('notify/null', notify('null'), null);
check('notify/array', notify('[true]'), null);
check('notify/number', notify('5'), null);
NODEEOF

# --- 11. bar module visibility: one switch per module, persisted ---
BSVC="$ROOT/services/BarVisibilityService.qml"
BVIEW="$ROOT/windows/LayoutSettingsView.qml"

test -f "$BSVC" \
    || fail "services/BarVisibilityService.qml is missing"
grep -q '^singleton BarVisibilityService 1.0 BarVisibilityService.qml' "$ROOT/services/qmldir" \
    || fail "BarVisibilityService is not registered in services/qmldir"
grep -q 'property var moduleVisible' "$BSVC" \
    || fail "BarVisibilityService has no moduleVisible state"
grep -q 'function isVisible' "$BSVC" \
    || fail "BarVisibilityService has no isVisible"
grep -q 'function setVisible' "$BSVC" \
    || fail "BarVisibilityService has no setVisible"
grep -q 'function parseVisibility' "$BSVC" \
    || fail "BarVisibilityService has no parseVisibility"
# The node runs below exercise StateParsers.js directly, so each service that
# delegates to it must keep the call site; otherwise a re-inlined copy passes.
grep -q 'StateParsers.parseVisibility' "$BSVC" \
    || fail "BarVisibilityService does not delegate parseVisibility to StateParsers"
for pair in \
    "services/AudioService.qml:StateParsers.parseAudioSettings" \
    "services/FontService.qml:StateParsers.parseFontSettings" \
    "services/CavaService.qml:StateParsers.parseCavaSettings" \
    "services/CalendarService.qml:StateParsers.parseZones" \
    "services/CalendarService.qml:StateParsers.parseZoneList" \
    "services/CalendarService.qml:StateParsers.isValidZoneName"; do
    file="${pair%%:*}"
    call="${pair#*:}"
    grep -q "$call" "$ROOT/$file" \
        || fail "$file does not delegate $call to StateParsers"
done
grep -q 'StateFile {' "$BSVC" \
    || fail "BarVisibilityService does not compose StateFile"
grep -q 'bar-visibility' "$BSVC" \
    || fail "BarVisibilityService does not persist to the bar-visibility state file"
for pair in "clock:Clock" "workspaces:Workspaces" "tray:Tray" "cava:Cava" "media:Media" "audio:Audio" "notifications:Notifications" "power:Power"; do
    key="${pair%%:*}"
    title="${pair##*:}"
    grep -q "\"$key\"" "$BSVC" \
        || fail "BarVisibilityService module list misses key $key"
    grep -qF "qsTr(\"$title\")" "$BSVC" \
        || fail "BarVisibilityService module list misses title $title"
done

# Every bar module composes the shared visibility gate with its own key; the
# dashboard title (ActiveWindow) is the dashboard trigger and stays unlisted.
for pair in "Clock:clock" "Workspaces:workspaces" "Tray:tray" "Cava:cava" "Media:media" "Audio:audio" "Notifications:notifications" "PowerMenu:power"; do
    module="${pair%%:*}"
    key="${pair##*:}"
    grep -q "BarVisibilityService.isVisible(\"$key\")" "$ROOT/modules/$module.qml" \
        || fail "$module.qml does not compose the bar visibility gate for $key"
done
if grep -q 'BarVisibilityService' "$ROOT/modules/ActiveWindow.qml"; then
    fail "ActiveWindow is gated by bar visibility; the dashboard trigger must stay"
fi

# Layout section: options derive from the one module list, plus a discoverable
# label; a real body of toggle rows renders per module.
grep -qF 'key: "layout"' "$ROOT/services/SettingsService.qml" \
    || fail "SettingsService has no layout section"
grep -qF 'BarVisibilityService.modules' "$ROOT/services/SettingsService.qml" \
    || fail "SettingsService layout options do not derive from the module list"
grep -qF 'qsTr("Bar visibility")' "$ROOT/services/SettingsService.qml" \
    || fail "SettingsService layout options do not list Bar visibility"
if grep -qF 'key: "layout", title: qsTr("Layout"), options: [], comingSoon: true' "$ROOT/services/SettingsService.qml"; then
    fail "layout section is still coming soon"
fi

test -f "$BVIEW" \
    || fail "windows/LayoutSettingsView.qml is missing"
grep -q 'property string filter' "$BVIEW" \
    || fail "LayoutSettingsView has no filter property"
grep -q 'BarVisibilityService.modules' "$BVIEW" \
    || fail "LayoutSettingsView does not list the bar modules"
grep -q 'SettingsToggleRow' "$BVIEW" \
    || fail "LayoutSettingsView does not compose the shared toggle row"
grep -q 'BarVisibilityService.isVisible' "$BVIEW" \
    || fail "LayoutSettingsView does not read module visibility"
grep -q 'BarVisibilityService.setVisible' "$BVIEW" \
    || fail "LayoutSettingsView does not write module visibility"
grep -qF 'SettingsFilter.matches(root.filter, qsTr("Bar visibility"))' "$BVIEW" \
    || fail "LayoutSettingsView does not match its Bar visibility search label, so searching it shows an empty body"
grep -q 'LayoutSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Layout section"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$BVIEW" "$BSVC"; then
    fail "bar visibility surface carries raw hex; palette tokens only"
fi

# parseVisibility oracle: default all true, only an explicit false hides,
# unknown keys ignored, malformed input falls back to defaults.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/StateParsers.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const sp = qmljs.load(process.argv[3]);
const KEYS = ['clock', 'workspaces', 'tray', 'cava', 'media', 'audio', 'notifications', 'power'];
const all = () => ({ clock: true, workspaces: true, tray: true, cava: true, media: true, audio: true, notifications: true, power: true });
const barvis = text => sp.parseVisibility(text, KEYS);
check('barvis/default', barvis(''), all());
check('barvis/malformed', barvis('{nope'), all());
check('barvis/list', barvis('[1, 2]'), all());
check('barvis/hide', barvis('{"media": false}').media, false);
check('barvis/kept', barvis('{"media": false}').clock, true);
check('barvis/unknown', barvis('{"nope": false}'), all());
check('barvis/nonbool', barvis('{"clock": 0}').clock, true);
NODEEOF

# Bar margins: two shared slider rows write the one BarMarginService, which
# clamps to the Globals range and persists behind the StateFile load guard.
# The shell reads the writable Globals tokens, not moduleMargin/horizontalBarMargin.
BMSVC="$ROOT/services/BarMarginService.qml"
test -f "$BMSVC" \
    || fail "services/BarMarginService.qml is missing"
grep -q '^singleton BarMarginService 1.0 BarMarginService.qml' "$ROOT/services/qmldir" \
    || fail "BarMarginService is not registered in services/qmldir"
grep -q 'name: "bar-margins"' "$BMSVC" \
    || fail "BarMarginService does not persist to the bar-margins state file"
grep -q 'function setMargin' "$BMSVC" \
    || fail "BarMarginService has no keyed setMargin"
grep -q 'function valueFor' "$BMSVC" \
    || fail "BarMarginService has no valueFor"
grep -q 'function maximumFor' "$BMSVC" \
    || fail "BarMarginService has no maximumFor"
grep -q 'function clampMargin' "$BMSVC" \
    || fail "BarMarginService has no keyed clampMargin"
grep -q 'readonly property var rows' "$BMSVC" \
    || fail "BarMarginService exposes no rows list"
grep -qF 'qsTr("Top margin")' "$BMSVC" \
    || fail "BarMarginService rows do not list Top margin"
grep -qF 'qsTr("Side margin")' "$BMSVC" \
    || fail "BarMarginService rows do not list Side margin"
grep -q 'function applySettings' "$BMSVC" \
    || fail "BarMarginService has no applySettings"
grep -q 'function saveSettings' "$BMSVC" \
    || fail "BarMarginService has no saveSettings"
grep -q 'StateParsers.parseBarMargins' "$BMSVC" \
    || fail "BarMarginService does not delegate parseBarMargins to StateParsers"
grep -q 'Globals.barTopMarginMax' "$BMSVC" \
    || fail "BarMarginService does not clamp the top margin to the Globals range"
grep -q 'Globals.barSideMarginMax' "$BMSVC" \
    || fail "BarMarginService does not clamp the side margin to the Globals range"
grep -q '^import qs.config' "$BMSVC" \
    || fail "BarMarginService does not import qs.config for the Globals tokens"
grep -q '^import qs.services' "$BMSVC" \
    || fail "BarMarginService is missing its qs.services self-import"

# Globals: writable margins with ranges; the derived insets follow the side
# margin so the bar interior and panel edge stay aligned with the slab.
grep -q 'property int barTopMargin' "$ROOT/config/Globals.qml" \
    || fail "Globals has no writable barTopMargin"
grep -q 'property int barSideMargin' "$ROOT/config/Globals.qml" \
    || fail "Globals has no writable barSideMargin"
grep -q 'property int barTopMarginMax' "$ROOT/config/Globals.qml" \
    || fail "Globals has no barTopMarginMax"
grep -q 'property int barSideMarginMax' "$ROOT/config/Globals.qml" \
    || fail "Globals has no barSideMarginMax"
grep -q 'panelEdgeMargin: root.barSideMargin' "$ROOT/config/Globals.qml" \
    || fail "Globals panelEdgeMargin does not follow the side margin"
grep -q 'slabInset: root.barSideMargin' "$ROOT/config/Globals.qml" \
    || fail "Globals slabInset does not follow the side margin"
if grep -q 'horizontalBarMargin' "$ROOT/config/Globals.qml"; then
    fail "horizontalBarMargin is back; barSideMargin is the single side token"
fi

# Shell: the slab, the window height, and the layout read the writable margins.
grep -q 'Globals.barHeight + Globals.barTopMargin' "$ROOT/shell.qml" \
    || fail "shell bar window height does not follow the top margin"
grep -q 'topMargin: Globals.barTopMargin' "$ROOT/shell.qml" \
    || fail "shell slab does not follow the top margin"
grep -q 'leftMargin: Globals.barSideMargin' "$ROOT/shell.qml" \
    || fail "shell slab does not follow the side margin"
grep -q 'rightMargin: Globals.barSideMargin' "$ROOT/shell.qml" \
    || fail "shell slab does not follow the side margin"
if grep -q 'Globals.moduleMargin' "$ROOT/shell.qml"; then
    fail "shell still places the bar with moduleMargin; the outer margin is barTopMargin"
fi
grep -q 'Globals.barSideMargin' "$ROOT/windows/NotificationPopups.qml" \
    || fail "NotificationPopups does not follow the side margin"
grep -q 'Globals.barHeight + Globals.barTopMargin' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not offset panels by the top margin, so panels detach from a moved bar"
if grep -q 'Globals.moduleMargin' "$ROOT/components/PanelShell.qml"; then
    fail "PanelShell still offsets panels with moduleMargin; the bar top gap is barTopMargin"
fi
if grep -q 'horizontalBarMargin' "$ROOT/shell.qml" "$ROOT/windows/NotificationPopups.qml"; then
    fail "horizontalBarMargin survives; barSideMargin is the single side token"
fi

# Layout view: one shared slider row per margin, driven by the service rows so
# the search labels derive from the same list the registry registers.
grep -q 'SettingsSliderRow' "$BVIEW" \
    || fail "LayoutSettingsView does not compose the shared slider row for margins"
grep -q 'model: BarMarginService.rows' "$BVIEW" \
    || fail "LayoutSettingsView does not render the margin rows from the service list"
grep -q 'SettingsFilter.matches(root.filter, modelData.label)' "$BVIEW" \
    || fail "LayoutSettingsView does not filter the margin rows by their label"
grep -q 'to: modelData.max' "$BVIEW" \
    || fail "LayoutSettingsView margin slider does not span the service range"
grep -q 'BarMarginService.valueFor(modelData.key)' "$BVIEW" \
    || fail "LayoutSettingsView margin slider does not read the shared value"
grep -q 'BarMarginService.setMargin(modelData.key, newValue)' "$BVIEW" \
    || fail "LayoutSettingsView margin slider does not write through BarMarginService"
grep -q 'BarMarginService.rows.map' "$SSVC" \
    || fail "SettingsService layout options do not derive from the margin rows"

# parseBarMargins oracle: only numeric margins survive, malformed input falls
# back to null, and the service clamps the survivors into their range.
node - "$ROOT/tests/qmljs.js" "$ROOT/services/StateParsers.js" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const sp = qmljs.load(process.argv[3]);
const margins = text => sp.parseBarMargins(text);
check('barmargins/all', margins('{"topMargin": 8, "sideMargin": 20}'), { topMargin: 8, sideMargin: 20 });
check('barmargins/partial', margins('{"topMargin": 0}'), { topMargin: 0 });
check('barmargins/drops-non-number', margins('{"topMargin": "8", "sideMargin": true}'), {});
check('barmargins/unknown-keys', margins('{"topMargin": 8, "other": 3}'), { topMargin: 8 });
check('barmargins/empty', margins('{}'), {});
check('barmargins/array', margins('[1, 2]'), null);
check('barmargins/null', margins('null'), null);
check('barmargins/malformed', margins('{nope'), null);
NODEEOF

# --- 12. dev probe is opt-in and covers the live-verification surface ---
PROBE="$ROOT/dev/DevProbe.qml"
test -f "$PROBE" \
    || fail "dev/DevProbe.qml is missing"
grep -qF 'target: "devprobe"' "$PROBE" \
    || fail "DevProbe has no devprobe target"
grep -q 'QUICKSHELL_DEV_PROBE' "$PROBE" \
    || fail "DevProbe is not gated by QUICKSHELL_DEV_PROBE"
grep -q 'quickshell-dev-probe' "$PROBE" \
    || fail "DevProbe has no runtime flag-file escape hatch"
grep -q 'DevProbe' "$ROOT/shell.qml" \
    || fail "shell.qml does not instantiate DevProbe"
for fn in "function state" "function toggle" "function closeAll" "function toggleDnd" "function setReducedMotion" "function addZone" "function removeZone" "function setFeedHidden"; do
    grep -q "$fn" "$PROBE" \
        || fail "DevProbe is missing $fn"
done

# The settings-section seam and the shared-row rule are documented where the
# navigator and the reviewer reach them.
test -f "$ROOT/docs/dev/settings-sections.md" \
    || fail "docs/dev/settings-sections.md is missing"
grep -q 'settings-sections.md' "$ROOT/AGENTS.md" \
    || fail "AGENTS.md does not point at docs/dev/settings-sections.md"
grep -q 'SettingsToggleRow' "$ROOT/docs/dev/CODING_STANDARDS.md" \
    || fail "coding standards do not require shared settings rows"

# --- 13. one shared focus grab across the panel shells ---
# The dashboard and a quick panel are separate windows; two HyprlandFocusGrabs
# clear each other, so exactly one grab whitelists every visible shell and
# routes an outside clear to all of them. Escape stays per window.
PGRAB="$ROOT/services/PanelGrab.qml"
test -f "$PGRAB" \
    || fail "services/PanelGrab.qml is missing"
grep -q '^singleton PanelGrab 1.0 PanelGrab.qml' "$ROOT/services/qmldir" \
    || fail "PanelGrab is not registered in services/qmldir"
if grep -q 'HyprlandFocusGrab' "$ROOT/components/PanelShell.qml"; then
    fail "PanelShell still owns a focus grab; the shared grab lives in services/PanelGrab.qml"
fi
grep -q 'HyprlandFocusGrab' "$PGRAB" \
    || fail "PanelGrab does not own the HyprlandFocusGrab"
GRAB_OWNERS="$(grep -rl 'HyprlandFocusGrab' "$ROOT/components" "$ROOT/windows" "$ROOT/modules" "$ROOT/services" "$ROOT/config" "$ROOT/dev" | wc -l)"
test "$GRAB_OWNERS" -eq 1 \
    || fail "expected exactly one HyprlandFocusGrab owner, found $GRAB_OWNERS"
grep -q 'PanelGrab.register(root)' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not register with the shared grab"
grep -q 'PanelGrab.unregister(root)' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not unregister from the shared grab"
grep -q 'sequence: "Escape"' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell lost its per-window Escape shortcut"
grep -q 'enabled: root.panelVisible' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell Escape is not gated on the panel being open"
grep -q 'windows: root.windows' "$PGRAB" \
    || fail "PanelGrab does not feed the computed whitelist to the grab"
grep -q 'active: root.active' "$PGRAB" \
    || fail "PanelGrab does not gate the grab on any visible panel"
grep -q 'member.panelVisible' "$PGRAB" \
    || fail "PanelGrab does not whitelist only visible panel shells"
grep -q 'onCleared: root.dismiss()' "$PGRAB" \
    || fail "PanelGrab does not route the outside clear to dismiss"
grep -q 'outsideClicked()' "$PGRAB" \
    || fail "PanelGrab does not dismiss through each shell's outsideClicked"
# The bar is shell chrome, not a panel, but the user opens panels from it. A
# bar click outside the grab would clear it and dismiss the dashboard before
# the trigger fires, so the always-visible bar stays whitelisted.
grep -q 'PanelGrab.registerBar(idPanelWindow)' "$ROOT/shell.qml" \
    || fail "shell.qml does not register the bar with the shared grab"
grep -q 'PanelGrab.unregisterBar(idPanelWindow)' "$ROOT/shell.qml" \
    || fail "shell.qml does not unregister the bar from the shared grab"
grep -q 'barWindows.concat' "$PGRAB" \
    || fail "PanelGrab does not fold the always-visible bar into the grab"

# Each quick panel hands PanelShell its PanelState, so the window binds one
# property and PanelShell owns the outside-click close; the dashboard keeps
# its explicit bindings with panel null.
for pair in \
    "windows/CavaCenter.qml:CavaService" \
    "windows/CalendarCenter.qml:CalendarService" \
    "windows/NotificationCenter.qml:NotificationServer" \
    "windows/PowerCenter.qml:PowerService"; do
    file="${pair%%:*}"
    service="${pair##*:}"
    grep -q "panel: $service.panelState" "$ROOT/$file" \
        || fail "$file does not hand PanelShell $service.panelState"
    if grep -qE '(cavaVisible|calendarVisible|centerVisible|powerVisible)' "$ROOT/$file"; then
        fail "$file still binds a service visibility alias"
    fi
done
grep -q 'property PanelState panel: null' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not take the panel's PanelState"
grep -q 'root.panel.closeFromOutside()' "$ROOT/components/PanelShell.qml" \
    || fail "PanelShell does not close the panel from outside"
grep -q 'onVisibleChanged: root.armedAction = ""' "$PSVC" \
    || fail "PowerService does not reset the armed action when its panel toggles"

# --- 14. theme service: palette model plus guarded colors.toml read ---
# ThemeService answers "what is the palette right now" only. The palette is
# read from a quickshell-owned theme root through one guarded door (regular
# file, not a symlink, size capped) and normalized by pure functions in
# ThemeParsers.js. Catalog listing is ticket 03, the desktop renderer is
# ticket 05; neither belongs here.
TSVC="$ROOT/services/ThemeService.qml"
TPARSE="$ROOT/services/ThemeParsers.js"
test -f "$TSVC" \
    || fail "services/ThemeService.qml is missing"
test -f "$TPARSE" \
    || fail "services/ThemeParsers.js is missing"
grep -q '^singleton ThemeService 1.0 ThemeService.qml' "$ROOT/services/qmldir" \
    || fail "ThemeService is not registered in services/qmldir"
grep -q '^import qs.services' "$TSVC" \
    || fail "ThemeService.qml is missing its qs.services self-import"
grep -qF 'quickshell/themes' "$TSVC" \
    || fail "ThemeService does not resolve the quickshell theme root"
if grep -q 'omarchy' "$TSVC"; then
    fail "ThemeService names an omarchy path; the theme root is quickshell-owned"
fi
grep -q 'name: "theme"' "$TSVC" \
    || fail "ThemeService does not persist the selection to the theme state file"
grep -qF '"colors.toml"' "$TSVC" \
    || fail "ThemeService does not read colors.toml"
grep -q '"stat"' "$TSVC" \
    || fail "ThemeService does not stat colors.toml before reading it"
grep -q 'ThemeParsers.parseColors' "$TSVC" \
    || fail "ThemeService does not parse the palette through ThemeParsers"
grep -q 'ThemeParsers.isTrustedStat' "$TSVC" \
    || fail "ThemeService does not gate the read through ThemeParsers.isTrustedStat"
grep -q 'ThemeParsers.parseSelection' "$TSVC" \
    || fail "ThemeService does not parse the selection through ThemeParsers"
grep -qF '"%f|%s"' "$TSVC" \
    || fail "ThemeService trust check must use stat's raw mode (%f), not the locale-dependent %F"
grep -q 'hasPalette' "$TSVC" \
    || fail "ThemeService exposes no hasPalette"
# Roles stay writable so a palette swap re-binds consumers, per the repaint
# rule; a readonly role would freeze the bar at the first palette.
for role in background dark_background lighter_background foreground muted dark_foreground light_foreground accent magenta red yellow; do
    grep -qE "^[[:space:]]*property color $role: " "$TSVC" \
        || fail "ThemeService does not expose writable role $role"
done
# B1: the restored state name is validated with the same predicate the catalog
# scan uses, and a ready catalog gates the path so only a listed theme is read.
grep -q 'function isValidThemeName' "$TPARSE" \
    || fail "ThemeParsers has no shared theme-name predicate"
grep -q 'isValidThemeName(parsed.theme)' "$TPARSE" \
    || fail "parseSelection does not validate the restored theme name"
grep -q 'isValidThemeName(name)' "$TPARSE" \
    || fail "parseCatalog does not use the shared theme-name predicate"
grep -q 'function isSelectionObject' "$TPARSE" \
    || fail "ThemeParsers has no selection-object predicate"
grep -q 'ThemeParsers.isSelectionObject' "$TSVC" \
    || fail "ThemeService does not tell a saved selection from a corrupt file"
grep -q 'function themePathAllowed' "$TSVC" \
    || fail "ThemeService does not gate a path on catalog membership"
grep -q 'root.themePathAllowed(root.activeTheme)' "$TSVC" \
    || fail "colorsPath is not gated on catalog membership"
# L7: required roles are opaque; only the border roles keep the eight-digit form.
grep -q 'function isOpaqueColorValue' "$TPARSE" \
    || fail "ThemeParsers does not distinguish opaque roles from border roles"
grep -q 'isOpaqueColorValue(value)' "$TPARSE" \
    || fail "parseColors does not restrict a required role to an opaque value"
grep -qF '[0-9a-fA-F]+' "$TPARSE" \
    || fail "isTrustedStat does not require a hex mode field (L15)"
# M3, L1, L2, L4: the refresh, background and renderer follow-ups.
grep -A6 'function refresh(): string' "$TSVC" | grep -q 'reloadPalette' \
    || fail "the IPC refresh does not reload the active palette (M3)"
grep -q 'no background named' "$TSVC" \
    || fail "selectBackground does not refuse an unknown background (L1)"
grep -q 'backgroundQueuedPath' "$TSVC" \
    || fail "a second background pick is not queued (L2)"
grep -q 'render-theme.sh exited non-zero' "$TSVC" \
    || fail "a non-zero renderer exit is not logged (L4)"

# Run the shipped parser under node: ThemeParsers.parseColors and its cascade,
# isTrustedStat, and parseSelection / serializeSelection, then the B1
# regression, which feeds parseSelection the state values a tampered state file
# could hold. B1 shipped in the real file while a Python copy of it passed.
node - "$ROOT/tests/qmljs.js" "$TPARSE" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const ctx = qmljs.load(process.argv[3]);
function fail(message) {
    console.error('panel-logic FAIL: ' + message);
    process.exit(1);
}
const parseColors = (text, hint) => ctx.parseColors(text, hint);
const drop = (text, prefix) => text.split('\n').filter(line => !line.startsWith(prefix)).join('\n');

// parseColors: a canonical file resolves to itself; a pre-semantic ANSI file is
// filled in via omarchy-theme-color's aliases, ANSI bridge, derived fills, and
// mixed shades. mode resolves as `mode` -> `theme_type` -> hint -> background
// luminance -> dark.
const VALID = `
mode = "dark"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
orange = "#eb927b"
green = "#9ece6a"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"
brown = "#75493d"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"
`;

const palette = parseColors(VALID);
check('colors/mode', palette.mode, 'dark');
check('colors/background', palette.background, '#1a1b26');
check('colors/lighter_background-kept', palette.lighter_background, '#24283b');
check('colors/red', palette.red, '#f7768e');
check('colors/optional-orange', palette.orange, '#eb927b');
check('colors/no-urgent-role', 'urgent' in palette, false);
check('colors/uppercase-lowered', parseColors(VALID.replaceAll('#1a1b26', '#1A1B26')).background, '#1a1b26');

// red is the urgent role; an explicit `urgent` key is ignored, not carried.
const urgent = parseColors(VALID + '\nurgent = "#ff0000"\n');
check('colors/urgent-ignored', 'urgent' in urgent, false);
check('colors/red-kept', urgent.red, '#f7768e');

// Eight digits are #rrggbbaa for the border roles only; a required role with
// eight digits is rejected rather than handed to QML, which reads #aarrggbb.
check('colors/required-8-digit-rejected', parseColors(
    VALID.replaceAll('accent = "#7aa2f7"', 'accent = "#7aa2f7aa"')), null);
check('colors/border-8-digit-kept', parseColors(
    VALID + '\nhyprland_inactive_border = "#00ff0080"\n').hyprland_inactive_border, '#00ff0080');
check('colors/alias-8-digit-dropped', 'orange' in parseColors(
    VALID.replaceAll('orange = "#eb927b"', 'orange = "#eb927baa"')), false);

check('colors/light', parseColors(VALID.replaceAll('mode = "dark"', 'mode = "light"')).mode, 'light');

// A pre-semantic theme (harbor's shape): ANSI color0-15 plus named accent,
// foreground, background, selection_*. The resolver fills the semantic roles.
const HARBOR = `
accent = "#5e81ac"
foreground = "#1c2d28"
background = "#dfe4c4"
selection_foreground = "#1c2d28"
selection_background = "#5e81ac"

color0 = "#dfe4c4"
color1 = "#b14752"
color2 = "#556753"
color3 = "#dc8164"
color4 = "#4c6c94"
color5 = "#8a5b81"
color6 = "#3d727d"
color7 = "#384f54"
color8 = "#7d8794"
color9 = "#b14752"
color10 = "#556753"
color11 = "#dc8164"
color12 = "#4c6c94"
color13 = "#8a5b81"
color14 = "#3d727d"
color15 = "#1c2d28"
`;
const harbor = parseColors(HARBOR, 'light');
check('colors/presemantic/resolves', harbor !== null, true);
check('colors/presemantic/mode-hint', harbor.mode, 'light');
check('colors/presemantic/mode-luminance', parseColors(HARBOR).mode, 'light');
check('colors/presemantic/red', harbor.red, '#b14752');
check('colors/presemantic/muted', harbor.muted, '#7d8794');
check('colors/presemantic/selection', harbor.selection, '#5e81ac');
check('colors/presemantic/light_foreground', harbor.light_foreground, '#1c2d28');
check('colors/presemantic/bright_foreground', harbor.bright_foreground, '#1c2d28');
check('colors/presemantic/dark_background', harbor.dark_background, '#a7ab93');
// color0 equals background, so the degenerate lighter_background steps toward
// the foreground instead of vanishing into the background.
check('colors/presemantic/lighter_background-stepped', harbor.lighter_background, '#b8bfa5');
// color9 is present, so bright_red aliases it rather than mixing.
check('colors/presemantic/bright_red-aliased', harbor.bright_red, '#b14752');

// Without color9-14 the bright roles are mixed from the base colors.
let MIXED = HARBOR;
for (const slot of ['color9', 'color10', 'color11', 'color12', 'color13', 'color14'])
    MIXED = drop(MIXED, slot + ' = ');
check('colors/presemantic/mixed-bright-red', parseColors(MIXED).bright_red, '#c16c75');

// magenta falls back to purple when color5 is absent.
const PURPLE = drop(HARBOR, 'color5 = ') + 'purple = "#123456"\n';
check('colors/presemantic/purple-alias', parseColors(PURPLE).magenta, '#123456');

// ANSI-only dark: no marker, no mode key, luminance decides.
const DARK = `
accent = "#5e81ac"
foreground = "#e0e0e0"
background = "#121212"
color0 = "#121212"
color1 = "#b14752"
color2 = "#556753"
color3 = "#dc8164"
color4 = "#4c6c94"
color5 = "#8a5b81"
color6 = "#3d727d"
color7 = "#e0e0e0"
`;
check('colors/presemantic/dark-mode', parseColors(DARK).mode, 'dark');

// A canonical value wins over its legacy form, and theme_type is the legacy mode.
const BOTH = VALID.replaceAll('background = "#1a1b26"', 'background = "#1a1b26"\nbg = "#000000"');
check('colors/canonical-over-legacy', parseColors(BOTH).background, '#1a1b26');
check('colors/theme-type', parseColors(
    VALID.replaceAll('mode = "dark"', 'theme_type = "light"')).mode, 'light');

check('colors/mode-hint-wins', parseColors(drop(VALID, 'mode = '), 'light').mode, 'light');
check('colors/short-hex', parseColors(VALID.replaceAll('#1a1b26', '#123')).background, '#112233');
check('colors/missing-key', parseColors(drop(VALID, 'red = ')), null);
check('colors/missing-mode', parseColors(drop(VALID, 'mode = ')).mode, 'dark');
check('colors/empty', parseColors(''), null);
check('colors/comments-only', parseColors('# just a comment\n'), null);

// isTrustedStat: the stat output is the raw mode in hex plus the byte size.
// Only a regular file (mode type 0x8000) at or below the 256 KB cap is
// readable; a symlink, a directory, a missing path, and an empty field are
// all refused.
const MAX_BYTES = 262144;
check('stat/max-bytes', ctx.themeMaxBytes(), MAX_BYTES);
check('stat/regular', ctx.isTrustedStat('81a4|512'), true);
check('stat/at-cap', ctx.isTrustedStat('81a4|' + MAX_BYTES), true);
check('stat/oversized', ctx.isTrustedStat('81a4|' + (MAX_BYTES + 1)), false);
check('stat/symlink', ctx.isTrustedStat('a1ff|9'), false);
check('stat/directory', ctx.isTrustedStat('41ed|4096'), false);
check('stat/missing', ctx.isTrustedStat(''), false);
check('stat/executable', ctx.isTrustedStat('81ed|14'), true);
check('stat/truncated-size', ctx.isTrustedStat('81a4|'), false);
check('stat/missing-mode', ctx.isTrustedStat('|512'), false);

// parseSelection / serializeSelection: the theme name is validated as one plain
// path segment before it can become a path, a malformed or non-object file
// falls back to no active theme with an empty background map, and a round trip
// preserves both.
const sel = text => ctx.parseSelection(text);
const none = { theme: '', backgrounds: {} };
check('selection/round-trip',
      sel(ctx.serializeSelection('tokyo-night', '{"tokyo-night": "2-swirl-buck.webp"}')),
      { theme: 'tokyo-night', backgrounds: { 'tokyo-night': '2-swirl-buck.webp' } });
check('selection/default-empty', sel(''), none);
check('selection/malformed', sel('{nope'), none);
check('selection/list', sel('[1, 2]'), none);
check('selection/keeps-backgrounds', sel('{"backgrounds": {"a": "b.jpg"}}'), { theme: '', backgrounds: { a: 'b.jpg' } });
check('selection/select-rewrites-theme-keeps-backgrounds',
      sel(ctx.serializeSelection('daylight', '{"tokyo-night": "2-swirl-buck.webp"}')),
      { theme: 'daylight', backgrounds: { 'tokyo-night': '2-swirl-buck.webp' } });
check('selection/traversal', sel('{"theme": "../../etc"}'), none);
check('selection/slash', sel('{"theme": "a/b"}'), none);
check('selection/backslash', sel(JSON.stringify({ theme: 'a\\b' })), none);
check('selection/dot', sel('{"theme": "."}'), none);
check('selection/dotdot', sel('{"theme": ".."}'), none);
check('selection/fragment', sel('{"theme": "a#b"}'), none);
check('selection/query', sel('{"theme": "a?b"}'), none);
check('selection/control', sel(JSON.stringify({ theme: 'evil\nname' })), none);
check('selection/valid', sel('{"theme": "tokyo-night"}'), { theme: 'tokyo-night', backgrounds: {} });

// B1 regression.
function selection(theme) {
    return ctx.parseSelection(JSON.stringify({ theme: theme })).theme;
}
for (const name of ['../../../etc', 'a/b', 'a\\b', 'a|b', 'a#b', 'a?b', '.', '..', '', 'evil\nname']) {
    const got = selection(name);
    if (got !== '')
        fail('parseSelection kept a rejected theme name ' + JSON.stringify(name) + ': ' + JSON.stringify(got));
}
if (selection('tokyo-night') !== 'tokyo-night')
    fail('parseSelection dropped a valid theme name');
if (ctx.isValidThemeName === undefined)
    fail('ThemeParsers.js did not expose isValidThemeName under node');
if (ctx.isSelectionObject === undefined)
    fail('ThemeParsers.js did not expose isSelectionObject under node');
if (ctx.isSelectionObject('') !== false)
    fail('isSelectionObject accepted an empty state file');
if (ctx.isSelectionObject('{nope') !== false)
    fail('isSelectionObject accepted malformed JSON');
if (ctx.isSelectionObject('[1, 2]') !== false)
    fail('isSelectionObject accepted a JSON array');
if (ctx.isSelectionObject('{"theme":""}') !== true)
    fail('isSelectionObject rejected a saved no-theme selection');
if (ctx.isSelectionObject('{"theme":"tokyo-night"}') !== true)
    fail('isSelectionObject rejected a saved selection');
const bg = ctx.parseBackgrounds('{"__proto__": "a.png"}');
if (bg["__proto__"] !== "a.png")
    fail('parseBackgrounds lost a __proto__ key');
if (Object.getPrototypeOf(bg) !== null)
    fail('parseBackgrounds kept a prototype, so a __proto__ key can shadow the map');
NODEEOF

# --- 15. colors mapping: every mapped token binds to ThemeService ---
# config/Colors.qml keeps its token names and gains a binding onto
# ThemeService per the frozen mapping table. When no
# theme is active each token falls back to the pre-theme hex, so the no-theme
# look is unchanged. Aliases (panel, card, danger, ...) resolve to their source
# token; appColor stays palette-independent.
COLORS="$ROOT/config/Colors.qml"
test -f "$COLORS" \
    || fail "config/Colors.qml is missing"
grep -q '^import qs.services' "$COLORS" \
    || fail "Colors.qml is missing its qs.services import"

python3 - "$COLORS" <<'EOF'
import re
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    text = handle.read()

# name -> expression for every `readonly property color <name>: <expr>`.
exprs = {}
for match in re.finditer(r"^\s*readonly property color (\w+):\s*(.+?)\s*$", text, re.M):
    exprs[match.group(1)] = match.group(2)

# Frozen mapping: every Colors token -> the pre-theme hex the binding keeps in
# the no-theme branch. Aliases resolve to their source token's expression.
MAPPED = {
    "background": "#141118", "panel": "#141118", "card": "#141118",
    "onAccent": "#141118",
    "backgroundSecondary": "#27222f", "cardSecondary": "#27222f",
    "surface": "#282936", "border": "#282936", "panelBorder": "#282936",
    "text": "#cac4d4",
    "textSubtle": "#9d93ad",
    "textSecondary": "#4f455f",
    "accent": "#b4befe", "accentDim": "#b4befe",
    "accentSecondary": "#a980db", "purple": "#a980db",
    "danger": "#ff5252", "red": "#ff5252",
    "warning": "#d7d370", "yellow": "#d7d370",
    "criticalCard": "#2a161c",
    "criticalCardBorder": "#40222b",
}

for token in MAPPED:
    check(f"colors/{token}/defined", token in exprs, True)

def terminal(name, seen=None):
    # Follow bare aliases (`other`, `root.other`) until an expression naming
    # ThemeService. A token that never reaches it has no palette binding.
    seen = seen or set()
    expr = exprs[name]
    if "ThemeService" in expr:
        return expr
    for ref in re.findall(r"(?:root\.)?(\w+)", expr):
        if ref in exprs and ref != name and ref not in seen:
            found = terminal(ref, seen | {name})
            if found is not None:
                return found
    return None

for token, fallback in MAPPED.items():
    resolved = terminal(token)
    check(f"colors/{token}/binds-theme", resolved is not None, True)
    check(f"colors/{token}/fallback", fallback in resolved, True)

check("colors/textSecondary/mode", "ThemeService.mode" in exprs["textSecondary"], True)
check("colors/textSecondary/dark", "dark_foreground" in exprs["textSecondary"], True)
check("colors/textSecondary/light", "light_foreground" in exprs["textSecondary"], True)

# accentDim is accent at 14 percent alpha, not a literal.
check("colors/accentDim/alpha", "0.14" in exprs["accentDim"], True)
check("colors/accentDim/accent", "accent" in exprs["accentDim"], True)

# criticalCard and criticalCardBorder mix red into background, not a literal.
for token in ("criticalCard", "criticalCardBorder"):
    check(f"colors/{token}/red", "red" in exprs[token], True)
    check(f"colors/{token}/background", "background" in exprs[token], True)

# textFaint keeps the theme's secondary when it already sits below the accent,
# and otherwise blends the background toward the foreground.
check("colors/textFaint/defined", "textFaint" in exprs, True)
check("colors/textFaint/secondary", "textSecondary" in exprs["textFaint"], True)
check("colors/textFaint/accent", "accent" in exprs["textFaint"], True)
check("colors/textFaint/derived", "mixInto" in exprs["textFaint"], True)
check("colors/textFaint/primary", "root.text," in exprs["textFaint"], True)

# appColor keeps its hash and never reads the palette.
appmatch = re.search(r"function appColor\([^)]*\)[^{]*\{(.*?)\n    \}", text, re.S)
check("colors/appColor/defined", appmatch is not None, True)
body = appmatch.group(1) if appmatch else ""
check("colors/appColor/hash", "5381" in body, True)
check("colors/appColor/hsla", "Qt.hsla((((hash % 11) + 1) * 30) / 360, 0.65, 0.72, 1.0)" in body, True)
check("colors/appColor/palette-free", "ThemeService" in body, False)
EOF

# --- 16. theme catalog: discovery and selection ---
# ThemeService discovers themes through scripts/theme-catalog-scan.sh, which
# lists a candidate only when it is a real directory holding a readable,
# regular-file colors.toml with a v4 mode. The scan is a real artifact, so this
# gate runs it against a fixture root. ThemeParsers.parseCatalog then names,
# orders, and locates the entries; selectTheme writes the selection through the
# ticket-01 state seam.
TSCRIPT="$ROOT/scripts/theme-catalog-scan.sh"
test -f "$TSCRIPT" \
    || fail "scripts/theme-catalog-scan.sh is missing"
grep -q 'ThemeParsers.parseCatalog' "$TSVC" \
    || fail "ThemeService does not build the catalog through ThemeParsers.parseCatalog"
grep -q 'function refresh' "$TSVC" \
    || fail "ThemeService exposes no refresh()"
grep -q 'function selectTheme' "$TSVC" \
    || fail "ThemeService exposes no selectTheme()"
grep -qE 'readonly property var catalog' "$TSVC" \
    || fail "ThemeService exposes no catalog list"
grep -q 'theme-catalog-scan.sh' "$TSVC" \
    || fail "ThemeService does not run the catalog scan script"
grep -q 'ThemeParsers.themeMaxBytes' "$TSVC" \
    || fail "ThemeService does not pass the palette byte cap to the scan"

CATDIR="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-catalog-XXXXXX")"
# The scan lists a theme only when colors.toml carries the full v4 palette, not
# merely a mode line, so the catalog cannot offer a switch that yields no
# palette (M4). The palette text matches the parseColors node checks above.
write_palette_theme() {
    mkdir -p "$1"
    sed "s/^mode = \"dark\"/mode = \"$2\"/" "$ROOT/tests/fixtures/theme-palette.toml" > "$1/colors.toml"
}
# A pre-semantic ANSI-only palette with the given background, plus the named
# roles omarchy's cascade needs (accent has no fallback).
write_ansi_theme() {
    mkdir -p "$1"
    cat > "$1/colors.toml" <<EOF
accent = "#5e81ac"
foreground = "#e0e0e0"
background = "$2"
color1 = "#b14752"
color2 = "#556753"
color3 = "#dc8164"
color4 = "#4c6c94"
color5 = "#8a5b81"
color6 = "#3d727d"
EOF
}
mkdir -p "$CATDIR/tokyo-night" "$CATDIR/daylight" "$CATDIR/quoted" "$CATDIR/twice" \
    "$CATDIR/modeonly" "$CATDIR/missingkey" "$CATDIR/dupmode" "$CATDIR/oversized" \
    "$CATDIR/hash#name" "$CATDIR/quest?name" "$CATDIR/pipe|name" "$CATDIR/back\\slash" \
    "$CATDIR/linktheme" "$CATDIR/linkcolors" "$CATDIR/harbor" "$CATDIR/plaindark" \
    "$CATDIR/legacytype"
write_palette_theme "$CATDIR/tokyo-night" dark
write_palette_theme "$CATDIR/daylight" light
write_palette_theme "$CATDIR/quoted" light
sed -i "s/^mode = \"light\"/mode = 'light'/" "$CATDIR/quoted/colors.toml"
write_palette_theme "$CATDIR/twice" dark
printf 'mode = "light"\n' >> "$CATDIR/twice/colors.toml"
# A mode-only file, and a palette missing a required key, are both dropped.
printf 'mode = "dark"\n' > "$CATDIR/modeonly/colors.toml"
grep -v '^red = ' "$CATDIR/tokyo-night/colors.toml" > "$CATDIR/missingkey/colors.toml"
# The last value of a key wins, so a valid value followed by an invalid one is
# dropped, matching parseColors.
write_palette_theme "$CATDIR/dupmode" dark
printf 'accent = "#7aa2f7aa"\n' >> "$CATDIR/dupmode/colors.toml"
write_palette_theme "$CATDIR/oversized" dark
head -c 262145 /dev/zero | tr '\0' '#' >> "$CATDIR/oversized/colors.toml"
write_palette_theme "$CATDIR/hash#name" dark
write_palette_theme "$CATDIR/quest?name" dark
write_palette_theme "$CATDIR/pipe|name" dark
write_palette_theme "$CATDIR/back\\slash" dark
ln -s "$CATDIR/tokyo-night" "$CATDIR/linktheme"
ln -s "$CATDIR/tokyo-night/colors.toml" "$CATDIR/linkcolors/colors.toml"
: > "$CATDIR/notatheme"
# A pre-semantic ANSI theme with a light.mode marker is listed light; without
# one its luminance decides. The legacy theme_type key resolves mode too.
write_ansi_theme "$CATDIR/harbor" "#dfe4c4"
: > "$CATDIR/harbor/light.mode"
write_ansi_theme "$CATDIR/plaindark" "#121212"
# A role takes the first key holding any hex value, then must be opaque, so a
# non-opaque magenta is a dead switch the scan drops, while an absent magenta
# falls through to color5 before purple.
write_ansi_theme "$CATDIR/magenta-alpha" "#121212"
printf 'magenta = "#8a5b81aa"\n' >> "$CATDIR/magenta-alpha/colors.toml"
write_ansi_theme "$CATDIR/magenta-order" "#121212"
sed -i 's/^color5 = "#8a5b81"/color5 = "#222222"/' "$CATDIR/magenta-order/colors.toml"
printf 'purple = "#111111"\n' >> "$CATDIR/magenta-order/colors.toml"
sed 's/^mode = "dark"/theme_type = "light"/' "$ROOT/tests/fixtures/theme-palette.toml" > "$CATDIR/legacytype/colors.toml"
scan_out="$(sh "$TSCRIPT" "$CATDIR" 262144 | LC_ALL=C sort)"
scan_want="$(cat <<'EOF'
daylight|"light"|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26
harbor|light|#5e81ac|#8a5b81|#e0e0e0|#dfe3ca|#dfe4c4
legacytype|"light"|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26
magenta-order|dark|#5e81ac|#222222|#e0e0e0|#3b3b3b|#121212
plaindark|dark|#5e81ac|#8a5b81|#e0e0e0|#3b3b3b|#121212
quoted|'light'|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26
tokyo-night|"dark"|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26
twice|"light"|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26
EOF
)"
test "$scan_out" = "$scan_want" \
    || fail "catalog scan listed the wrong themes: got [$scan_out] want [$scan_want]"

# The preview must match the palette the loader builds, or Settings shows
# colours the theme never applies. Run the real parseColors under node against
# each listed fixture and compare the five roles the scan emits; a listed theme
# parseColors rejects is a dead switch the scan should have dropped.
node - "$ROOT/tests/qmljs.js" "$TPARSE" "$CATDIR" "$scan_out" <<'NODEEOF'
const fs = require('fs');
const path = require('path');
const qmljs = require(process.argv[2]);
const ctx = qmljs.load(process.argv[3]);
const catdir = process.argv[4];
const scanOut = process.argv[5];
function fail(message) {
    console.error('panel-logic FAIL: ' + message);
    process.exit(1);
}
const roles = ['accent', 'magenta', 'foreground', 'lighter_background', 'background'];
for (const line of scanOut.split('\n')) {
    if (line === '')
        continue;
    const parts = line.split('|');
    const name = parts[0];
    const preview = parts.slice(2);
    const palette = ctx.parseColors(fs.readFileSync(path.join(catdir, name, 'colors.toml'), 'utf8'), '');
    if (palette === null) {
        fail('the scan listed a theme parseColors rejects: ' + name);
        continue;
    }
    for (let i = 0; i < roles.length; i++) {
        if (preview[i] !== palette[roles[i]])
            fail('preview mismatch for ' + name + ' ' + roles[i] + ': scan ' + preview[i] + ' palette ' + palette[roles[i]]);
    }
}
NODEEOF
rm -rf "$CATDIR"

node - "$ROOT/tests/qmljs.js" "$TPARSE" <<'NODEEOF'
// ThemeParsers.displayName: split on runs of - or _, drop empty segments,
// uppercase each segment's first character, and join with single spaces.
// ThemeParsers.parseCatalog: one `name|raw mode|<preview roles>` record per line
// from the scan; the raw value goes through parseTomlString (a quoted value ends
// at its closing quote, an unquoted value at the first space), a valid mode and
// name are required, the trailing roles are normalized to lowercase opaque hex,
// and entries sort by display name then slug and are located under the theme
// root.
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const tp = qmljs.load(process.argv[3]);
check('catalog/display-kebab', tp.displayName('tokyo-night'), 'Tokyo Night');
check('catalog/display-snake', tp.displayName('rose_pine'), 'Rose Pine');
check('catalog/display-single', tp.displayName('nord'), 'Nord');
check('catalog/display-runs', tp.displayName('a--b__c'), 'A B C');
check('catalog/display-lead-trail', tp.displayName('-lead-trail-'), 'Lead Trail');
check('catalog/display-digits', tp.displayName('123abc'), '123abc');
check('catalog/display-empty', tp.displayName(''), '');
check('toml/double-quoted', tp.parseTomlString(' "dark" # comment'), 'dark');
check('toml/single-quoted', tp.parseTomlString("'light'"), 'light');
check('toml/unquoted', tp.parseTomlString('dark trailing'), 'dark');
check('toml/empty', tp.parseTomlString('   '), '');
const catalog = (output, root) => tp.parseCatalog(output, root);
const catalogNames = (output, root) => catalog(output, root).map(e => e.name);
const TEXT = 'tokyo-night|"dark"\ndaylight|"light"\nnord|light\n';
check('catalog/order', catalogNames(TEXT, '/r'), ['daylight', 'nord', 'tokyo-night']);
check('catalog/dir', catalog(TEXT, '/r')[0].dir, '/r/daylight');
check('catalog/display', catalog(TEXT, '/r')[2].displayName, 'Tokyo Night');
check('catalog/single-quotes', catalog("quoted|'light'\n", '/r')[0].mode, 'light');
check('catalog/trailing-comment', catalog('commented|"dark" # dark\n', '/r')[0].mode, 'dark');
check('catalog/order-by-display', catalogNames('Zebra|dark\nalpha|light\n', '/r'), ['alpha', 'Zebra']);
check('catalog/drop-bad-mode', catalogNames('bad|purple\ngood|dark\n', '/r'), ['good']);
check('catalog/drop-no-sep', catalog('noseparator\n', '/r'), []);
check('catalog/drop-path', catalog('a/b|dark\n', '/r'), []);
check('catalog/drop-hash-name', catalog('a#b|dark\n', '/r'), []);
check('catalog/drop-quest-name', catalog('a?b|dark\n', '/r'), []);
check('catalog/empty', catalog('', '/r'), []);
check('catalog/trailing-newline-ok', catalogNames('good|dark\n', '/r'), ['good']);
check('catalog/preview-roles', catalog('tokyo-night|dark|#7aa2f7|#ad8ee6|#a9b1d6|#24283b|#1a1b26\n', '/r')[0].swatches,
      ['#7aa2f7', '#ad8ee6', '#a9b1d6', '#24283b', '#1a1b26']);
check('catalog/preview-short-hex', catalog('x|dark|#ABC|#ad8ee6\n', '/r')[0].swatches, ['#aabbcc', '#ad8ee6']);
check('catalog/preview-drops-invalid', catalog('x|dark|#7aa2f7|notacolor|#ad8ee6\n', '/r')[0].swatches,
      ['#7aa2f7', '#ad8ee6']);
check('catalog/preview-drops-alpha', catalog('x|dark|#7aa2f7ff\n', '/r')[0].swatches, []);
check('catalog/no-preview', catalog('x|dark\n', '/r')[0].swatches, []);
NODEEOF

# --- 17. desktop retint: the renderer writes repo-owned templates ---
# scripts/render-theme.sh substitutes the resolved palette into the templates
# under assets/templates/ and writes the six desktop files. It reads no theme
# directory, so this gate runs the real script against a fixture palette with
# XDG_CONFIG_HOME redirected, then checks the bytes, the border fallback and
# override, the empty-palette default, and idempotency.
RENDER="$ROOT/scripts/render-theme.sh"
test -f "$RENDER" \
    || fail "scripts/render-theme.sh is missing"
for tpl in hypr-theme.lua kitty-theme.conf hyprlock-colors.conf starship-theme.toml yazi-theme.toml btop-theme.theme; do
    test -f "$ROOT/assets/templates/$tpl" \
        || fail "assets/templates/$tpl is missing"
done
grep -q 'render-theme.sh' "$TSVC" \
    || fail "ThemeService does not run the desktop renderer"
grep -q 'renderScriptPath' "$TSVC" \
    || fail "ThemeService does not expose the renderer script path"
# The renderer also runs for the no-palette case, so a selected-but-unreadable
# theme leaves the desktop on the same fallback the bar shows instead of the
# previous theme's files.
if grep -A4 'function renderDesktop' "$TSVC" | grep -q '!root.hasPalette'; then
    fail "renderDesktop skips the fallback render for an active theme (stale desktop)"
fi
if grep -q 'colors.toml' "$RENDER"; then
    fail "render-theme.sh names colors.toml; it must consume only the resolved palette"
fi

RENDER_HOME="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE='{"accent":"#7aa2f7","selection":"#33467c","muted":"#565f89","background":"#1a1b26","dark_background":"#16161e","darker_background":"#101014","lighter_background":"#292e42","foreground":"#c0caf5","dark_foreground":"#a9b1d6","light_foreground":"#d5d6db","bright_foreground":"#ffffff","red":"#f7768e","yellow":"#e0af68","green":"#9ece6a","cyan":"#7dcfff","blue":"#7aa2f7","magenta":"#bb9af7","bright_red":"#ff7a93","bright_yellow":"#ff9e64","bright_green":"#b9f27c","bright_cyan":"#7ff7ff","bright_blue":"#7aa2ff","bright_magenta":"#c7a9ff"}'
XDG_CONFIG_HOME="$RENDER_HOME" sh "$RENDER" "$RENDER_PALETTE"
test -f "$RENDER_HOME/hypr/theme.lua" \
    || fail "renderer wrote no hypr theme.lua"
test -f "$RENDER_HOME/kitty/theme.conf" \
    || fail "renderer wrote no kitty theme.conf"
test -f "$RENDER_HOME/hypr/hyprlock/colors.conf" \
    || fail "renderer wrote no hyprlock colors.conf"
grep -q 'rgba(7aa2f7ff)' "$RENDER_HOME/hypr/theme.lua" \
    || fail "hypr active border does not derive from accent"
grep -q 'rgba(7aa2f7aa)' "$RENDER_HOME/hypr/theme.lua" \
    || fail "hypr inactive border does not derive from accent at reduced alpha"
grep -q 'background *#1a1b26' "$RENDER_HOME/kitty/theme.conf" \
    || fail "kitty background does not come from the palette"
grep -q 'cursor *#7aa2f7' "$RENDER_HOME/kitty/theme.conf" \
    || fail "kitty cursor does not come from accent"
grep -q 'color1 *#f7768e' "$RENDER_HOME/kitty/theme.conf" \
    || fail "kitty color1 does not come from red"
grep -q '\$theme_accent = rgb(122, 162, 247)' "$RENDER_HOME/hypr/hyprlock/colors.conf" \
    || fail "hyprlock accent does not come from the palette"
test -f "$RENDER_HOME/starship.toml" \
    || fail "renderer wrote no starship.toml"
grep -q "palette = \"theme\"" "$RENDER_HOME/starship.toml" \
    || fail "starship does not select the rendered palette"
grep -q "accent = '#7aa2f7'" "$RENDER_HOME/starship.toml" \
    || fail "starship accent does not come from the palette"
grep -q 'bg:selection' "$RENDER_HOME/starship.toml" \
    || fail "starship pill background does not come from selection"
# The fixture's hues already contrast with its selection, so they are kept.
grep -q "text_accent = '#7aa2f7'" "$RENDER_HOME/starship.toml" \
    || fail "starship dropped a pill hue that already contrasts with selection"
grep -q 'fg:text_accent' "$RENDER_HOME/starship.toml" \
    || fail "starship pill text does not use the contrast-resolved hue"
test -f "$RENDER_HOME/yazi/theme.toml" \
    || fail "renderer wrote no yazi theme.toml"
grep -q 'overall = { bg = "#1a1b26" }' "$RENDER_HOME/yazi/theme.toml" \
    || fail "yazi background does not come from the palette"
grep -q 'cwd = { fg = "#7dcfff" }' "$RENDER_HOME/yazi/theme.toml" \
    || fail "yazi cwd does not come from cyan"
# A chip paints its text with the black-or-white ink chosen against the hue,
# not with a fixed palette role.
grep -q 'fg = "#000000", bg = "#7aa2f7"' "$RENDER_HOME/yazi/theme.toml" \
    || fail "yazi chip text is not the contrast ink for its background"
if grep -q '^\[flavor\]' "$RENDER_HOME/yazi/theme.toml"; then
    fail "yazi theme still points at a static flavor"
fi
test -f "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "renderer wrote no btop theme"
grep -q 'theme\[main_bg\]="#1a1b26"' "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "btop background does not come from the palette"
grep -q 'theme\[hi_fg\]="#7aa2f7"' "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "btop highlight does not come from accent"
grep -q 'theme\[temp_end\]="#f7768e"' "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "btop temperature gradient does not come from red"
# The banner and followed-process grounds paint their text with the
# black-or-white ink chosen against the ground, not a fixed palette role.
grep -q 'theme\[proc_banner_fg\]="#000000"' "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "btop banner text is not the contrast ink for accent"
grep -q 'theme\[followed_fg\]="#000000"' "$RENDER_HOME/btop/themes/theme.theme" \
    || fail "btop followed text is not the contrast ink for blue"
if grep -q '{{' "$RENDER_HOME/hypr/theme.lua" "$RENDER_HOME/kitty/theme.conf" "$RENDER_HOME/hypr/hyprlock/colors.conf" "$RENDER_HOME/starship.toml" "$RENDER_HOME/yazi/theme.toml" "$RENDER_HOME/btop/themes/theme.theme"; then
    fail "renderer left an unresolved template placeholder"
fi

before_lua="$(cat "$RENDER_HOME/hypr/theme.lua")"
before_kitty="$(cat "$RENDER_HOME/kitty/theme.conf")"
before_lock="$(cat "$RENDER_HOME/hypr/hyprlock/colors.conf")"
before_starship="$(cat "$RENDER_HOME/starship.toml")"
before_yazi="$(cat "$RENDER_HOME/yazi/theme.toml")"
before_btop="$(cat "$RENDER_HOME/btop/themes/theme.theme")"
stamp="$(stat -c '%y' "$RENDER_HOME/kitty/theme.conf")"
sleep 1
XDG_CONFIG_HOME="$RENDER_HOME" sh "$RENDER" "$RENDER_PALETTE"
test "$before_lua" = "$(cat "$RENDER_HOME/hypr/theme.lua")" \
    || fail "renderer is not idempotent: theme.lua changed on an identical rerun"
test "$before_kitty" = "$(cat "$RENDER_HOME/kitty/theme.conf")" \
    || fail "renderer is not idempotent: theme.conf changed on an identical rerun"
test "$before_lock" = "$(cat "$RENDER_HOME/hypr/hyprlock/colors.conf")" \
    || fail "renderer is not idempotent: colors.conf changed on an identical rerun"
test "$before_starship" = "$(cat "$RENDER_HOME/starship.toml")" \
    || fail "renderer is not idempotent: starship.toml changed on an identical rerun"
test "$before_yazi" = "$(cat "$RENDER_HOME/yazi/theme.toml")" \
    || fail "renderer is not idempotent: yazi theme.toml changed on an identical rerun"
test "$before_btop" = "$(cat "$RENDER_HOME/btop/themes/theme.theme")" \
    || fail "renderer is not idempotent: btop theme changed on an identical rerun"
test "$stamp" = "$(stat -c '%y' "$RENDER_HOME/kitty/theme.conf")" \
    || fail "renderer rewrote an unchanged file"

RENDER_HOME2="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE2="$(printf '%s' "$RENDER_PALETTE" | sed 's/}$/,"hyprland_active_border":"#ff0000","hyprland_inactive_border":"#00ff0080"}/')"
XDG_CONFIG_HOME="$RENDER_HOME2" sh "$RENDER" "$RENDER_PALETTE2"
grep -q 'rgba(ff0000ff)' "$RENDER_HOME2/hypr/theme.lua" \
    || fail "hypr does not honor hyprland_active_border"
grep -q 'rgba(00ff0080)' "$RENDER_HOME2/hypr/theme.lua" \
    || fail "hypr does not honor hyprland_inactive_border"

# An empty palette is the no-active-theme case: the renderer writes its built-in
# default so the bar's fallback and the desktop files agree (M1). A palette that
# is present but missing required roles is still a no-op.
RENDER_HOME3="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
XDG_CONFIG_HOME="$RENDER_HOME3" sh "$RENDER" ""
test -f "$RENDER_HOME3/hypr/theme.lua" \
    || fail "renderer wrote no default theme.lua for an empty palette"
grep -q 'rgba(b4befe' "$RENDER_HOME3/hypr/theme.lua" \
    || fail "the empty-palette default does not use the fallback accent"
grep -q 'background *#141118' "$RENDER_HOME3/kitty/theme.conf" \
    || fail "the empty-palette default does not use the fallback background"
grep -q "accent = '#b4befe'" "$RENDER_HOME3/starship.toml" \
    || fail "the empty-palette default does not use the fallback accent for starship"
grep -q 'overall = { bg = "#141118" }' "$RENDER_HOME3/yazi/theme.toml" \
    || fail "the empty-palette default does not use the fallback background for yazi"
grep -q 'bg = "#b4befe"' "$RENDER_HOME3/yazi/theme.toml" \
    || fail "the empty-palette default does not use the fallback accent for yazi"
grep -q 'theme\[main_bg\]="#141118"' "$RENDER_HOME3/btop/themes/theme.theme" \
    || fail "the empty-palette default does not use the fallback background for btop"
grep -q 'theme\[hi_fg\]="#b4befe"' "$RENDER_HOME3/btop/themes/theme.theme" \
    || fail "the empty-palette default does not use the fallback accent for btop"

RENDER_HOME3B="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
XDG_CONFIG_HOME="$RENDER_HOME3B" sh "$RENDER" '{"accent":"#7aa2f7"}'
test -z "$(find "$RENDER_HOME3B" -type f)" \
    || fail "renderer wrote files for a palette missing required roles"

RENDER_HOME4="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE4="$(printf '%s' "$RENDER_PALETTE" | sed 's/}$/,"hyprland_active_border":"not-a-color"}/')"
XDG_CONFIG_HOME="$RENDER_HOME4" sh "$RENDER" "$RENDER_PALETTE4"
test -f "$RENDER_HOME4/hypr/theme.lua" \
    || fail "renderer stopped writing when an optional border key is malformed"
grep -q 'rgba(7aa2f7ff)' "$RENDER_HOME4/hypr/theme.lua" \
    || fail "a malformed hyprland_active_border does not fall back to accent"

# A three-digit #rgb is expanded to six digits for the raw kitty tokens, so
# kitty reads the same colour hypr and hyprlock get.
RENDER_HOME5="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE5="$(printf '%s' "$RENDER_PALETTE" | sed 's/"accent":"#7aa2f7"/"accent":"#abc"/')"
XDG_CONFIG_HOME="$RENDER_HOME5" sh "$RENDER" "$RENDER_PALETTE5"
grep -q 'cursor *#aabbcc' "$RENDER_HOME5/kitty/theme.conf" \
    || fail "renderer did not expand a three-digit accent for kitty"
grep -q 'rgba(aabbccff)' "$RENDER_HOME5/hypr/theme.lua" \
    || fail "renderer did not expand a three-digit accent for hypr"
grep -q "accent = '#aabbcc'" "$RENDER_HOME5/starship.toml" \
    || fail "renderer did not expand a three-digit accent for starship"
grep -q 'bg = "#aabbcc"' "$RENDER_HOME5/yazi/theme.toml" \
    || fail "renderer did not expand a three-digit accent for yazi"
grep -q 'theme\[hi_fg\]="#aabbcc"' "$RENDER_HOME5/btop/themes/theme.theme" \
    || fail "renderer did not expand a three-digit accent for btop"

# A light theme whose selection and hues are all mid-tone: none of the pill
# hues clear the contrast threshold, so each falls back to a black-or-white ink
# chosen against selection. This is the harbor case; the fixture above proves
# a theme that already contrasts is untouched.
RENDER_HOME6="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE6="$(printf '%s' "$RENDER_PALETTE" | sed \
    -e 's/"selection":"#33467c"/"selection":"#5e81ac"/' \
    -e 's/"accent":"#7aa2f7"/"accent":"#5e81ac"/' \
    -e 's/"blue":"#7aa2f7"/"blue":"#4c6c94"/' \
    -e 's/"cyan":"#7dcfff"/"cyan":"#3d727d"/' \
    -e 's/"red":"#f7768e"/"red":"#b14752"/' \
    -e 's/"yellow":"#e0af68"/"yellow":"#dc8164"/' \
    -e 's/"magenta":"#bb9af7"/"magenta":"#8a5b81"/')"
XDG_CONFIG_HOME="$RENDER_HOME6" sh "$RENDER" "$RENDER_PALETTE6"
grep -q "selection_ink = '#000000'" "$RENDER_HOME6/starship.toml" \
    || fail "the pill ink is not the higher-contrast of black and white"
grep -q "text_blue = '#000000'" "$RENDER_HOME6/starship.toml" \
    || fail "a low-contrast pill hue did not fall back to the ink"
grep -q 'fg:text_blue' "$RENDER_HOME6/starship.toml" \
    || fail "the fallen-back pill text is not referenced by the styles"

# A light background with a mid-tone hue: the body text keeps the hue only when
# it clears the contrast threshold, and otherwise falls back to the black or
# white ink chosen against the background.
RENDER_HOME7="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-render-XXXXXX")"
RENDER_PALETTE7="$(printf '%s' "$RENDER_PALETTE" | sed \
    -e 's/"background":"#1a1b26"/"background":"#f5f5f5"/' \
    -e 's/"dark_background":"#16161e"/"dark_background":"#e6e6e6"/' \
    -e 's/"darker_background":"#101014"/"darker_background":"#dddddd"/' \
    -e 's/"lighter_background":"#292e42"/"lighter_background":"#ffffff"/' \
    -e 's/"foreground":"#c0caf5"/"foreground":"#222222"/' \
    -e 's/"cyan":"#7dcfff"/"cyan":"#d0f0f0"/')"
XDG_CONFIG_HOME="$RENDER_HOME7" sh "$RENDER" "$RENDER_PALETTE7"
grep -q 'cwd = { fg = "#000000" }' "$RENDER_HOME7/yazi/theme.toml" \
    || fail "yazi did not fall a low-contrast body hue back to the background ink"

rm -rf "$RENDER_HOME" "$RENDER_HOME2" "$RENDER_HOME3" "$RENDER_HOME3B" "$RENDER_HOME4" "$RENDER_HOME5" "$RENDER_HOME6" "$RENDER_HOME7"

# --- 18. dashboard Theme block: live palette, name, settings target ---
# The block is the switcher's second home: a palette strip bound to the mapped
# roles, the active theme's display name, and a click that opens the Settings
# Theme section through the dashboard tab. The empty
# wallpaper grid is gone; ticket 08 owns the background picker.
DBLOCK="$ROOT/windows/DashboardThemeBlock.qml"
test -f "$DBLOCK" \
    || fail "windows/DashboardThemeBlock.qml is missing"
if grep -qE '\[[[:space:]]*Colors\.' "$DBLOCK"; then
    fail "DashboardThemeBlock still binds a literal swatch list"
fi
grep -q 'Colors.themeSwatches' "$DBLOCK" \
    || fail "DashboardThemeBlock does not bind the shared mapped swatches"
grep -q 'readonly property var themeSwatches' "$COLORS" \
    || fail "Colors has no themeSwatches list of mapped roles"
grep -q 'ThemeService.activeDisplayName' "$DBLOCK" \
    || fail "DashboardThemeBlock does not show the active theme name"
grep -q 'letterSpacing: Globals.uiLetterSpacing' "$DBLOCK" \
    || fail "DashboardThemeBlock captions lack the section-caption tracking"
if grep -q 'Globals.uiTitleSize' "$DBLOCK"; then
    fail "DashboardThemeBlock uses uiTitleSize, which is not a dashboard role"
fi
grep -qF 'qsTr("No theme")' "$DBLOCK" \
    || fail "DashboardThemeBlock has no empty-theme label"
grep -qF 'DashboardService.openSettings("theme")' "$DBLOCK" \
    || fail "DashboardThemeBlock does not open the Theme section through the dashboard tab"
if grep -qi 'wallpaper' "$DBLOCK"; then
    fail "DashboardThemeBlock still renders the empty wallpaper grid"
fi
if grep -q 'MouseArea' "$DBLOCK"; then
    fail "DashboardThemeBlock rolls its own click surface; the shared Card owns the click"
fi
grep -q 'property bool clickable' "$ROOT/components/Card.qml" \
    || fail "Card has no clickable opt-in for a whole-card target"
grep -q 'property string targetSection' "$SSVC" \
    || fail "SettingsService has no section target"
grep -q 'SettingsService.targetSection' "$SCENTER" \
    || fail "SettingsView does not honor the requested section target"
grep -q 'readonly property string activeDisplayName' "$TSVC" \
    || fail "ThemeService has no activeDisplayName"
grep -q 'root.backgroundEntries.length === 0' "$DBLOCK" \
    || fail "DashboardThemeBlock resets the background page on a transient empty list (L11)"

# --- 19. theme backgrounds: guarded listing plus per-theme apply ---
# ThemeService lists a theme's backgrounds through scripts/theme-backgrounds-scan.sh,
# which admits a file only when it is a real regular file, not a symlink, directly
# inside backgrounds/, with an allowed image extension and at most the 32 MB cap.
# The scan is a real artifact, so this gate runs it against a fixture directory;
# ThemeParsers.parseBackgroundList then names and orders the entries, and the
# awww apply rides the ticket-05 renderer path in ThemeService.
BSCAN="$ROOT/scripts/theme-backgrounds-scan.sh"
TILE="$ROOT/components/BackgroundTile.qml"
test -f "$BSCAN" \
    || fail "scripts/theme-backgrounds-scan.sh is missing"
test -f "$TILE" \
    || fail "components/BackgroundTile.qml is missing"
grep -q 'theme-backgrounds-scan.sh' "$TSVC" \
    || fail "ThemeService does not run the background scan script"
grep -q 'ThemeParsers.backgroundMaxBytes' "$TSVC" \
    || fail "ThemeService does not pass the background byte cap to the scan"
grep -q 'ThemeParsers.parseBackgroundList' "$TSVC" \
    || fail "ThemeService does not build the background list through ThemeParsers"
grep -qE 'readonly property var backgroundList' "$TSVC" \
    || fail "ThemeService exposes no background list"
grep -q 'function refreshBackgrounds' "$TSVC" \
    || fail "ThemeService exposes no refreshBackgrounds()"
grep -q 'currentBackgroundName' "$TSVC" \
    || fail "ThemeService exposes no current background choice"
grep -qF '["awww", "img"' "$TSVC" \
    || fail "ThemeService does not apply the background with awww"
grep -q 'Image' "$TILE" \
    || fail "BackgroundTile does not decode its thumbnail with Qt"
grep -q 'root.implicitWidth' "$TILE" \
    || fail "BackgroundTile does not seed sourceSize from its implicit size (L10)"
grep -q 'ThemeService.backgroundList' "$DBLOCK" \
    || fail "DashboardThemeBlock does not bind the background list"
grep -q 'ThemeService.currentBackgroundName' "$DBLOCK" \
    || fail "DashboardThemeBlock does not mark the current background"
grep -q 'ThemeService.selectBackground' "$DBLOCK" \
    || fail "DashboardThemeBlock does not pick a background through ThemeService"
grep -q 'BackgroundTile' "$DBLOCK" \
    || fail "DashboardThemeBlock does not render background thumbnails"
grep -q 'backgroundPageSize: 4' "$DBLOCK" \
    || fail "DashboardThemeBlock does not cap a background page at four"
grep -q 'backgroundPageItems' "$DBLOCK" \
    || fail "DashboardThemeBlock does not page the background list"
grep -q 'function stepBackgroundPage' "$DBLOCK" \
    || fail "DashboardThemeBlock has no background paging step"
grep -q 'pageForBackground' "$DBLOCK" \
    || fail "DashboardThemeBlock does not land on the current background's page"
grep -q 'Icons.chevronLeft' "$DBLOCK" \
    || fail "DashboardThemeBlock has no previous-page arrow"
grep -q 'Icons.chevronRight' "$DBLOCK" \
    || fail "DashboardThemeBlock has no next-page arrow"
if grep -q 'awww' "$DBLOCK"; then
    fail "DashboardThemeBlock applies the background itself; the renderer path owns the awww call"
fi
if grep -q 'Process' "$DBLOCK"; then
    fail "DashboardThemeBlock spawns its own process; ThemeService owns the apply"
fi

BG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-backgrounds-XXXXXX")"
mkdir -p "$BG_DIR/nested"
printf 'a' > "$BG_DIR/a.png"
printf 'b' > "$BG_DIR/b.JPG"
printf 'c' > "$BG_DIR/c.webp"
printf 'd' > "$BG_DIR/notes.txt"
ln -s "$BG_DIR/a.png" "$BG_DIR/link.png"
ln -s "$BG_DIR/nested" "$BG_DIR/linkdir.png"
printf 'e' > "$BG_DIR/nested/deep.png"
printf 'f' > "$BG_DIR/big.png"
truncate -s 33554433 "$BG_DIR/big.png"
printf 'g' > "$BG_DIR/x..png"
printf 'h' > "$BG_DIR/pipe|name.png"
bg_out="$(sh "$BSCAN" "$BG_DIR" 33554432 | LC_ALL=C sort)"
bg_want="$(printf 'a.png\nb.JPG\nc.webp\n')"
test "$bg_out" = "$bg_want" \
    || fail "background scan listed the wrong files: got [$bg_out] want [$bg_want]"
BG_LINK="$(mktemp -d "${TMPDIR:-/tmp}/qs-theme-backgrounds-XXXXXX")"
ln -s "$BG_DIR" "$BG_LINK/backgrounds"
bg_link_out="$(sh "$BSCAN" "$BG_LINK/backgrounds" 33554432)"
test -z "$bg_link_out" \
    || fail "background scan followed a symlinked backgrounds directory"
rm -rf "$BG_DIR" "$BG_LINK"

node - "$ROOT/tests/qmljs.js" "$TPARSE" <<'NODEEOF'
// ThemeParsers.backgroundMaxBytes, encodePath, and parseBackgroundList: the scan
// output is one file name per line; a line is kept only when it is a bare
// allowed-extension image name, resolved under the backgrounds directory, and
// the list sorts by name so the picker order is stable. The url is the path
// percent-encoded per segment, so a name holding # or ? cannot be read as a URL
// fragment or query by the thumbnail.
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const tp = qmljs.load(process.argv[3]);
const list = (output, dir) => tp.parseBackgroundList(output, dir);
const names = (output, dir) => list(output, dir).map(e => e.name);
check('backgrounds/max-bytes', tp.backgroundMaxBytes(), 33554432);
check('backgrounds/names', names('b.png\na.JPG\nnotes.txt\nbig.webp\n', '/bg'), ['a.JPG', 'b.png', 'big.webp']);
check('backgrounds/order-stable', names('z.png\na.png\nm.png', '/bg'), ['a.png', 'm.png', 'z.png']);
check('backgrounds/path', list('a.png\n', '/bg')[0].path, '/bg/a.png');
check('backgrounds/empty-dir', list('a.png\n', '')[0].path, 'a.png');
check('backgrounds/url-encoded', list('a#b.png\n', '/bg')[0].url, 'file:///bg/a%23b.png');
check('backgrounds/url-space', list('a b.png\n', '/bg')[0].url, 'file:///bg/a%20b.png');
check('backgrounds/drop-extension', names('a.gif\nb.PNG\n', '/bg'), ['b.PNG']);
check('backgrounds/drop-path', list('a/b.png\n', '/bg'), []);
check('backgrounds/drop-dotdot', list('..\n.\n', '/bg'), []);
check('backgrounds/drop-pipe', list('a|b.png\n', '/bg'), []);
check('backgrounds/drop-control', list('a\tb.png\n', '/bg'), []);
check('backgrounds/drop-hidden', list('.hidden.png\n', '/bg'), []);
check('backgrounds/empty', list('', '/bg'), []);
check('backgrounds/non-string', list(null, '/bg'), []);
NODEEOF

# --- 20. fonts: one picker per role, one service, persisted ---
FONTSVC="$ROOT/services/FontService.qml"
FONTVIEW="$ROOT/windows/FontsSettingsView.qml"
FONTROW="$ROOT/components/FontPickerRow.qml"
GLOBALS="$ROOT/config/Globals.qml"

# FontService owns enumeration, role mapping, and persistence; its setters
# write the shared Globals families every Text binds to, so a pick repaints
# the whole shell with no restart.
test -f "$FONTSVC" \
    || fail "services/FontService.qml is missing"
grep -q '^singleton FontService 1.0 FontService.qml' "$ROOT/services/qmldir" \
    || fail "FontService is not registered in services/qmldir"
grep -q 'name: "font-settings"' "$FONTSVC" \
    || fail "FontService does not persist to the font-settings state file"
grep -q 'function applySettings' "$FONTSVC" \
    || fail "FontService has no applySettings"
grep -q 'function saveSettings' "$FONTSVC" \
    || fail "FontService has no saveSettings"
grep -q 'function setFamily' "$FONTSVC" \
    || fail "FontService has no setFamily"
grep -q 'function familyFor' "$FONTSVC" \
    || fail "FontService has no familyFor"
grep -q 'function familiesFor' "$FONTSVC" \
    || fail "FontService has no familiesFor"
grep -q 'Qt.fontFamilies()' "$FONTSVC" \
    || fail "FontService does not enumerate the installed families"
grep -q 'indexOf("Nerd Font")' "$FONTSVC" \
    || fail "FontService does not restrict the icon role to Nerd Fonts"
grep -q 'Globals.uiFontFamily' "$FONTSVC" \
    || fail "FontService does not drive the shared UI family"
grep -q 'Globals.fontFamily' "$FONTSVC" \
    || fail "FontService does not drive the shared bar family"
grep -q 'Globals.iconFontFamily' "$FONTSVC" \
    || fail "FontService does not drive the shared icon family"

# One picker row renders every role, so Change, Search, and No match cannot
# drift between Interface, Bar, and Icons.
test -f "$FONTROW" \
    || fail "components/FontPickerRow.qml is missing"
grep -q 'signal selected' "$FONTROW" \
    || fail "FontPickerRow exposes no selected signal"
grep -q 'NavItem' "$FONTROW" \
    || fail "FontPickerRow does not reuse the shared NavItem for results"
grep -q 'function filtered' "$FONTROW" \
    || fail "FontPickerRow has no filtered()"
grep -q 'property int maxResults' "$FONTROW" \
    || fail "FontPickerRow does not cap its result list"

test -f "$FONTVIEW" \
    || fail "windows/FontsSettingsView.qml is missing"
grep -q 'property string filter' "$FONTVIEW" \
    || fail "FontsSettingsView has no filter property"
grep -q 'FontService.roles' "$FONTVIEW" \
    || fail "FontsSettingsView does not render one picker per FontService role"
grep -q 'FontPickerRow' "$FONTVIEW" \
    || fail "FontsSettingsView does not compose the shared picker row"
grep -q 'FontService.familyFor' "$FONTVIEW" \
    || fail "FontsSettingsView does not read the role family from FontService"
grep -q 'FontService.familiesFor' "$FONTVIEW" \
    || fail "FontsSettingsView does not list the role families from FontService"
grep -q 'FontService.setFamily' "$FONTVIEW" \
    || fail "FontsSettingsView does not write the role family through FontService"
grep -q 'SettingsFilter.matches' "$FONTVIEW" \
    || fail "FontsSettingsView does not filter through the shared SettingsFilter"
grep -q 'FontsSettingsView' "$SCENTER" \
    || fail "SettingsView does not compose the Fonts section"
grep -qF 'root.currentSection.key === "fonts"' "$SCENTER" \
    || fail "SettingsView does not gate the Fonts section"
grep -qF 'key: "fonts"' "$SSVC" \
    || fail "SettingsService has no fonts section"
grep -qF 'FontService.roles.map(role => role.label)' "$SSVC" \
    || fail "SettingsService fonts options do not derive from FontService roles"
if grep -qE 'key: "fonts".*comingSoon: true' "$SSVC"; then
    fail "fonts section is still coming soon"
fi

# The picker sets state; the shared Globals roles must stay writable.
grep -q '^    property string fontFamily' "$GLOBALS" \
    || fail "Globals.fontFamily is not writable"
grep -q '^    property string uiFontFamily' "$GLOBALS" \
    || fail "Globals.uiFontFamily is not writable"
grep -q '^    property string iconFontFamily' "$GLOBALS" \
    || fail "Globals.iconFontFamily is not writable"

if grep -qnE '#[0-9a-fA-F]{3,8}' "$FONTVIEW" "$FONTROW"; then
    fail "fonts settings surface carries raw hex; palette tokens only"
fi

python3 - <<'EOF'
import json
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

# Mirror of FontPickerRow.filtered: case-insensitive substring match, cap 40,
# empty query shows the first page.
def filter_fonts(families, query, cap=40):
    needle = query.strip().lower()
    out = []
    for family in families:
        if len(out) >= cap:
            break
        if needle == "" or needle in family.lower():
            out.append(family)
    return out

check("fonts/filter-empty-caps", filter_fonts([f"F{i}" for i in range(50)], ""), [f"F{i}" for i in range(40)])
check("fonts/filter-match", filter_fonts(["Geist", "Iosevka", "GeistMono"], "geist"), ["Geist", "GeistMono"])
check("fonts/filter-none", filter_fonts(["Geist"], "nope"), [])
EOF

# --- 21. cava restart backoff: exponential, capped, crash-only ---
# restartDelayMs doubles per attempt and clamps at cavaRestartMaxMs; a missing
# cava exits 0 and never enters the loop, and an intentional restartAnalyser
# stop is excluded from the backoff counter so it cannot inflate the delay.
CAVALOGIC="$ROOT/services/CavaLogic.js"
CAVASVC="$ROOT/services/CavaService.qml"
CAVAGLOBALS="$ROOT/config/Globals.qml"

grep -q 'readonly property int cavaRestartBaseMs: 1500' "$CAVAGLOBALS" \
    || fail "Globals.cavaRestartBaseMs is not the 1500ms base"
grep -q 'readonly property int cavaRestartMaxMs: 30000' "$CAVAGLOBALS" \
    || fail "Globals.cavaRestartMaxMs is not the 30000ms cap"
grep -q 'import "CavaLogic.js" as CavaLogic' "$CAVASVC" \
    || fail "CavaService does not import CavaLogic.js"
grep -q 'CavaLogic.restartDelayMs' "$CAVASVC" \
    || fail "CavaService does not compute the restart delay through CavaLogic"
grep -q 'property int restartIntervalMs: Globals.cavaRestartBaseMs' "$CAVASVC" \
    || fail "CavaService does not seed its restart interval from Globals"
grep -q 'interval: root.restartIntervalMs' "$CAVASVC" \
    || fail "CavaService restart timer does not read the backoff interval"
if grep -q 'interval: 1500' "$CAVASVC"; then
    fail "CavaService still hardcodes the 1500ms restart interval"
fi
grep -q 'property bool intentionalStop' "$CAVASVC" \
    || fail "CavaService has no intentionalStop flag"
grep -q 'root.intentionalStop = true' "$CAVASVC" \
    || fail "restartAnalyser does not mark its stop intentional"
# The intentional-exit branch must clear the flag and return before the backoff
# scheduling, so a deliberate restart never enters the crash timer. Extract the
# handler body by indentation instead of a fixed -A count.
onexit_body="$(awk '/^        onExited: exitCode =>/,/^        }$/' "$CAVASVC")"
test -n "$onexit_body" || fail "could not extract CavaService onExited"
intentional_branch="$(printf '%s\n' "$onexit_body" | awk '/if \(root.intentionalStop\)/,/^            }$/')"
printf '%s\n' "$intentional_branch" | grep -q 'root.intentionalStop = false' \
    || fail "onExited intentional branch does not clear the flag"
printf '%s\n' "$intentional_branch" | grep -q 'return;' \
    || fail "onExited intentional branch does not return before the backoff"
if printf '%s\n' "$intentional_branch" | grep -q 'idCavaRestartTimer'; then
    fail "onExited intentional branch schedules the restart timer"
fi
# restartAnalyser's deferred block must set running=true with no !running guard:
# under Quickshell 0.3.1 running=false only SIGTERMs, so the pointer is still
# alive when the deferred block runs and a guard would skip the replacement.
restart_body="$(awk '/^    function restartAnalyser/,/^    }$/' "$CAVASVC")"
test -n "$restart_body" || fail "could not extract CavaService restartAnalyser"
deferred="$(printf '%s\n' "$restart_body" | awk '/Qt\.callLater/,/^        }\);$/')"
printf '%s\n' "$deferred" | grep -q 'idCavaProcess.running = true' \
    || fail "restartAnalyser does not relaunch cava after the stop"
if printf '%s\n' "$deferred" | grep -q '!idCavaProcess.running'; then
    fail "restartAnalyser guards the relaunch on !running; it skips while the old process is alive"
fi
grep -q 'root.restartAttempts = 0' "$CAVASVC" \
    || fail "handleFrame does not reset restartAttempts on a live frame"

node - "$ROOT/tests/qmljs.js" "$CAVALOGIC" <<'NODEEOF'
const qmljs = require(process.argv[2]);
const check = qmljs.checker('panel-logic');
const cl = qmljs.load(process.argv[3]);

const BASE = 1500;
const MAX = 30000;
const want = [1500, 3000, 6000, 12000, 24000, 30000, 30000];
for (let i = 0; i < want.length; i++)
    check('cava/delay-' + i, cl.restartDelayMs(i, BASE, MAX), want[i]);

check('cava/negative', cl.restartDelayMs(-1, BASE, MAX), 1500);
check('cava/nan', cl.restartDelayMs(NaN, BASE, MAX), 1500);
check('cava/non-integer-floor', cl.restartDelayMs(3.9, BASE, MAX), 12000);
check('cava/huge', cl.restartDelayMs(1000, BASE, MAX), 30000);
NODEEOF

# --- 22. bar anchor: one registered trigger per panel, IPC toggles it ---
# PowerService's anchor plumbing (a property plus two functions plus a signal)
# was private per panel; BarAnchor owns it once and each service composes one,
# exposing it as barAnchor, so a keybind lands a panel exactly where its
# trigger sits. The IPC toggle reports a miss when the trigger module is
# hidden instead of silently doing nothing.
BARANCHOR="$ROOT/services/BarAnchor.qml"
test -f "$BARANCHOR" \
    || fail "services/BarAnchor.qml is missing"
grep -q '^BarAnchor 1.0 BarAnchor.qml' "$ROOT/services/qmldir" \
    || fail "BarAnchor is not registered as a non-singleton in services/qmldir"
grep -q 'id: root' "$BARANCHOR" \
    || fail "BarAnchor's file root is not id: root"
grep -q 'property Item anchor: null' "$BARANCHOR" \
    || fail "BarAnchor has no anchor property"
grep -q 'signal toggleRequested' "$BARANCHOR" \
    || fail "BarAnchor has no toggleRequested signal"
for fn in 'function register(trigger: Item)' 'function unregister(trigger: Item)' 'function requestToggle(): bool'; do
    grep -q "$fn" "$BARANCHOR" \
        || fail "BarAnchor has no $fn"
done
# unregister only clears its own trigger, and requestToggle reports whether an
# anchor answered so the IPC target can tell a miss from a toggle.
unregister_body="$(awk '/^    function unregister\(trigger: Item\)/,/^    }$/' "$BARANCHOR")"
test -n "$unregister_body" || fail "could not extract BarAnchor.unregister"
printf '%s\n' "$unregister_body" | grep -q 'root.anchor === trigger' \
    || fail "BarAnchor.unregister does not guard on its own trigger"
request_body="$(awk '/^    function requestToggle/,/^    }$/' "$BARANCHOR")"
test -n "$request_body" || fail "could not extract BarAnchor.requestToggle"
printf '%s\n' "$request_body" | grep -q 'root.toggleRequested()' \
    || fail "BarAnchor.requestToggle does not emit toggleRequested"
printf '%s\n' "$request_body" | grep -q 'return true' \
    || fail "BarAnchor.requestToggle does not return true on a live anchor"
printf '%s\n' "$request_body" | grep -q 'return false' \
    || fail "BarAnchor.requestToggle does not return false without an anchor"
# Each panel service composes one and exposes it under the same name.
for svc in PowerService CalendarService NotificationServer; do
    grep -q 'BarAnchor {' "$ROOT/services/$svc.qml" \
        || fail "$svc does not compose a BarAnchor"
    grep -q 'readonly property BarAnchor barAnchor: idBarAnchor' "$ROOT/services/$svc.qml" \
        || fail "$svc does not expose barAnchor"
done
# The three IPC targets each route toggle through the anchor; the quick panel
# targets return a status string in the theme target's style.
for target in power:PowerService calendar:CalendarService notifications:NotificationServer; do
    name="${target%%:*}"
    svc="${target##*:}"
    grep -q "target: \"$name\"" "$ROOT/services/$svc.qml" \
        || fail "$svc has no IpcHandler target \"$name\""
    grep -q 'idBarAnchor.requestToggle()' "$ROOT/services/$svc.qml" \
        || fail "$svc's $name toggle does not route through the anchor"
done
grep -q '"error: clock module is hidden"' "$ROOT/services/CalendarService.qml" \
    || fail "Calendar's toggle does not report a hidden clock"
grep -q '"error: notifications module is hidden"' "$ROOT/services/NotificationServer.qml" \
    || fail "Notifications' toggle does not report a hidden module"
# Each trigger module registers while anchored and answers the toggle signal.
for pair in PowerMenu:PowerService Clock:CalendarService Notifications:NotificationServer; do
    mod="${pair%%:*}"
    svc="${pair##*:}"
    grep -q "$svc.barAnchor.register(" "$ROOT/modules/$mod.qml" \
        || fail "$mod does not register with $svc.barAnchor"
    grep -q 'onToggleRequested' "$ROOT/modules/$mod.qml" \
        || fail "$mod does not handle the anchor's toggleRequested"
done
# The handler body must guard on the module's own state: with a Clock on every
# bar, an unguarded handler toggles the calendar once per monitor on one IPC
# request (open then close).
clock_toggle="$(awk '/^        function onToggleRequested\(\)/,/^        \}$/' "$ROOT/modules/Clock.qml")"
test -n "$clock_toggle" || fail "could not extract Clock.onToggleRequested"
printf '%s\n' "$clock_toggle" | grep -q 'root.anchorActive' \
    || fail "Clock.onToggleRequested does not guard on its primary-only anchor"
for mod in Notifications PowerMenu; do
    toggle_body="$(awk '/^        function onToggleRequested\(\)/,/^        \}$/' "$ROOT/modules/$mod.qml")"
    test -n "$toggle_body" || fail "could not extract $mod.onToggleRequested"
    printf '%s\n' "$toggle_body" | grep -q 'root.visible' \
        || fail "$mod.onToggleRequested does not guard on visibility"
done
# Clock lives on every bar; only the primary one anchors, and its sync follows
# both visibility and the resolved primary through one binding.
clock_gate="$(grep 'property bool anchorActive' "$ROOT/modules/Clock.qml")"
test -n "$clock_gate" || fail "Clock has no anchorActive gate"
printf '%s\n' "$clock_gate" | grep -q 'root.visible' \
    || fail "Clock's anchor gate ignores visibility"
printf '%s\n' "$clock_gate" | grep -q 'Globals.onPrimaryMonitor(root.monitorName)' \
    || fail "Clock's anchor gate ignores the primary monitor"
clock_sync="$(awk '/^    function syncAnchor/,/^    }$/' "$ROOT/modules/Clock.qml")"
test -n "$clock_sync" || fail "could not extract Clock.syncAnchor"
printf '%s\n' "$clock_sync" | grep -q 'root.anchorActive' \
    || fail "Clock.syncAnchor ignores its primary-only gate"
printf '%s\n' "$clock_sync" | grep -q 'CalendarService.barAnchor.register(' \
    || fail "Clock.syncAnchor does not register its trigger"

# --- 23. IPC targets: dashboard, dnd, and volume ---
# The dashboard opens on the focused screen at its center; dnd persists through
# the notifications state file; volume reports the sink's raw percent. Each
# handler body is extracted by its target so a re-inlined copy cannot pass.
DASHSVC="$ROOT/services/DashboardService.qml"
NOTIFSVC="$ROOT/services/NotificationServer.qml"
AUDIOSVC="$ROOT/services/AudioService.qml"
MONITORSVC="$ROOT/services/MonitorService.qml"

for pair in "dashboard:$DASHSVC" "dnd:$NOTIFSVC" "volume:$AUDIOSVC"; do
    name="${pair%%:*}"
    svc="${pair##*:}"
    grep -q "target: \"$name\"" "$svc" \
        || fail "$(basename "$svc") has no IpcHandler target \"$name\""
done

dashboard_ipc="$(awk '/target: "dashboard"/,/^    }$/' "$DASHSVC")"
test -n "$dashboard_ipc" || fail "could not extract the dashboard IPC handler"
for fn in 'function toggle(): string' 'function open(): string' 'function close(): string' 'function settings(section: string): string'; do
    printf '%s\n' "$dashboard_ipc" | grep -q "$fn" \
        || fail "dashboard IPC has no $fn"
done
printf '%s\n' "$dashboard_ipc" | grep -q 'MonitorService.focusedScreen()' \
    || fail "dashboard IPC does not resolve the focused screen"
test "$(printf '%s\n' "$dashboard_ipc" | grep -c 'screen.width / 2')" -ge 3 \
    || fail "dashboard IPC does not center each open on the focused screen"
for call in 'root.toggleDashboardAt' 'root.openDashboardAt' 'root.openSettingsAt'; do
    printf '%s\n' "$dashboard_ipc" | grep -q "$call" \
        || fail "dashboard IPC does not delegate $call"
done
printf '%s\n' "$dashboard_ipc" | grep -q 'SettingsService.sectionRegistry' \
    || fail "dashboard settings IPC does not validate the section key"
printf '%s\n' "$dashboard_ipc" | grep -q '"error: no screen"' \
    || fail "dashboard IPC does not report a missing screen"
printf '%s\n' "$dashboard_ipc" | grep -q '"error: no section "' \
    || fail "dashboard IPC does not report an unknown section"
test "$(printf '%s\n' "$dashboard_ipc" | grep -c 'return "ok";')" -ge 3 \
    || fail "dashboard IPC toggle, open and close do not return \"ok\""
printf '%s\n' "$dashboard_ipc" | grep -q 'return "ok: " + section;' \
    || fail "dashboard IPC settings does not echo the opened section"
printf '%s\n' "$dashboard_ipc" | grep -q 'root.closeDashboardFromOutside()' \
    || fail "dashboard IPC close does not close like the other panel targets"

volume_ipc="$(awk '/target: "volume"/,/^    }$/' "$AUDIOSVC")"
test -n "$volume_ipc" || fail "could not extract the volume IPC handler"
for fn in 'function up(): string' 'function down(): string' 'function set(percent: int): string' 'function mute(): string' 'function status(): string'; do
    printf '%s\n' "$volume_ipc" | grep -q "$fn" \
        || fail "volume IPC has no $fn"
done
for call in 'root.stepVolume' 'root.setVolume' 'root.toggleMute'; do
    printf '%s\n' "$volume_ipc" | grep -q "$call" \
        || fail "volume IPC does not delegate $call"
done
grep -q 'AudioLogic.statusText' "$AUDIOSVC" \
    || fail "volume IPC does not report through AudioLogic.statusText"
grep -q '"error: no sink"' "$AUDIOSVC" \
    || fail "volume IPC does not report a missing sink"

dnd_ipc="$(awk '/target: "dnd"/,/^    }$/' "$NOTIFSVC")"
test -n "$dnd_ipc" || fail "could not extract the dnd IPC handler"
for fn in 'function toggle(): string' 'function on(): string' 'function off(): string' 'function status(): string'; do
    printf '%s\n' "$dnd_ipc" | grep -q "$fn" \
        || fail "dnd IPC has no $fn"
done
printf '%s\n' "$dnd_ipc" | grep -q 'root.dndEnabled' \
    || fail "dnd IPC does not report the persisted state"
test "$(printf '%s\n' "$dnd_ipc" | grep -c '"on"')" -ge 3 \
    || fail "dnd IPC does not return \"on\" from toggle, on and status"
test "$(printf '%s\n' "$dnd_ipc" | grep -c '"off"')" -ge 3 \
    || fail "dnd IPC does not return \"off\" from toggle, off and status"
grep -q 'name: "notifications"' "$NOTIFSVC" \
    || fail "NotificationServer does not persist to the notifications state file"
grep -q 'StateParsers.parseNotificationSettings' "$NOTIFSVC" \
    || fail "NotificationServer does not parse its settings through StateParsers"
grep -q 'onDndEnabledChanged: root.saveNotificationSettings' "$NOTIFSVC" \
    || fail "NotificationServer does not save DND on change"

grep -q 'Hyprland.focusedMonitor' "$MONITORSVC" \
    || fail "MonitorService.focusedScreen does not read the Hyprland focused monitor"
grep -q 'MonitorLogic.pickScreenName' "$MONITORSVC" \
    || fail "MonitorService.focusedScreen does not resolve the name through MonitorLogic"

# --- 24. volume OSD: transient click-through layer on the focused monitor ---
# The OSD reacts to PipeWire property changes (not the volume IPC), sits
# bottom-center on the focused monitor, and never steals input. windows/ is an
# implicit module with no qmldir, so lint.sh and lint-review.sh pick the new
# file up through their tracked-plus-untracked QML glob.
OSD="$ROOT/windows/VolumeOsd.qml"
test -f "$OSD" \
    || fail "windows/VolumeOsd.qml is missing"
grep -q 'VolumeOsd {}' "$ROOT/shell.qml" \
    || fail "shell.qml does not instantiate VolumeOsd"
grep -q 'ExclusionMode.Ignore' "$OSD" \
    || fail "VolumeOsd does not ignore exclusive zones"
grep -q 'mask: Region {}' "$OSD" \
    || fail "VolumeOsd does not mask an empty Region; it would steal input"
grep -q 'MonitorService.focusedScreen()' "$OSD" \
    || fail "VolumeOsd does not place itself on the focused screen"
grep -q 'Globals.osdHoldMs' "$OSD" \
    || fail "VolumeOsd does not hold for Globals.osdHoldMs"
grep -q 'Globals.osdArmMs' "$OSD" \
    || fail "VolumeOsd does not guard startup with Globals.osdArmMs"
grep -q 'Globals.reducedMotion' "$OSD" \
    || fail "VolumeOsd ignores Globals.reducedMotion"
for handler in onVolumesChanged onMutedChanged; do
    grep -q "function $handler" "$OSD" \
        || fail "VolumeOsd does not handle $handler"
done
# PwNodeAudio.volume declares its NOTIFY as volumesChanged; binding the
# auto-named onVolumeChanged would never fire (installed 0.3.1 qmltypes).
if grep -q 'onVolumeChanged' "$OSD"; then
    fail "VolumeOsd binds onVolumeChanged, which PwNodeAudio does not emit"
fi
grep -q 'AudioService.defaultSink ? AudioService.defaultSink.audio : null' "$OSD" \
    || fail "VolumeOsd does not target the default sink's PwNodeAudio"
grep -q 'Icons.volumeOff' "$OSD" \
    || fail "VolumeOsd misses the no-sink glyph"
grep -q 'Icons.volumeMute' "$OSD" \
    || fail "VolumeOsd misses the muted glyph"
grep -q 'Icons.volumeHigh' "$OSD" \
    || fail "VolumeOsd misses the audible glyph"
grep -q 'AudioService.percentText' "$OSD" \
    || fail "VolumeOsd does not use the AudioLogic percent rounding"
grep -q 'TextMetrics' "$OSD" \
    || fail "VolumeOsd does not reserve the percent width with TextMetrics"
# No literal ms/px for the window timing or canvas: every value is a token.
if grep -qE 'interval: [0-9]' "$OSD"; then
    fail "VolumeOsd hardcodes a timer interval instead of a Globals token"
fi
for prop in implicitWidth implicitHeight; do
    if grep -qE "$prop: [0-9]" "$OSD"; then
        fail "VolumeOsd hardcodes $prop instead of a Globals token"
    fi
done
for token in osdHoldMs osdArmMs osdWidth osdHeight osdBottomMargin; do
    grep -q "property int $token" "$ROOT/config/Globals.qml" \
        || fail "Globals has no $token token"
done
test -f "$ROOT/docs/adr/0017-volume-osd.md" \
    || fail "docs/adr/0017-volume-osd.md is missing"

echo "panel-logic: all ok"
