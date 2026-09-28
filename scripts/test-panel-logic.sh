#!/usr/bin/env bash
# Headless logic gate for the panel architecture (review #07, Q4).
#
# A full QML boot needs a compositor, so this gate does not boot one.
# Instead it checks two things that run anywhere:
#   1. structural assertions over the QML: the one-panel rule, the monitor
#      policy, the invoke path, and the cava formula each live in exactly
#      one place, so the mesh cannot silently grow back;
#   2. python oracles mirroring the pure QML helpers (stale, anchor clamp,
#      monitor policy, debounce, focus queue) at their boundary values.
#      Each oracle cites its QML source; change the source and update the
#      mirror in the same commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "panel-logic FAIL: $*" >&2; exit 1; }

# --- 1. one-panel rule lives in services/Panels.qml only ---
# Direct writes to another panel's visibility outside the registry mean the
# N-squared mesh is growing back. Alias declarations use a colon, so only
# match plain assignments.
WRITERS="$(grep -rn --include='*.qml' -E '(calendarVisible|centerVisible|cavaVisible|powerVisible) = ' "$ROOT/modules" "$ROOT/windows" "$ROOT/services" || true)"
echo "$WRITERS" | grep -v '^$' | grep -v 'services/Panels.qml' | grep -q . \
    && fail "panel visibility written outside services/Panels.qml: $(echo "$WRITERS" | grep -v 'services/Panels.qml')"
test -z "$(echo "$WRITERS" | grep -v '^$')" \
    && fail "no panel visibility writes found at all; the registry owns eight (2 per toggle)"

# Toasts hide while ANY panel is open (toasts-over-cava was the leak).
grep -q 'Panels.anyOpen' "$ROOT/windows/NotificationPopups.qml" \
    || fail "NotificationPopups does not gate on Panels.anyOpen"

# Triggers call the registry instead of each other's services.
for trigger in "Clock.qml:Panels.toggleCalendarAt" "Notifications.qml:Panels.toggleCenterAt" "Cava.qml:Panels.toggleCavaAt" "PowerMenu.qml:Panels.togglePowerAt"; do
    file="${trigger%%:*}"
    call="${trigger##*:}"
    grep -q "$call" "$ROOT/modules/$file" \
        || fail "$file does not call $call"
done

# --- 2. monitor policy is data in Globals, composed in modules ---
grep -q 'monitorName === "DP-1"' "$ROOT/shell.qml" \
    && fail "shell.qml still gates modules by monitor name directly"
grep -q 'primaryMonitor' "$ROOT/config/Globals.qml" \
    || fail "Globals has no primaryMonitor policy"
grep -q 'function onPrimaryMonitor' "$ROOT/config/Globals.qml" \
    || fail "Globals has no onPrimaryMonitor helper"
for module in Tray Media Audio PowerMenu Cava Notifications; do
    grep -q 'property string monitorName' "$ROOT/modules/$module.qml" \
        || fail "$module.qml declares no monitorName"
    grep -q 'Globals.onPrimaryMonitor(root.monitorName)' "$ROOT/modules/$module.qml" \
        || fail "$module.qml does not compose Globals.onPrimaryMonitor"
done

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
for site in "modules/Tray.qml" "services/NotificationServer.qml"; do
    grep -q 'HyprlandFocus.focusByTokens' "$ROOT/$site" \
        || fail "$site does not delegate to HyprlandFocus"
done
if grep -rn --include='*.qml' 'lastIpcObject' "$ROOT/modules/Tray.qml" "$ROOT/services/NotificationServer.qml" | grep -q .; then
    fail "matcher logic leaked back into a call site"
fi

# --- 3b. module siblings resolve only through a self-import ---
# qmllint resolves same-directory siblings, the runtime does not when the
# directory is a qmldir module: every service file that names a sibling
# type must import qs.services, and every sibling component must be in qmldir.
for svc in CalendarService NotificationServer CavaService Panels PowerService SettingsService; do
    grep -q '^import qs.services' "$ROOT/services/$svc.qml" \
        || fail "$svc.qml is missing its qs.services self-import"
done
grep -q '^PanelState 1.0 PanelState.qml' "$ROOT/services/qmldir" \
    || fail "PanelState is not registered in services/qmldir"
grep -q '^singleton PowerService 1.0 PowerService.qml' "$ROOT/services/qmldir" \
    || fail "PowerService is not registered in services/qmldir"
grep -q 'PowerService.powerVisible' "$ROOT/services/Panels.qml" \
    || fail "Panels does not own the power one-panel rule"

# --- 4. single invoke path for notification actions ---
for pill in components/NotificationToast.qml components/NotificationCard.qml; do
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

# --- 6. python oracles for the pure helpers ---
python3 - <<'EOF'
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

# Mirror of Globals.onPrimaryMonitor (config/Globals.qml): primary is DP-1.
def on_primary(monitor):
    return monitor == "" or monitor == "DP-1"

