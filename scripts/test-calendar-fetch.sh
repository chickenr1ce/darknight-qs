#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FETCH="$ROOT/scripts/calendar-fetch.py"
FIXTURE="$ROOT/tests/fixtures/calendar-basic.ics"
EXPECTED="$ROOT/tests/fixtures/calendar-basic.expected.json"
WORK="$(mktemp -d /tmp/opencode/calendar-test-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

export TZ=UTC

TZ=UTC python3 "$FETCH" --input "$FIXTURE" --now "2026-09-16T12:00:00" \
    --cache-file "$WORK/actual.json" >/dev/null
python3 - "$WORK/actual.json" "$EXPECTED" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
expected = json.load(open(sys.argv[2]))
assert actual == expected, (
    "conversion mismatch:\nactual:   %s\nexpected: %s" % (actual, expected))
EOF
echo "calendar-fetch: fixture conversion ok"

TZ=UTC python3 "$FETCH" --input "$ROOT/tests/fixtures/calendar-birthday.ics" \
    --input "$ROOT/tests/fixtures/calendar-holiday.ics" --now "2026-09-16T12:00:00" \
    --cache-file "$WORK/multi.json" >/dev/null
python3 - "$WORK/multi.json" "$ROOT/tests/fixtures/calendar-multi.expected.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
expected = json.load(open(sys.argv[2]))
assert actual == expected, (
    "multi-feed mismatch:\nactual:   %s\nexpected: %s" % (actual, expected))
EOF
echo "calendar-fetch: multi-feed merge ok"

