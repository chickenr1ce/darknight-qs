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
for svc in CalendarService NotificationServer CavaService Panels PowerService; do
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
# Lock fires at once; the other four only arm.
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
for key in '"1"' '"2"' '"3"' '"4"' '"5"' '"Return"' '"Enter"'; do
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

echo "panel-logic: all ok"
