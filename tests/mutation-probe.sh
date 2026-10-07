#!/usr/bin/env bash
# Mutation probe for the node-run-logic feature. Plant one bug at a time in a
# copy of the repo and record whether the two logic test scripts catch it.
# Usage: mutation-probe.sh <repo>. A mutant whose original text no longer
# matches (because its function moved to a *Logic.js file) reports NOT APPLIED;
# retarget it at the new file when the ticket moves that function.
set -u
if [ $# -lt 1 ]; then
    echo "usage: $0 <repo>" >&2
    exit 2
fi
src="$1"
# Unique per process: two probes running at once must not overwrite each
# other's repo copy.
work="$(mktemp -d "${TMPDIR:-/tmp}/qs-mutation-probe.XXXXXX")"
trap 'rm -rf "${work:?}"' EXIT

# A mutant is only "caught" if the unmutated repo passes first; otherwise a
# broken harness (missing node or python3) would report every mutant as caught.
for script in scripts/test-panel-logic.sh scripts/test-dashboard-data.sh; do
    if ! bash "$src/$script" >/dev/null 2>&1; then
        echo "baseline $script fails on the unmutated repo; probe cannot judge" >&2
        exit 1
    fi
done
# file | exact original | mutated | label
mutants=(
"services/WeatherLogic.js|return Math.round(value) + \"°\";|return Math.floor(value) + \"°\";|Weather.formatTemp round→floor"
"services/WeatherLogic.js|return (nowMs - fetchedAtMs) > staleAfterMs;|return (nowMs - fetchedAtMs) >= staleAfterMs * 2;|Weather.isStale threshold x2"
"services/WeatherLogic.js|return \"weatherFog\";|return \"weatherCloudy\";|Weather.glyphFor fog→cloudy"
"services/SpotifyLogic.js|out.ok = parsed.ok === true;|out.ok = Boolean(parsed.ok);|Spotify.parseResponse truthy ok"
"services/MprisLogic.js|return minutes + \":\" + (secs < 10 ? \"0\" : \"\") + secs;|return minutes + \":\" + secs;|Mpris.formatTime no pad"
"services/MprisLogic.js|return states.None;|return states.Playlist;|Mpris.nextLoopState Track→Playlist"
"services/MprisLogic.js|item[\"allowed\"] = entry.allowed !== false;|item[\"allowed\"] = entry.allowed === true;|Mpris.parseApps default allowed"
"services/MonitorLogic.js|return index * perMonitor + 1;|return index * perMonitor;|Monitor.firstWorkspaceFor off by one"
"services/MonitorLogic.js|return Math.max(1, Math.min(20, count));|return Math.max(1, Math.min(30, count));|Monitor.clamp max 30"
"services/SystemLogic.js|const iface = lines[i].slice(0, colon).trim();|const iface = lines[i].slice(0, colon);|SystemMonitor.parseNetSample untrimmed iface"
"services/SystemLogic.js|return (count / 1000).toFixed(1) + \"k\";|return (count / 1000).toFixed(0) + \"k\";|SystemInfo.formatPackages precision"
"services/AudioLogic.js|return Math.round(Math.max(0, Math.min(1, value)) * 100);|return Math.floor(Math.max(0, Math.min(1, value)) * 100);|Audio.percentForVolume round→floor"
"services/StateParsers.js|if (parsed[key] === false)|if (!parsed[key])|BarVisibility.parseVisibility falsy hides"
"services/StateParsers.js|return Math.max(range[0], Math.min(range[1], n));|return Math.max(range[0], n);|StateParsers.parseCavaSettings no upper clamp"
"services/ThemeParsers.js|function isValidThemeName(name) {|function isValidThemeName(name) { return typeof name === \"string\" \&\& name !== \"\";|ThemeParsers.isValidThemeName accepts all (node-tested control)"
)
printf '%-62s %-12s %-12s\n' "mutant" "panel-logic" "dash-data"
for m in "${mutants[@]}"; do
  IFS='|' read -r file orig mut label <<<"$m"
  rm -rf "${work:?}"; mkdir -p "$work"; cp -a "$src/." "$work/"; rm -rf "${work:?}/.git"
  # A half-finished copy would make the suite under test fail and read as a
  # false "caught"; assert the tree landed.
  test -f "$work/scripts/test-panel-logic.sh" || { echo "copy failed for $label" >&2; exit 1; }
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