check("monitor/empty", on_primary(""), True)
check("monitor/primary", on_primary("DP-1"), True)
check("monitor/other", on_primary("DP-2"), False)

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
EOF

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
for block in DashboardTabs DashboardWeatherBlock DashboardSystemBlock DashboardCpuBlock DashboardVolumeBlock DashboardPlayerBlock DashboardThemeBlock; do
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
grep -q 'DashboardTabs' "$DCENTER" \
    || fail "DashboardCenter does not compose the tab row"
grep -q 'DashboardPlayerBlock' "$DCENTER" \
    || fail "DashboardCenter does not compose the player block"
if grep -qiE 'cream|peach' "$ROOT"/windows/Dashboard*.qml; then
    fail "dashboard blocks carry reference cream/peach; palette tokens only"
fi

# --- 9. settings window: Hyprland-managed toplevel, dashboard gear, search ---
# Settings is a FloatingWindow hosted in a Loader, outside the exclusive
# registry. It owns no focus grab; opening it closes the dashboard (ADR 0007).
SSVC="$ROOT/services/SettingsService.qml"
SCENTER="$ROOT/windows/SettingsCenter.qml"
CSV="$ROOT/windows/CavaSettingsView.qml"

test -f "$SSVC" \
    || fail "services/SettingsService.qml is missing"
grep -q 'property bool visible: false' "$SSVC" \
    || fail "SettingsService has no visible flag"
grep -qF 'function open(screen)' "$SSVC" \
    || fail "SettingsService has no open(screen)"
grep -qF 'function close' "$SSVC" \
    || fail "SettingsService has no close"
grep -q '^import qs.services' "$SSVC" \
    || fail "SettingsService.qml is missing its qs.services self-import"
grep -q '^singleton SettingsService 1.0 SettingsService.qml' "$ROOT/services/qmldir" \
    || fail "SettingsService is not registered in services/qmldir"
if grep -q 'SettingsService' "$ROOT/services/Panels.qml"; then
    fail "Panels owns SettingsService; settings opens from the dashboard, not the registry"
fi

# Settings is a toplevel, not a PanelShell: the shared-grab switches are gone.
if grep -qE 'grabEnabled|extraGrabWindows' "$ROOT/components/PanelShell.qml"; then
    fail "PanelShell still carries the settings shared-grab switches; settings is a toplevel now"
fi

test -f "$SCENTER" \
    || fail "windows/SettingsCenter.qml is missing"
grep -q 'FloatingWindow' "$SCENTER" \
    || fail "SettingsCenter is not a Hyprland-managed FloatingWindow"
grep -q 'active: SettingsService.visible' "$SCENTER" \
    || fail "SettingsCenter does not gate on SettingsService.visible"
grep -q 'SettingsService.close()' "$SCENTER" \
    || fail "SettingsCenter does not close via SettingsService"
grep -qF 'settingsWindowTitle: "Settings"' "$SCENTER" \
    || fail "SettingsCenter has no settingsWindowTitle for the Hyprland float rule to match"
grep -qF 'title: root.settingsWindowTitle' "$SCENTER" \
    || fail "SettingsCenter window title does not derive from settingsWindowTitle"
grep -qF '"title:^" + root.settingsWindowTitle' "$SCENTER" \
    || fail "SettingsCenter placement selector does not derive from settingsWindowTitle"
grep -q 'Globals.settingsWidth' "$SCENTER" \
    || fail "SettingsCenter does not size from Globals.settingsWidth"
grep -q 'Globals.settingsHeight' "$SCENTER" \
    || fail "SettingsCenter does not size from Globals.settingsHeight"
grep -q 'Globals.settingsSidebarWidth' "$SCENTER" \
    || fail "SettingsCenter does not size the sidebar from Globals.settingsSidebarWidth"
grep -qF 'qsTr("Search settings…")' "$SCENTER" \
    || fail "SettingsCenter has no search field"
grep -qF 'qsTr("No match")' "$SCENTER" \
    || fail "SettingsCenter has no no-match note"
grep -q 'NavItem' "$SCENTER" \
    || fail "SettingsCenter does not compose the sidebar NavItem"
grep -q 'SettingsCenter' "$ROOT/shell.qml" \
    || fail "shell.qml does not instantiate SettingsCenter"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$SCENTER" "$CSV" "$SSVC" "$ROOT/components/NavItem.qml"; then
    fail "settings surface carries raw hex; palette tokens only"
fi

# Dashboard gear opens settings on the dashboard's screen; opening settings
# closes the dashboard and opening the dashboard closes settings, so the two
# never stack.
grep -q 'SettingsService.open' "$DCENTER" \
    || fail "DashboardCenter gear does not open settings"
grep -qF 'accessibleName: qsTr("Settings")' "$DCENTER" \
    || fail "DashboardCenter has no settings gear"