python3 - "$FETCH" "$WORK" <<'EOF'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("calendar_fetch", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
work = sys.argv[2]
single = os.path.join(work, "single-url")
open(single, "w").write("https://example.com/a.ics")
assert mod.read_url_file(single) == ["https://example.com/a.ics"], "single-URL file broke"
multi = os.path.join(work, "multi-url")
open(multi, "w").write("https://example.com/a.ics\n\n   \nhttps://example.com/b.ics  \n")
assert mod.read_url_file(multi) == ["https://example.com/a.ics", "https://example.com/b.ics"], "blank lines not skipped"
empty = os.path.join(work, "empty-url")
open(empty, "w").write("\n  \n")
assert mod.read_url_file(empty) == [], "blank-only file should yield no URLs"
EOF
echo "calendar-fetch: url-file parsing ok"

cp "$WORK/actual.json" "$WORK/cache.json"
BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
if TZ=UTC python3 "$FETCH" --backend ical --url-file "$WORK/missing-url" \
    --cache-file "$WORK/cache.json" 2>/dev/null; then
    echo "calendar-fetch: expected a failing poll to exit non-zero" >&2
    exit 1
fi
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on failed poll" >&2; exit 1; }
echo "calendar-fetch: last-good cache ok"

BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
if TZ=UTC python3 "$FETCH" --backend ical --input "$FIXTURE" --input "$WORK/missing-feed.ics" \
    --cache-file "$WORK/cache.json" 2>/dev/null; then
    echo "calendar-fetch: expected a failing multi-feed run to exit non-zero" >&2
    exit 1
fi
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on failed multi-feed run" >&2; exit 1; }
echo "calendar-fetch: multi-feed last-good ok"

printf '%s\n' 'https://127.0.0.1:9/a.ics' '' 'https://127.0.0.1:9/b.ics' > "$WORK/urls"
BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
if TZ=UTC python3 "$FETCH" --backend ical --url-file "$WORK/urls" \
    --cache-file "$WORK/cache.json" 2>/dev/null; then
    echo "calendar-fetch: expected a failing N-feed fetch to exit non-zero" >&2
    exit 1
fi
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on failed N-feed fetch" >&2; exit 1; }
echo "calendar-fetch: N-feed fetch failure ok"

if TZ=UTC python3 "$FETCH" --backend ical --url-file "$WORK/missing-url" \
    --cache-file "$WORK/unused.json" 2>/dev/null; then
    echo "calendar-fetch: expected missing URL file to fail" >&2
    exit 1
fi
echo "calendar-fetch: missing URL file ok"

TZ=UTC python3 "$FETCH" --gcalcli-input "$ROOT/tests/fixtures/calendar-gcalcli.tsv" \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/gcal.json" >/dev/null
python3 - "$WORK/gcal.json" "$ROOT/tests/fixtures/calendar-gcalcli.expected.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
expected = json.load(open(sys.argv[2]))
assert actual == expected, (
    "gcalcli conversion mismatch:\nactual:   %s\nexpected: %s" % (actual, expected))
EOF
echo "calendar-fetch: gcalcli conversion ok"

python3 - "$FETCH" "$WORK" <<'EOF'
import importlib.util, os, stat, sys
spec = importlib.util.spec_from_file_location("calendar_fetch", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
work = sys.argv[2]
assert mod.has_gcalcli_auth(os.path.join(work, "missing-bin"),
                            os.path.join(work, "missing-oauth")) is False, "missing bin must not count as auth"
oauth = os.path.join(work, "fake-oauth")
open(oauth, "w").write("token")
os.chmod(oauth, stat.S_IRUSR | stat.S_IWUSR)
assert mod.has_gcalcli_auth("definitely-not-a-real-binary-xyz",
                            oauth) is False, "missing binary must not count as auth"
stub = os.path.join(work, "probe-bin")
open(stub, "w").write("#!/usr/bin/env bash\nexit 0\n")
os.chmod(stub, 0o755)
assert mod.has_gcalcli_auth(stub, oauth) is True, "stub binary plus oauth must count as auth"
assert mod.has_gcalcli_auth(stub, os.path.join(work, "missing-oauth")) is False, "missing oauth must not count as auth"
rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\tcalendar\ttitle\n2026-09-16\t09:00\t2026-09-16\t09:30\tWork\tStandup\n")
assert rows == [{"start_date": "2026-09-16", "start_time": "09:00",
                 "end_date": "2026-09-16", "end_time": "09:30",
                 "title": "Standup"}], "extra TSV columns broke parsing: %r" % (rows,)
rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\textra\n2026-09-16\t09:00\t2026-09-16\t09:30\tA\tB\n")
assert rows[0]["title"] == "A", "title not in last column broke parsing: %r" % (rows,)
rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n2026-09-16\t09:00\t2026-09-16\t09:30\tA\tB\n")
assert rows[0]["title"] == "A\tB", "embedded tab in title broke parsing: %r" % (rows,)
import io
from contextlib import redirect_stderr
buf = io.StringIO()
with redirect_stderr(buf):
    rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n\t09:00\t2026-09-16\t09:30\tLost\n2026-09-16\t09:00\t2026-09-16\t09:30\tKept\n")
assert [r["title"] for r in rows] == ["Kept"], "empty start_date row not skipped: %r" % (rows,)
assert "missing start_date" in buf.getvalue(), "empty start_date row did not warn"
buf = io.StringIO()
with redirect_stderr(buf):
    rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n\t\t\t\t\n2026-09-16\t09:00\t2026-09-16\t09:30\tKept\n")
assert [r["title"] for r in rows] == ["Kept"], "whitespace-only line broke parsing: %r" % (rows,)
assert "blank gcalcli line" in buf.getvalue(), "whitespace-only line did not warn"
buf = io.StringIO()
with redirect_stderr(buf):
    rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n2026-09-16\t09:00\t2026-09-16\t09:30\tA\n\n2026-09-17\t09:00\t2026-09-17\t09:30\tB\n")
assert [r["title"] for r in rows] == ["A", "B"], "empty middle line broke parsing: %r" % (rows,)
assert "blank gcalcli line: ''" in buf.getvalue(), "empty middle line did not warn"
try:
    mod.parse_gcalcli_tsv("")
    raise SystemExit("empty TSV input should raise")
except ValueError as exc:
    assert "empty gcalcli output" in str(exc), exc
buf = io.StringIO()
with redirect_stderr(buf):
    rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n2026-09-16\t09:00\n")
assert rows[0]["title"] == "(no title)", "short row broke parsing: %r" % (rows,)
assert "short gcalcli row" in buf.getvalue(), "short row did not warn"
rows = mod.parse_gcalcli_tsv("start_date\tstart_time\tend_date\tend_time\ttitle\n2026-09-16\t09:00\t2026-09-16\t09:30\t(No title)\n")
assert rows[0]["title"] == "(no title)", "gcalcli untitled event not normalized: %r" % (rows,)
names = mod.parse_gcalcli_list(" Access  Title\n ------  -----\n  owner  alexizfirdaus@gmail.com\n  owner  Family Room\n  reader  Feiertage in Deutschland\n\n")
assert names == ["Family Room", "Feiertage in Deutschland", "alexizfirdaus@gmail.com"], "list parse broke: %r" % (names,)
assert mod.parse_gcalcli_list(" Access  Title\n ------  -----\n") == [], "empty list should yield no names"
assert mod.parse_gcalcli_list("") == [], "blank list output should yield no names"
buf = io.StringIO()
with redirect_stderr(buf):
    names = mod.parse_gcalcli_list(" Access  Title\n ------  -----\n  owner  Access Group\nGarbageLine\n  reader  Home\n")
assert names == ["Access Group", "Home"], "list parse broke: %r" % (names,)
assert "malformed gcalcli list line" in buf.getvalue(), "malformed list line did not warn"
try:
    mod.fetch_gcalcli("definitely-not-a-real-binary-xyz", [], mod.date(2026, 1, 1), mod.date(2026, 1, 2))
    raise SystemExit("empty calendar list should raise")
except ValueError as exc:
    assert "at least one calendar" in str(exc), exc
EOF
echo "calendar-fetch: gcalcli auth check ok"

printf '#!/usr/bin/env bash\necho "$@" >> "%s/argv-ok"\nfor a in "$@"; do [ "$a" = list ] && { printf " Access  Title\\n ------  -----\\n  owner  Work\\n  owner  Home\\n"; exit 0; }; done\ncal=""; prev=""; for a in "$@"; do [ "$prev" = "--calendar" ] && cal="$a"; prev="$a"; done\nif [ "$cal" = Home ]; then printf "start_date\\tstart_time\\tend_date\\tend_time\\ttitle\\n"; else cat "%s"; fi\n' "$WORK" "$ROOT/tests/fixtures/calendar-gcalcli.tsv" > "$WORK/fake-gcalcli-ok"
chmod 755 "$WORK/fake-gcalcli-ok"
printf '#!/usr/bin/env bash\necho "boom" >&2\nexit 1\n' > "$WORK/fake-gcalcli-fail"
chmod 755 "$WORK/fake-gcalcli-fail"
printf 'token' > "$WORK/oauth"
chmod 600 "$WORK/oauth"

TZ=UTC python3 "$FETCH" --backend auto --gcalcli-bin "$WORK/fake-gcalcli-ok" \
    --gcalcli-oauth "$WORK/oauth" --now "2026-09-16T12:00:00" \
    --cache-file "$WORK/auto.json" >/dev/null
python3 - "$WORK/auto.json" "$ROOT/tests/fixtures/calendar-gcalcli-live.expected.json" <<'EOF'
import json, sys
assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2])), "auto backend did not take the gcalcli path"
EOF
grep -q -- "--tsv" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed --tsv" >&2; exit 1; }
grep -q -- "--nocache" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed --nocache" >&2; exit 1; }
grep -q -- "--details time" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed --details time" >&2; exit 1; }
grep -q -- "--details title" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed --details title" >&2; exit 1; }
grep -q "2024-01-01" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed window start" >&2; exit 1; }
grep -q "2032-12-31" "$WORK/argv-ok" || { echo "calendar-fetch: gcalcli run missed window end" >&2; exit 1; }
echo "calendar-fetch: auto selects gcalcli ok"

