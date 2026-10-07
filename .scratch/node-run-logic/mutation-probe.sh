#!/usr/bin/env bash
# Mutation probe for the node-run-logic feature. Plant one bug at a time in a
# copy of the repo and record whether the two logic test scripts catch it.
# Usage: mutation-probe.sh <repo>. A mutant whose original text no longer
# matches (because its function moved to a *Logic.js file) reports NOT APPLIED;
# retarget it at the new file when the ticket moves that function.
set -u
src="$1"
work="${TMPDIR:-/tmp}/qs-mutation-probe"
# file | exact original | mutated | label
mutants=(
"services/WeatherService.qml|return Math.round(value) + \"°\";|return Math.floor(value) + \"°\";|Weather.formatTemp round→floor"
"services/WeatherService.qml|return (nowMs - fetchedAtMs) > root.staleAfterMs;|return (nowMs - fetchedAtMs) >= root.staleAfterMs * 2;|Weather.isStale threshold x2"
"services/WeatherService.qml|return Icons.weatherFog;|return Icons.weatherCloudy;|Weather.glyphFor fog→cloudy"
"services/SpotifyService.qml|out.ok = parsed.ok === true;|out.ok = Boolean(parsed.ok);|Spotify.parseResponse truthy ok"
"services/MprisPlayers.qml|return minutes + \":\" + (secs < 10 ? \"0\" : \"\") + secs;|return minutes + \":\" + secs;|Mpris.formatTime no pad"
"services/MprisPlayers.qml|return MprisLoopState.None;|return MprisLoopState.Playlist;|Mpris.nextLoopState Track→Playlist"
"services/MprisPlayers.qml|item[\"allowed\"] = entry.allowed !== false;|item[\"allowed\"] = entry.allowed === true;|Mpris.parseApps default allowed"
"services/MonitorLogic.js|return index * perMonitor + 1;|return index * perMonitor;|Monitor.firstWorkspaceFor off by one"
"services/MonitorLogic.js|return Math.max(1, Math.min(20, count));|return Math.max(1, Math.min(30, count));|Monitor.clamp max 30"
"services/SystemMonitor.qml|const iface = lines[i].slice(0, colon).trim();|const iface = lines[i].slice(0, colon);|SystemMonitor.parseNetSample untrimmed iface"
"services/SystemInfo.qml|return (count / 1000).toFixed(1) + \"k\";|return (count / 1000).toFixed(0) + \"k\";|SystemInfo.formatPackages precision"
"services/AudioService.qml|return Math.round(Math.max(0, Math.min(1, value)) * 100);|return Math.floor(Math.max(0, Math.min(1, value)) * 100);|Audio.percentForVolume round→floor"
"services/BarVisibilityService.qml|if (parsed[key] === false)|if (!parsed[key])|BarVisibility.parseVisibility falsy hides"
"services/StateParsers.js|return Math.max(range[0], Math.min(range[1], n));|return Math.max(range[0], n);|StateParsers.parseCavaSettings no upper clamp"
"services/ThemeParsers.js|function isValidThemeName(name) {|function isValidThemeName(name) { return typeof name === \"string\" \&\& name !== \"\";|ThemeParsers.isValidThemeName accepts all (node-tested control)"
)
printf '%-62s %-12s %-12s\n' "mutant" "panel-logic" "dash-data"
for m in "${mutants[@]}"; do
  IFS='|' read -r file orig mut label <<<"$m"
  rm -rf "$work"; cp -a "$src" "$work"; rm -rf "$work/.git"
  python3 - "$work/$file" "$orig" "$mut" <<'PY' || { printf '%-62s %s\n' "$label" "NOT APPLIED"; continue; }
import sys
p, o, n = sys.argv[1:]
s = open(p, encoding="utf-8").read()
if s.count(o) != 1:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(o, n))
PY
  r1=caught; bash "$work/scripts/test-panel-logic.sh" >/dev/null 2>&1 && r1=MISSED
  r2=caught; bash "$work/scripts/test-dashboard-data.sh" >/dev/null 2>&1 && r2=MISSED
  printf '%-62s %-12s %-12s\n' "$label" "$r1" "$r2"
done
rm -rf "$work"