grep -qF 'DashboardService.close()' "$SSVC" \
    || fail "SettingsService does not close the dashboard when settings opens"
grep -qF 'SettingsService.close()' "$DSVC" \
    || fail "DashboardService does not close settings when the dashboard opens"

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
grep -qF 'matches(qsTr("Style"))' "$CSV" \
    || fail "CavaSettingsView does not filter the Style option"
for label in "Sensitivity" "Auto sensitivity" "Bars" "Max height"; do
    grep -qF "matches(qsTr(\"$label\"))" "$CSV" \
        || fail "CavaSettingsView does not filter the $label option"
    grep -qF "qsTr(\"$label\")" "$SSVC" \
        || fail "SettingsService sections do not list $label for search"
done
grep -qF 'qsTr("Style")' "$SSVC" \
    || fail "SettingsService sections do not list Style for search"

# Settings tokens exist and the sidebar component is shared.
grep -q 'property int settingsWidth' "$ROOT/config/Globals.qml" \
    || fail "Globals has no settingsWidth token"
grep -q 'property int settingsHeight' "$ROOT/config/Globals.qml" \
    || fail "Globals has no settingsHeight token"
grep -q 'property int settingsSidebarWidth' "$ROOT/config/Globals.qml" \
    || fail "Globals has no settingsSidebarWidth token"
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

# Zones plus feeds persist through the CalendarService state files; the parse
# validation is unchanged. Oracle mirrors CalendarService.parseZones.
python3 - <<'EOF'
import re
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

# Mirror of CalendarService.parseZones (services/CalendarService.qml): trim,
# reject names failing the regex, drop duplicates, cap at maxZones = 6.
def parse_zones(text, max_zones=6):
    zones = []
    lines = text.split("\n")
    i = 0
    while i < len(lines) and len(zones) < max_zones:
        name = lines[i].strip()
        if name != "" and re.fullmatch(r"[A-Za-z0-9_\-+/]+", name) and name not in zones:
            zones.append(name)
        i += 1
    return zones

check("zones/trim-dedupe", parse_zones(" UTC \nUTC\nEurope/Berlin\n"), ["UTC", "Europe/Berlin"])
check("zones/reject-invalid", parse_zones("UTC\nbad name\nAsia/Tokyo\n"), ["UTC", "Asia/Tokyo"])
check("zones/cap", parse_zones("\n".join(f"Z{i}" for i in range(10))), ["Z0", "Z1", "Z2", "Z3", "Z4", "Z5"])
check("zones/empty", parse_zones(""), [])
EOF

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
grep -q 'applyingSettings' "$BSVC" \
    || fail "BarVisibilityService has no echo guard"
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
grep -qF 'matches(qsTr("Bar visibility"))' "$BVIEW" \
    || fail "LayoutSettingsView does not match its Bar visibility search label, so searching it shows an empty body"
grep -q 'LayoutSettingsView' "$SCENTER" \
    || fail "SettingsCenter does not compose the Layout section"
if grep -qnE '#[0-9a-fA-F]{3,8}' "$BVIEW" "$BSVC"; then
    fail "bar visibility surface carries raw hex; palette tokens only"
fi

# parseVisibility oracle: default all true, only an explicit false hides,
# unknown keys ignored, malformed input falls back to defaults.
python3 - <<'EOF'
import json
import sys

def check(name, got, want):
    if got != want:
        print(f"panel-logic FAIL: {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

KEYS = ["clock", "workspaces", "tray", "cava", "media", "audio", "notifications", "power"]

# Mirror of BarVisibilityService.parseVisibility (services/BarVisibilityService.qml).
def parse_visibility(text, keys=KEYS):
    out = {key: True for key in keys}
    try:
        parsed = json.loads(text)
    except Exception:
        return out
    if not isinstance(parsed, dict):
        return out
    for key in keys:
        if parsed.get(key) is False:
            out[key] = False
    return out

check("barvis/default", parse_visibility(""), {key: True for key in KEYS})
check("barvis/malformed", parse_visibility("{nope"), {key: True for key in KEYS})
check("barvis/list", parse_visibility("[1, 2]"), {key: True for key in KEYS})
check("barvis/hide", parse_visibility('{"media": false}')["media"], False)
check("barvis/kept", parse_visibility('{"media": false}')["clock"], True)
check("barvis/unknown", parse_visibility('{"nope": false}'), {key: True for key in KEYS})
check("barvis/nonbool", parse_visibility('{"clock": 0}')["clock"], True)
EOF

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
test -f "$ROOT/docs/settings-sections.md" \
    || fail "docs/settings-sections.md is missing"
grep -q 'settings-sections.md' "$ROOT/AGENTS.md" \
    || fail "AGENTS.md does not point at docs/settings-sections.md"
grep -q 'SettingsToggleRow' "$ROOT/docs/coding-conventions.md" \
    || fail "coding conventions do not require shared settings rows"

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

echo "panel-logic: all ok"