: > "$WORK/argv-ok"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-ok" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-calendar "Work" \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/cal.json" >/dev/null
grep -q -- "--calendar Work" "$WORK/argv-ok" || { echo "calendar-fetch: --gcalcli-calendar not forwarded" >&2; exit 1; }
grep -q -- "--calendar Home" "$WORK/argv-ok" && { echo "calendar-fetch: unpinned calendar polled" >&2; exit 1; }
[[ "$(grep -c . "$WORK/argv-ok")" -eq 2 ]] || { echo "calendar-fetch: pin run made extra calls" >&2; exit 1; }
echo "calendar-fetch: gcalcli calendar filter ok"

printf '#!/usr/bin/env bash\necho "$@" >> "%s/argv-multi"\nfor a in "$@"; do [ "$a" = list ] && { printf " Access  Title\\n ------  -----\\n  owner  Work\\n  owner  Home\\n"; exit 0; }; done\ncal=""; prev=""; for a in "$@"; do [ "$prev" = "--calendar" ] && cal="$a"; prev="$a"; done\ncase "$cal" in\n  Work) cat "%s";;\n  Home) cat "%s";;\n  *) echo "unknown calendar $cal" >&2; exit 1;;\nesac\n' "$WORK" "$ROOT/tests/fixtures/calendar-work.tsv" "$ROOT/tests/fixtures/calendar-home.tsv" > "$WORK/fake-gcalcli-multi"
chmod 755 "$WORK/fake-gcalcli-multi"
printf '#!/usr/bin/env bash\necho "$@" >> "%s/argv-dead"\nfor a in "$@"; do [ "$a" = list ] && { printf " Access  Title\\n ------  -----\\n  owner  Work\\n  owner  Family\\n"; exit 0; }; done\ncal=""; prev=""; for a in "$@"; do [ "$prev" = "--calendar" ] && cal="$a"; prev="$a"; done\nif [ "$cal" = Family ]; then echo "HttpError 404 Not Found" >&2; exit 1; fi\ncat "%s"\n' "$WORK" "$ROOT/tests/fixtures/calendar-work.tsv" > "$WORK/fake-gcalcli-dead"
chmod 755 "$WORK/fake-gcalcli-dead"
printf '#!/usr/bin/env bash\necho "$@" >> "%s/argv-empty"\nfor a in "$@"; do [ "$a" = agenda ] && { echo "agenda ran with no calendars" >&2; exit 1; }; done\nprintf " Access  Title\\n ------  -----\\n"\n' "$WORK" > "$WORK/fake-gcalcli-empty"
chmod 755 "$WORK/fake-gcalcli-empty"

TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --now "2026-09-16T12:00:00" \
    --cache-file "$WORK/percal.json" >/dev/null
python3 - "$WORK/percal.json" "$ROOT/tests/fixtures/calendar-per-calendar.expected.json" <<'EOF'
import json, sys
assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2])), "per-calendar merge mismatch"
EOF
grep -q -- "--calendar Work" "$WORK/argv-multi" || { echo "calendar-fetch: Work never polled" >&2; exit 1; }
grep -q -- "--calendar Home" "$WORK/argv-multi" || { echo "calendar-fetch: Home never polled" >&2; exit 1; }
grep -q " list$" "$WORK/argv-multi" || { echo "calendar-fetch: calendar list never fetched" >&2; exit 1; }
grep -q -- "--nocache" "$WORK/argv-multi" || { echo "calendar-fetch: list run missed --nocache" >&2; exit 1; }
cp "$WORK/argv-multi" "$WORK/argv-percal"
echo "calendar-fetch: per-calendar merge ok"

: > "$WORK/argv-multi"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-ignore-calendar Home \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/ignored.json" >/dev/null
python3 - "$WORK/ignored.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["calendars"] == ["Home", "Work"], actual["calendars"]
assert sorted(actual["days"]) == ["2026-09-15", "2026-09-16", "2026-09-22", "2026-09-29"], sorted(actual["days"])
assert all(e["s"] in ("Standup", "Review") for es in actual["days"].values() for e in es), actual["days"]
assert "Trip" not in json.dumps(actual["days"]) and "Alice" not in json.dumps(actual["days"]), actual["days"]
EOF
grep -q -- "--calendar Home" "$WORK/argv-multi" && { echo "calendar-fetch: ignored calendar still polled" >&2; exit 1; }
grep -q -- "--calendar Work" "$WORK/argv-multi" || { echo "calendar-fetch: enabled calendar not polled" >&2; exit 1; }
echo "calendar-fetch: ignore calendar ok"

: > "$WORK/argv-multi"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-ignore-calendar Work \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/ignored-work.json" >/dev/null
python3 - "$WORK/ignored-work.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["calendars"] == ["Home", "Work"], actual["calendars"]
assert "Standup" not in json.dumps(actual["days"]) and "Review" not in json.dumps(actual["days"]), actual["days"]
assert "Trip" in json.dumps(actual["days"]) and "Alice birthday" in json.dumps(actual["days"]), actual["days"]
EOF
grep -q -- "--calendar Work" "$WORK/argv-multi" && { echo "calendar-fetch: ignored Work still polled" >&2; exit 1; }
grep -q -- "--calendar Home" "$WORK/argv-multi" || { echo "calendar-fetch: enabled Home not polled" >&2; exit 1; }
echo "calendar-fetch: ignore work ok"

: > "$WORK/argv-multi"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-ignore-calendar Home --gcalcli-ignore-calendar Work \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/ignored-all.json" >/dev/null
python3 - "$WORK/ignored-all.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["days"] == {}, actual["days"]
assert actual["calendars"] == ["Home", "Work"], actual["calendars"]
EOF
echo "calendar-fetch: ignore all ok"

grep -q -- "--calendar" "$WORK/argv-multi" && { echo "calendar-fetch: ignore-all still polled" >&2; exit 1; }
echo "calendar-fetch: ignore all polls nothing ok"

if grep -v -- "--nocache" "$WORK/argv-percal" | grep -q .; then
    echo "calendar-fetch: gcalcli call without --nocache:" >&2
    grep -v -- "--nocache" "$WORK/argv-percal" >&2
    exit 1
fi
echo "calendar-fetch: every gcalcli call uncached ok"

: > "$WORK/argv-multi"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-calendar Work --gcalcli-calendar Work \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/dedup.json" >/dev/null
[[ "$(grep -c -- '--calendar Work' "$WORK/argv-multi")" -eq 1 ]] || { echo "calendar-fetch: duplicate pin polled twice" >&2; exit 1; }
python3 - "$WORK/dedup.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["days"]["2026-09-16"] == [{"t": "09:00", "s": "Standup"}], actual["days"]["2026-09-16"]
EOF
echo "calendar-fetch: duplicate pin ok"

: > "$WORK/argv-multi"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-multi" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-calendar Work --gcalcli-ignore-calendar Work \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/deny.json" >/dev/null
python3 - "$WORK/deny.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["days"] == {}, actual["days"]
assert actual["calendars"] == ["Home", "Work"], actual["calendars"]
EOF
grep -q -- "--calendar Work" "$WORK/argv-multi" && { echo "calendar-fetch: deny-wins broken" >&2; exit 1; }
echo "calendar-fetch: deny wins ok"

BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-dead" \
    --gcalcli-oauth "$WORK/oauth" --cache-file "$WORK/cache.json" 2>"$WORK/dead.err"
CODE=$?
set -e
[[ $CODE -eq 1 ]] || { echo "calendar-fetch: dead calendar exited $CODE, want 1" >&2; exit 1; }
grep -q "404" "$WORK/dead.err" || { echo "calendar-fetch: dead calendar hid the cause" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on dead calendar" >&2; exit 1; }
echo "calendar-fetch: dead calendar last-good ok"

: > "$WORK/argv-dead"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-dead" \
    --gcalcli-oauth "$WORK/oauth" --gcalcli-ignore-calendar Family \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/ignored-dead.json" >/dev/null
python3 - "$WORK/ignored-dead.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["calendars"] == ["Family", "Work"], actual["calendars"]
assert sorted(actual["days"]) == ["2026-09-15", "2026-09-16", "2026-09-22", "2026-09-29"], sorted(actual["days"])
EOF
grep -q -- "--calendar Family" "$WORK/argv-dead" && { echo "calendar-fetch: ignored dead calendar still polled" >&2; exit 1; }
grep -q -- "--calendar Work" "$WORK/argv-dead" || { echo "calendar-fetch: enabled Work not polled" >&2; exit 1; }
echo "calendar-fetch: ignore dead ok"

: > "$WORK/argv-empty"
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-empty" \
    --gcalcli-oauth "$WORK/oauth" --now "2026-09-16T12:00:00" \
    --cache-file "$WORK/empty-cals.json" >/dev/null
python3 - "$WORK/empty-cals.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual == {"fetchedAt": "2026-09-16T12:00:00+00:00", "days": {}, "calendars": []}, actual
EOF
grep -q "agenda" "$WORK/argv-empty" && { echo "calendar-fetch: agenda ran with no calendars" >&2; exit 1; }
echo "calendar-fetch: empty calendar list ok"

printf 'http://example.com/a.ics\n' > "$WORK/http-url"
head -n 2 "$ROOT/tests/fixtures/calendar-gcalcli.tsv" > "$WORK/g1.tsv"
printf 'start_date\tstart_time\tend_date\tend_time\ttitle\n2026-10-30\t\t2026-11-02\t\tTrip\n' > "$WORK/g2.tsv"
cp "$WORK/actual.json" "$WORK/reject.json"
reject_check() {
    local desc="$1"; local want="$2"; shift 2
    local before after code
    before="$(sha256sum "$WORK/reject.json" | cut -d' ' -f1)"
    set +e
    TZ=UTC python3 "$FETCH" "$@" --cache-file "$WORK/reject.json" 2>"$WORK/reject.err"
    code=$?
    set -e
    [[ $code -eq 2 ]] || { echo "calendar-fetch: $desc exited $code, want 2" >&2; exit 1; }
    grep -q -- "$want" "$WORK/reject.err" \
        || { echo "calendar-fetch: $desc hid the reason: $(cat "$WORK/reject.err")" >&2; exit 1; }
    after="$(sha256sum "$WORK/reject.json" | cut -d' ' -f1)"
    [[ "$before" == "$after" ]] || { echo "calendar-fetch: $desc rewrote the cache" >&2; exit 1; }
    echo "calendar-fetch: $desc ok"
}
reject_check "gcalcli-calendar with ical rejected" "gcalcli-calendar" --backend ical --gcalcli-calendar "Work" --input "$FIXTURE"
reject_check "gcalcli-calendar with input rejected" "gcalcli-calendar" --gcalcli-calendar "Work" --input "$FIXTURE"
reject_check "gcalcli-calendar with fixture rejected" "gcalcli-calendar" --gcalcli-calendar "Work" --gcalcli-input "$WORK/g1.tsv"
reject_check "gcalcli-calendar with auto fallback rejected" "gcalcli-calendar" --backend auto --gcalcli-bin "$WORK/missing-bin" --gcalcli-oauth "$WORK/missing-oauth" --gcalcli-calendar "Work" --url-file "$WORK/missing-url"
reject_check "ignore-calendar with ical rejected" "gcalcli-ignore-calendar" --backend ical --gcalcli-ignore-calendar "Home" --input "$FIXTURE"
reject_check "ignore-calendar with input rejected" "gcalcli-ignore-calendar" --gcalcli-ignore-calendar "Home" --input "$FIXTURE"
reject_check "ignore-calendar with fixture rejected" "gcalcli-ignore-calendar" --gcalcli-ignore-calendar "Home" --gcalcli-input "$WORK/g1.tsv"
reject_check "ignore-calendar with auto fallback rejected" "gcalcli-ignore-calendar" --backend auto --gcalcli-bin "$WORK/missing-bin" --gcalcli-oauth "$WORK/missing-oauth" --gcalcli-ignore-calendar "Home" --url-file "$WORK/missing-url"
reject_check "input plus gcalcli-input rejected" "cannot be combined" --input "$FIXTURE" --gcalcli-input "$WORK/g1.tsv"
reject_check "input with forced gcalcli rejected" "--input needs" --backend gcalcli --input "$FIXTURE"
reject_check "gcalcli-input with forced ical rejected" "--gcalcli-input needs" --backend ical --gcalcli-input "$WORK/g1.tsv"
reject_check "bad now rejected" "cannot parse --now" --now "not-a-date" --input "$FIXTURE"
reject_check "non-https URL rejected" "refusing non-https" --backend ical --url-file "$WORK/http-url"
reject_check "empty URL file rejected" "no URLs in" --backend ical --url-file "$WORK/empty-url"
reject_check "missing input rejected" "cannot read --input" --input "$WORK/missing-feed.ics"
reject_check "forced gcalcli missing bin rejected" "gcalcli backend needs" --backend gcalcli --gcalcli-bin "$WORK/missing-bin" --gcalcli-oauth "$WORK/oauth"
reject_check "forced gcalcli missing PATH bin rejected" "gcalcli backend needs" --backend gcalcli --gcalcli-bin definitely-not-a-real-binary-xyz --gcalcli-oauth "$WORK/oauth"
reject_check "missing URL file rejected" "secret URL file" --backend ical --url-file "$WORK/missing-url"

TZ=UTC python3 "$FETCH" --backend ical --input "$FIXTURE" \
    --gcalcli-bin "$WORK/fake-gcalcli-ok" --gcalcli-oauth "$WORK/oauth" \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/forced-ical.json" >/dev/null
python3 - "$WORK/forced-ical.json" "$EXPECTED" <<'EOF'
import json, sys
assert json.load(open(sys.argv[1])) == json.load(open(sys.argv[2])), "forced ical did not use the URL path"
EOF
echo "calendar-fetch: forced ical ok"

BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/missing-bin" \
    --gcalcli-oauth "$WORK/missing-oauth" \
    --cache-file "$WORK/cache.json" 2>/dev/null
CODE=$?
set -e
[[ $CODE -eq 2 ]] || { echo "calendar-fetch: forced gcalcli without auth exited $CODE, want 2" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on forced gcalcli failure" >&2; exit 1; }
echo "calendar-fetch: forced gcalcli without auth ok"

BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-fail" \
    --gcalcli-oauth "$WORK/oauth" \
    --cache-file "$WORK/cache.json" 2>/dev/null
CODE=$?
set -e
[[ $CODE -eq 1 ]] || { echo "calendar-fetch: failing gcalcli poll exited $CODE, want 1" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on failed gcalcli poll" >&2; exit 1; }
echo "calendar-fetch: gcalcli last-good ok"

printf '#!/usr/bin/env bash\nexit 3\n' > "$WORK/fake-gcalcli-quiet"
chmod 755 "$WORK/fake-gcalcli-quiet"
BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --backend gcalcli --gcalcli-bin "$WORK/fake-gcalcli-quiet" \
    --gcalcli-oauth "$WORK/oauth" \
    --cache-file "$WORK/cache.json" 2>"$WORK/quiet.err"
CODE=$?
set -e
[[ $CODE -eq 1 ]] || { echo "calendar-fetch: quiet gcalcli failure exited $CODE, want 1" >&2; exit 1; }
grep -q "exit 3" "$WORK/quiet.err" || { echo "calendar-fetch: quiet failure hid the exit code" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on quiet gcalcli failure" >&2; exit 1; }
echo "calendar-fetch: gcalcli quiet-failure ok"

BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --gcalcli-input "$WORK/missing.tsv" \
    --cache-file "$WORK/cache.json" 2>/dev/null
CODE=$?
set -e
[[ $CODE -eq 2 ]] || { echo "calendar-fetch: missing --gcalcli-input exited $CODE, want 2" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on missing --gcalcli-input" >&2; exit 1; }
echo "calendar-fetch: gcalcli missing-input ok"

if TZ=UTC python3 "$FETCH" --backend auto --gcalcli-bin "$WORK/missing-bin" \
    --gcalcli-oauth "$WORK/missing-oauth" --url-file "$WORK/missing-url" \
    --cache-file "$WORK/unused2.json" 2>"$WORK/auto-fallback.err"; then
    echo "calendar-fetch: expected auto without auth to fail on the URL file" >&2
    exit 1
fi
grep -q "secret URL file" "$WORK/auto-fallback.err" \
    || { echo "calendar-fetch: auto without auth did not take the URL path" >&2; exit 1; }
echo "calendar-fetch: auto fallback ok"

printf 'start_date\tstart_time\tend_date\tend_time\n2026-09-16\t09:00\t2026-09-16\t09:30\n' > "$WORK/bad.tsv"
BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --gcalcli-input "$WORK/bad.tsv" \
    --cache-file "$WORK/cache.json" 2>/dev/null
CODE=$?
set -e
[[ $CODE -eq 1 ]] || { echo "calendar-fetch: bad TSV exited $CODE, want 1" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on bad TSV" >&2; exit 1; }
echo "calendar-fetch: gcalcli bad-input last-good ok"

: > "$WORK/empty.tsv"
BEFORE="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
set +e
TZ=UTC python3 "$FETCH" --gcalcli-input "$WORK/empty.tsv" \
    --cache-file "$WORK/cache.json" 2>/dev/null
CODE=$?
set -e
[[ $CODE -eq 1 ]] || { echo "calendar-fetch: empty TSV exited $CODE, want 1" >&2; exit 1; }
AFTER="$(sha256sum "$WORK/cache.json" | cut -d' ' -f1)"
[[ "$BEFORE" == "$AFTER" ]] || { echo "calendar-fetch: cache rewritten on empty TSV" >&2; exit 1; }
echo "calendar-fetch: gcalcli empty-input last-good ok"

TZ=UTC python3 "$FETCH" --gcalcli-input "$WORK/g1.tsv" --gcalcli-input "$WORK/g2.tsv" \
    --now "2026-09-16T12:00:00" --cache-file "$WORK/merge.json" >/dev/null
python3 - "$WORK/merge.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert sorted(actual["days"]) == ["2026-09-16", "2026-10-30", "2026-10-31", "2026-11-01"], \
    "gcalcli merge mismatch: %s" % sorted(actual["days"])
assert actual["days"]["2026-09-16"] == [{"t": "09:00", "s": "Standup"}], actual["days"]["2026-09-16"]
assert actual["fetchedAt"] == "2026-09-16T12:00:00+00:00", actual["fetchedAt"]
assert actual["calendars"] == [], actual["calendars"]
EOF
echo "calendar-fetch: gcalcli merge ok"

TZ=UTC python3 "$FETCH" --gcalcli-input "$WORK/g1.tsv" \
    --now "2026-09-16T12:00:00+05:00" --cache-file "$WORK/offset.json" >/dev/null
python3 - "$WORK/offset.json" <<'EOF'
import json, sys
actual = json.load(open(sys.argv[1]))
assert actual["fetchedAt"] == "2026-09-16T07:00:00+00:00", actual["fetchedAt"]
assert actual["calendars"] == [], actual["calendars"]
EOF
echo "calendar-fetch: now offset ok"

echo "calendar-fetch: all ok"
