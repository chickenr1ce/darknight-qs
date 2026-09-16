#!/usr/bin/env python3
r"""Poll Google Calendar and cache it as local JSON for QML.

Two tiers share one cache schema, one poll contract, and one offline rule
(last good wins, cache untouched on failure: fetch failures exit 1,
usage errors exit 2). QML never changes.

Tier 1, default, works minutes after clone. Paste secret iCal URLs:

  1. Google Calendar on the web > Settings for my calendars >
     Integrate calendar > "Secret address in iCal format" > copy the URL.
     Repeat for holidays or other calendars with their own secret
     address. Contacts birthdays has none, so birthdays need Tier 2.
  2. printf '%s\n' '<primary-url>' '<holidays-url>' > "${XDG_STATE_HOME:-~/.local/state}/quickshell/calendar-url"
     chmod 600 <that file>

One URL per non-blank line in the URL file; a file holding a single URL
keeps working unchanged. All feeds merge into one days map QML reads.

Tier 2, opt-in, unlocks the Contacts birthdays calendar. Google issues no
secret iCal address for that auto-generated calendar, so the URL file can
never see it. Install gcalcli, bring your own Cloud project, and
authenticate once; the helper then uses gcalcli instead of the URL file:

  1. Create a Cloud project and enable the Calendar API.
  2. Create an OAuth consent screen (External), add yourself as a test
     user, and create an OAuth client ID of type Desktop app.
  3. gcalcli --client-id=<....apps.googleusercontent.com> list
     Enter the client secret when asked, open the browser link, grant
     access, and confirm the calendar list prints. Note: gcalcli
     requests the full Calendar scope, not readonly — that trust
     decision is yours to make on the consent screen.
  4. Publishing the app (Audience page, Publish) keeps tokens alive
     indefinitely, but Google now requires a homepage plus a privacy
     policy on a domain you own before it lets an external app go
     production. With no website, skip publishing and stay in
     testing mode instead: tokens die every 7 days, and the panel
     tells you via its stale marker. Re-authenticate with the same
     command as step 3, then chmod 600 the refreshed token file;
     the next poll picks up where it left off with the cache intact.

Each user brings their own client ID and secret. This repo ships none:
quota, verification, and calendar-read trust stay with the user. The
OAuth token (usually ~/.local/share/gcalcli/oauth) is a password: keep
it owner-only, never commit it. If a Workspace admin disables the secret
address, use this tier instead. If the gcalcli poll starts failing after
auth expires, either re-authenticate or force the URL path with
--backend ical; deleting the stale token lets auto fall back.

Visibility: the gcalcli path polls each discovered calendar separately
and records every discovered name in the cache beside the days map, so a
settings view can offer toggles. Pass --gcalcli-ignore-calendar to skip
a noisy feed (repeat for more); a name both pinned and ignored is
skipped. Hiding a dead entry also repairs a poll
that entry keeps 404ing. New calendars arrive enabled. The URL-file path
has no names to list and stays all-feeds.

On any failure the cache is left untouched (last good wins: fetch and
conversion failures exit 1, usage errors exit 2).
Each URL line is a bearer token: keep the file owner-only, never commit it.
Rotate via Google's "Reset" control for each secret address, then repeat step 2.
"""

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

time.tzset()

WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
MAX_INSTANCES_PER_EVENT = 2000
FETCH_TIMEOUT_S = 20
GCALCLI_TIMEOUT_S = 60


def default_path(env_var, fallback_tail):
    base = os.environ.get(env_var) or os.path.expanduser(fallback_tail[0])
    return os.path.join(base, *fallback_tail[1:])


def default_url_file():
    return default_path("XDG_STATE_HOME", ("~/.local/state", "quickshell", "calendar-url"))


def default_cache_file():
    return default_path("XDG_CACHE_HOME", ("~/.cache", "quickshell", "calendar-events.json"))


def warn_world_readable(path):
    try:
        if os.stat(path).st_mode & (stat.S_IRGRP | stat.S_IROTH):
            print(f"warning: {path} is readable beyond owner; run chmod 600 {path}",
                  file=sys.stderr)
    except OSError:
        pass


def read_url_file(path):
    with open(path, encoding="utf-8") as handle:
        content = handle.read()
    urls = []
    for line in content.splitlines():
        stripped = line.strip()
        if stripped:
            urls.append(stripped.split()[0])
    return urls


def unfold(text):
    lines, current = [], None
    for raw in text.splitlines():
        if raw[:1] in (" ", "\t") and current is not None:
            current += raw[1:]
        else:
            if current is not None:
                lines.append(current)
            current = raw
    if current is not None:
        lines.append(current)
    return lines


def parse_content_line(line):
    name_params, _, value = line.partition(":")
    parts = name_params.split(";")
    params = {}
    for part in parts[1:]:
        key, _, val = part.partition("=")
        params[key.upper()] = val
    return parts[0].upper(), params, value


def parse_date_value(value):
    return date(int(value[0:4]), int(value[4:6]), int(value[6:8]))


def parse_datetime_value(value):
    return datetime(int(value[0:4]), int(value[4:6]), int(value[6:8]),
                    int(value[9:11]), int(value[11:13]), int(value[13:15]))


def local_tz():
    return datetime.now().astimezone().tzinfo


def parse_dtstart(params, value):
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        day = parse_date_value(value)
        return True, datetime(day.year, day.month, day.day, tzinfo=local_tz())
    moment = parse_datetime_value(value)
    if value.endswith("Z"):
        return False, moment.replace(tzinfo=ZoneInfo("UTC")).astimezone()
    tzid = params.get("TZID")
    if tzid:
        try:
            return False, moment.replace(tzinfo=ZoneInfo(tzid)).astimezone()
        except ZoneInfoNotFoundError:
            print(f"warning: unknown TZID {tzid}; treating as local wall time",
                  file=sys.stderr)
    return False, moment.replace(tzinfo=local_tz())


def parse_dt_or_duration(params, value, start):
    if value.upper().startswith("P"):
        match = re.fullmatch(
            r"P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?",
            value.upper())
        if not match:
            return start
        weeks, days, hours, minutes, seconds = (int(g or 0) for g in match.groups())
        return start + timedelta(weeks=weeks, days=days, hours=hours,
                                 minutes=minutes, seconds=seconds)
    all_day, moment = parse_dtstart(params, value)
    return moment


def parse_list_dtstart(params, value):
    out = []
    for item in value.split(","):
        item = item.strip()
        if not item:
            continue
        if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", item):
            day = parse_date_value(item)
            out.append(datetime(day.year, day.month, day.day, tzinfo=local_tz()))
        elif re.fullmatch(r"\d{8}T\d{6}Z?", item):
            all_day, moment = parse_dtstart(params, item)
            out.append(moment)
    return out


def parse_vevents(ics_text):
    events, current = [], None
    for line in unfold(ics_text):
        name, params, value = parse_content_line(line)
        if name == "BEGIN" and value.upper() == "VEVENT":
            current = {"exdates": [], "rdates": []}
        elif name == "END" and value.upper() == "VEVENT":
            if current and "dtstart" in current:
                events.append(current)
            current = None
        elif current is not None:
            if name == "UID":
                current["uid"] = value
            elif name == "SUMMARY":
                current["summary"] = value.replace("\\,", ",").replace("\\;", ";").replace("\\n", " ")
            elif name == "DTSTART":
                all_day, moment = parse_dtstart(params, value)
                current["all_day"] = all_day
                current["dtstart"] = moment
            elif name == "DTEND":
                current["dtend"] = (params, value)
            elif name == "DURATION":
                current["duration"] = value
            elif name == "RRULE":
                rule = {}
                for part in value.split(";"):
                    key, _, val = part.partition("=")
                    rule[key.upper()] = val
                current["rrule"] = rule
            elif name == "EXDATE":
                current["exdates"].extend(parse_list_dtstart(params, value))
            elif name == "RDATE":
                current["rdates"].extend(parse_list_dtstart(params, value))
            elif name == "RECURRENCE-ID":
                current["recurrence_id"] = True
    return events


def event_end(event):
    start = event["dtstart"]
    if "dtend" in event:
        params, value = event["dtend"]
        return parse_dt_or_duration(params, value, start)
    if "duration" in event:
        return parse_dt_or_duration({}, event["duration"], start)
    if event.get("all_day"):
        return start + timedelta(days=1)
    return start


def span_days(start, end, all_day):
    first = start.date()
    if all_day:
        last = (end - timedelta(seconds=1)).date()
    else:
        last = end.date()
        if end.time() == datetime.min.time() and last > first:
            last -= timedelta(days=1)
    day, out = first, []
    while day <= last:
        out.append(day)
        day += timedelta(days=1)
    return out


def parse_until(rule):
    if "UNTIL" not in rule:
        return None
    raw = rule["UNTIL"]
    if re.fullmatch(r"\d{8}", raw):
        return parse_date_value(raw)
    return parse_dtstart({}, raw)[1].date()


def expand_weekly(start, rule, window_start, window_end):
    interval = int(rule.get("INTERVAL", "1"))
    byday = rule.get("BYDAY")
    wanted = {WEEKDAYS[d] for d in byday.split(",") if d in WEEKDAYS} if byday else {start.weekday()}
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = parse_until(rule)
    monday = start.date() - timedelta(days=start.date().weekday())
    emitted, occurrences = [], 0
    day = monday
    while day <= window_end and len(emitted) < MAX_INSTANCES_PER_EVENT:
        weeks_out = (day - monday).days // 7
        if weeks_out >= 0 and weeks_out % interval == 0 and day.weekday() in wanted and day >= start.date():
            if until and day > until:
                break
            occurrences += 1
            if count is not None and occurrences > count:
                break
            if day >= window_start:
                emitted.append(datetime(day.year, day.month, day.day,
                                        start.hour, start.minute, start.second,
                                        tzinfo=start.tzinfo))
        day += timedelta(days=1)
    return emitted


def expand_monthly(start, rule, window_start, window_end):
    interval = int(rule.get("INTERVAL", "1"))
    if "BYMONTHDAY" in rule:
        monthdays = {int(d) for d in rule["BYMONTHDAY"].split(",") if d.lstrip("-").isdigit()}
    else:
        monthdays = {start.day}
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = parse_until(rule)
    emitted, occurrences = [], 0
    month_index = 0
    base = date(start.year, start.month, 1)
    while len(emitted) < MAX_INSTANCES_PER_EVENT:
        year = base.year + (base.month - 1 + month_index) // 12
        month = (base.month - 1 + month_index) % 12 + 1
        first_of_month = date(year, month, 1)
        if first_of_month > window_end and (until is None or first_of_month > until):
            break
        if month_index % interval == 0:
            for day_no in sorted(monthdays):
                try:
                    day = date(year, month, day_no)
                except ValueError:
                    continue
                if day < start.date():
                    continue
                if until and day > until:
                    return emitted
                if day > window_end:
                    return emitted
                occurrences += 1
                if count is not None and occurrences > count:
                    return emitted
                if day >= window_start:
                    emitted.append(datetime(day.year, day.month, day.day,
                                            start.hour, start.minute, start.second,
                                            tzinfo=start.tzinfo))
        month_index += 1
        if month_index > 1200:
            break
    return emitted


def expand_event(event, window_start, window_end):
    start = event["dtstart"]
    rule = event.get("rrule")
    if not rule:
        return [start]
    freq = rule.get("FREQ", "").upper()
    if freq == "DAILY":
        interval = int(rule.get("INTERVAL", "1"))
        count = int(rule["COUNT"]) if "COUNT" in rule else None
        until = parse_until(rule)
        emitted, occurrences, day = [], 0, start.date()
        while day <= window_end and len(emitted) < MAX_INSTANCES_PER_EVENT:
            if (day - start.date()).days % interval == 0:
                if until and day > until:
                    break
                occurrences += 1
                if count is not None and occurrences > count:
                    break
                if day >= window_start:
                    emitted.append(datetime(day.year, day.month, day.day,
                                            start.hour, start.minute, start.second,
                                            tzinfo=start.tzinfo))
            day += timedelta(days=1)
        return emitted
    if freq == "WEEKLY":
        return expand_weekly(start, rule, window_start, window_end)
    if freq == "MONTHLY":
        return expand_monthly(start, rule, window_start, window_end)
    if freq == "YEARLY":
        interval = int(rule.get("INTERVAL", "1"))
        count = int(rule["COUNT"]) if "COUNT" in rule else None
        until = parse_until(rule)
        emitted, occurrences, year = [], 0, start.year
        while len(emitted) < MAX_INSTANCES_PER_EVENT:
            if (year - start.year) % interval == 0:
                try:
                    day = date(year, start.month, start.day)
                except ValueError:
                    year += 1
                    continue
                if day >= start.date():
                    if until and day > until:
                        break
                    if day > window_end:
                        break
                    occurrences += 1
                    if count is not None and occurrences > count:
                        break
                    if day >= window_start:
                        emitted.append(datetime(day.year, day.month, day.day,
                                                start.hour, start.minute, start.second,
                                                tzinfo=start.tzinfo))
            year += 1
            if year > window_end.year + 1:
                break
        return emitted
    print(f"warning: unsupported RRULE FREQ={freq or '?'}; keeping first instance only",
          file=sys.stderr)
    return [start]


def convert(ics_text, now):
    window_start, window_end = poll_window(now)
    days = {}
    for event in parse_vevents(ics_text):
        if event.get("recurrence_id"):
            continue
        title = event.get("summary", "(no title)").strip()
        if title in ("", "(No title)"):
            title = "(no title)"
        all_day = event.get("all_day", False)
        start = event["dtstart"]
        duration = event_end(event) - start
        excluded = {moment.date() for moment in event["exdates"]}
        instances = [dt for dt in expand_event(event, window_start, window_end)
                     if dt.date() not in excluded]
        for extra in event["rdates"]:
            if window_start <= extra.date() <= window_end and extra.date() not in excluded:
                instances.append(extra)
        for instance in instances:
            end = instance + duration
            touched = span_days(instance, end, all_day)
            for day in touched:
                if day < window_start or day > window_end:
                    continue
                iso = day.isoformat()
                if day == instance.date():
                    entry = {"t": "" if all_day else instance.strftime("%H:%M"), "s": title}
                else:
                    entry = {"t": "", "s": title}
                days.setdefault(iso, []).append(entry)
    for entries in days.values():
        entries.sort(key=lambda e: ("1" if e["t"] else "0", e["t"], e["s"]))
    return {"fetchedAt": now.isoformat(timespec="seconds"),
            "days": {iso: days[iso] for iso in sorted(days)}}


def fetch_ics(url):
    request = urllib.request.Request(url, headers={"User-Agent": "quickshell-calendar-fetch/1"})
    with urllib.request.urlopen(request, timeout=FETCH_TIMEOUT_S) as response:
        return response.read().decode("utf-8", errors="replace")


def gcalcli_oauth_candidates(oauth_override=None):
    if oauth_override:
        return [oauth_override]
    candidates = []
    explicit = os.environ.get("GCALCLI_CONFIG")
    if explicit:
        base = os.path.expanduser(explicit)
        if base.endswith(".toml") or os.path.isfile(base):
            candidates.append(os.path.join(os.path.dirname(base), "oauth"))
        else:
            candidates.append(os.path.join(base, "oauth"))
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    candidates.append(os.path.join(data_home, "gcalcli", "oauth"))
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    candidates.append(os.path.join(config_home, "gcalcli", "oauth"))
    candidates.append(os.path.expanduser("~/.gcalcli_oauth"))
    return candidates


def find_gcalcli_oauth(oauth_override=None):
    for candidate in gcalcli_oauth_candidates(oauth_override):
        try:
            if os.path.isfile(candidate):
                return candidate
        except OSError:
            continue
    return None


def has_gcalcli_auth(gcalcli_bin, oauth_override=None):
    if "/" in gcalcli_bin:
        if not (os.path.isfile(gcalcli_bin) and os.access(gcalcli_bin, os.X_OK)):
            return False
    elif shutil.which(gcalcli_bin) is None:
        return False
    return find_gcalcli_oauth(oauth_override) is not None


def parse_gcalcli_tsv(text):
    rows = []
    lines = [line for line in text.splitlines() if line.strip() != ""]
    dropped = [line for line in text.splitlines() if line.strip() == ""]
    for line in dropped:
        print(f"warning: skipping blank gcalcli line: {line!r}", file=sys.stderr)
    if not lines:
        raise ValueError("empty gcalcli output")
    header = lines[0].split("\t")
    index = {name: pos for pos, name in enumerate(header)}
    for want in ("start_date", "start_time", "end_date", "end_time", "title"):
        if want not in index:
            raise ValueError(f"gcalcli TSV is missing column {want!r}")
    title_pos = index["title"]
    title_last = title_pos == len(header) - 1
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) < len(header):
            print(f"warning: short gcalcli row, padding with blanks: {line!r}", file=sys.stderr)
            fields += [""] * (len(header) - len(fields))
        get = lambda name: fields[index[name]].strip() if index[name] < len(fields) else ""
        if title_last and len(fields) > title_pos:
            title = "\t".join(fields[title_pos:]).strip()
        else:
            title = get("title")
        title = title.replace("\\n", " ").strip()
        if title in ("", "(No title)"):
            title = "(no title)"
        if not get("start_date"):
            print(f"warning: skipping gcalcli row with missing start_date: {line!r}", file=sys.stderr)
            continue
        rows.append({
            "start_date": get("start_date"),
            "start_time": get("start_time"),
            "end_date": get("end_date") or get("start_date"),
            "end_time": get("end_time"),
            "title": title,
        })
    return rows


def parse_gcalcli_list(text):
    names = set()
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or set(stripped) <= set("- "):
            continue
        fields = stripped.split(None, 1)
        if fields == ["Access", "Title"]:
            continue
        if len(fields) != 2:
            print(f"warning: skipping malformed gcalcli list line: {line!r}", file=sys.stderr)
            continue
        title = fields[1].strip()
        if title:
            names.add(title)
    return sorted(names)


def parse_hhmm(value):
    for fmt in ("%H:%M", "%H:%M:%S"):
        try:
            return datetime.strptime(value, fmt).time()
        except ValueError:
            continue
    raise ValueError(f"bad time {value!r}")


def gcalcli_row_bounds(row):
    start_day = date.fromisoformat(row["start_date"])
    end_day = date.fromisoformat(row["end_date"])
    all_day = row["start_time"] == "" and row["end_time"] == ""
    if all_day:
        start = datetime(start_day.year, start_day.month, start_day.day, tzinfo=local_tz())
        end = datetime(end_day.year, end_day.month, end_day.day, tzinfo=local_tz())
        if end <= start:
            end = start + timedelta(days=1)
        return all_day, start, end
    start_time = parse_hhmm(row["start_time"])
    start = datetime(start_day.year, start_day.month, start_day.day,
                     start_time.hour, start_time.minute, start_time.second,
                     tzinfo=local_tz())
    if row["end_time"]:
        end_time = parse_hhmm(row["end_time"])
        end = datetime(end_day.year, end_day.month, end_day.day,
                       end_time.hour, end_time.minute, end_time.second,
                       tzinfo=local_tz())
    else:
        end = start
    if end < start:
        end = start
    return all_day, start, end


def convert_gcalcli(tsv_text, now):
    window_start, window_end = poll_window(now)
    days = {}
    for row in parse_gcalcli_tsv(tsv_text):
        try:
            all_day, start, end = gcalcli_row_bounds(row)
        except ValueError:
            print(f"warning: skipping gcalcli row with bad date/time: {row!r}", file=sys.stderr)
            continue
        if all_day:
            day = start.date()
            touched = []
            while day < end.date():
                touched.append(day)
                day += timedelta(days=1)
        else:
            touched = span_days(start, end, False)
        for day in touched:
            if day < window_start or day > window_end:
                continue
            iso = day.isoformat()
            if day == start.date() and not all_day:
                entry = {"t": start.strftime("%H:%M"), "s": row["title"]}
            else:
                entry = {"t": "", "s": row["title"]}
            days.setdefault(iso, []).append(entry)
    for entries in days.values():
        entries.sort(key=lambda e: ("1" if e["t"] else "0", e["t"], e["s"]))
    return {"fetchedAt": now.isoformat(timespec="seconds"),
            "days": {iso: days[iso] for iso in sorted(days)}}


def run_gcalcli(gcalcli_bin, subcommand, what):
    try:
        completed = subprocess.run(subcommand, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, timeout=GCALCLI_TIMEOUT_S,
                                   text=True, encoding="utf-8", errors="replace",
                                   check=False)
    except OSError as exc:
        raise RuntimeError(f"cannot run {gcalcli_bin}: {exc}") from exc
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"gcalcli {what} timed out: {exc}") from exc
    if completed.returncode != 0:
        detail = (completed.stderr or "").strip().splitlines()
        raise RuntimeError(f"gcalcli {what} failed: {detail[0] if detail else f'exit {completed.returncode}'}")
    return completed.stdout


def fetch_gcalcli(gcalcli_bin, calendars, window_start, window_end):
    if not calendars:
        raise ValueError("fetch_gcalcli needs at least one calendar")
    command = [gcalcli_bin, "--nocache", "--nocolor", "agenda",
               window_start.isoformat(), window_end.isoformat(),
               "--tsv", "--details", "time", "--details", "title"]
    for name in calendars:
        command += ["--calendar", name]
    return run_gcalcli(gcalcli_bin, command, "agenda")


def fetch_gcalcli_list(gcalcli_bin):
    return parse_gcalcli_list(run_gcalcli(gcalcli_bin, [gcalcli_bin, "--nocache", "--nocolor", "list"], "list"))


def write_cache(cache_file, payload):
    parent = os.path.dirname(cache_file)
    if parent:
        os.makedirs(parent, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=parent or ".", prefix=".calendar-events-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        os.replace(tmp_name, cache_file)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def run_ical_backend(args, now):
    if args.input:
        ics_texts = []
        for input_path in args.input:
            try:
                with open(input_path, encoding="utf-8") as handle:
                    ics_texts.append(handle.read())
            except OSError as exc:
                print(f"error: cannot read --input: {exc}", file=sys.stderr)
                return 2
    else:
        try:
            urls = read_url_file(args.url_file)
        except OSError as exc:
            print(f"error: cannot read secret URL file {args.url_file}: {exc}", file=sys.stderr)
            return 2
        if not urls:
            print(f"error: no URLs in secret URL file {args.url_file}", file=sys.stderr)
            return 2
        for url in urls:
            if not url.startswith("https://"):
                print(f"error: refusing non-https URL in {args.url_file}", file=sys.stderr)
                return 2
        warn_world_readable(args.url_file)
        try:
            ics_texts = [fetch_ics(url) for url in urls]
        except Exception as exc:
            print(f"error: fetch failed, keeping last good cache: {exc}", file=sys.stderr)
            return 1

    try:
        parts = [convert(ics_text, now) for ics_text in ics_texts]
        return merge_and_write(parts, now, args.cache_file, [])
    except Exception as exc:
        print(f"error: conversion failed, keeping last good cache: {exc}", file=sys.stderr)
        return 1


def poll_window(now):
    return date(now.year - 2, 1, 1), date(now.year + 6, 12, 31)


def merge_and_write(parts, now, cache_file, calendars):
    merged = {}
    for part in parts:
        for iso, entries in part["days"].items():
            merged.setdefault(iso, []).extend(entries)
    for entries in merged.values():
        entries.sort(key=lambda e: ("1" if e["t"] else "0", e["t"], e["s"]))
    payload = {"fetchedAt": now.isoformat(timespec="seconds"),
               "days": {iso: merged[iso] for iso in sorted(merged)},
               "calendars": sorted(calendars)}
    write_cache(cache_file, payload)
    print(f"cached {len(payload['days'])} days with events to {cache_file}")
    return 0


def run_gcalcli_backend(args, now):
    window_start, window_end = poll_window(now)
    discovered = []
    if args.gcalcli_input:
        tsv_texts = []
        for input_path in args.gcalcli_input:
            try:
                with open(input_path, encoding="utf-8") as handle:
                    tsv_texts.append(handle.read())
            except OSError as exc:
                print(f"error: cannot read --gcalcli-input: {exc}", file=sys.stderr)
                return 2
    else:
        oauth_path = find_gcalcli_oauth(args.gcalcli_oauth)
        if oauth_path is None:
            print("error: gcalcli backend needs authentication; run the Tier 2 setup first", file=sys.stderr)
            return 2
        if "/" in args.gcalcli_bin:
            if not (os.path.isfile(args.gcalcli_bin) and os.access(args.gcalcli_bin, os.X_OK)):
                print(f"error: gcalcli backend needs {args.gcalcli_bin} installed", file=sys.stderr)
                return 2
        elif shutil.which(args.gcalcli_bin) is None:
            print(f"error: gcalcli backend needs {args.gcalcli_bin} installed", file=sys.stderr)
            return 2
        warn_world_readable(oauth_path)
        try:
            discovered = fetch_gcalcli_list(args.gcalcli_bin)
            candidates = args.gcalcli_calendar if args.gcalcli_calendar else discovered
            ignored = set(args.gcalcli_ignore_calendar)
            enabled = list(dict.fromkeys(name for name in candidates if name not in ignored))
            tsv_texts = [fetch_gcalcli(args.gcalcli_bin, [name],
                                       window_start, window_end)
                         for name in enabled]
        except Exception as exc:
            print(f"error: gcalcli fetch failed, keeping last good cache: {exc}", file=sys.stderr)
            return 1

    try:
        parts = [convert_gcalcli(tsv_text, now) for tsv_text in tsv_texts]
        return merge_and_write(parts, now, args.cache_file, discovered)
    except Exception as exc:
        print(f"error: conversion failed, keeping last good cache: {exc}", file=sys.stderr)
        return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description="Fetch Google Calendar into local JSON cache.")
    parser.add_argument("--url-file", default=default_url_file())
    parser.add_argument("--cache-file", default=default_cache_file())
    parser.add_argument("--input", action="append", default=None,
                        help="read ICS from a file instead of the network (tests, offline re-expand); repeat for multiple feeds")
    parser.add_argument("--backend", choices=("auto", "ical", "gcalcli"), default="auto",
                        help="ical forces the secret-URL path, gcalcli forces the gcalcli path, auto uses gcalcli when authenticated else the URL file")
    parser.add_argument("--gcalcli-bin", default="gcalcli")
    parser.add_argument("--gcalcli-calendar", action="append", default=[],
                        help="restrict the gcalcli path to a calendar name; repeat for more (default: all calendars; rejected with --backend ical, with --input, without gcalcli auth, or with --gcalcli-input)")
    parser.add_argument("--gcalcli-ignore-calendar", action="append", default=[],
                        help="skip a calendar name on the gcalcli path; repeat for more (a name both pinned and ignored is skipped; rejected with --backend ical, with --input, without gcalcli auth, or with --gcalcli-input)")
    parser.add_argument("--gcalcli-input", action="append", default=None,
                        help="read gcalcli agenda --tsv from a file instead of running gcalcli (tests); repeat to merge")
    parser.add_argument("--gcalcli-oauth", default=None,
                        help="override the OAuth token path used for the gcalcli auth check (tests)")
    parser.add_argument("--now", help="pin fetch time as local ISO (deterministic tests)")
    args = parser.parse_args(argv)

    try:
        if args.now:
            parsed = datetime.fromisoformat(args.now)
            now = (parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=local_tz())).astimezone()
        else:
            now = datetime.now().astimezone()
    except ValueError:
        print(f"error: cannot parse --now {args.now!r}", file=sys.stderr)
        return 2

    if args.input and args.gcalcli_input:
        print("error: --input and --gcalcli-input cannot be combined", file=sys.stderr)
        return 2
    if args.input and args.backend == "gcalcli":
        print("error: --input needs --backend ical or auto", file=sys.stderr)
        return 2
    if args.gcalcli_input and args.backend == "ical":
        print("error: --gcalcli-input needs --backend gcalcli or auto", file=sys.stderr)
        return 2
    gcalcli_only = ((args.gcalcli_calendar, "--gcalcli-calendar"),
                    (args.gcalcli_ignore_calendar, "--gcalcli-ignore-calendar"))
    for value, name in gcalcli_only:
        if value and args.gcalcli_input:
            print(f"error: {name} has no effect with --gcalcli-input fixture data", file=sys.stderr)
            return 2

    if args.backend == "ical":
        use_gcalcli = False
    elif args.backend == "gcalcli":
        use_gcalcli = True
    elif args.gcalcli_input:
        use_gcalcli = True
    elif args.input:
        use_gcalcli = False
    else:
        use_gcalcli = has_gcalcli_auth(args.gcalcli_bin, args.gcalcli_oauth)

    for value, name in gcalcli_only:
        if value and not use_gcalcli:
            print(f"error: {name} needs the gcalcli path (--backend gcalcli or auto with authentication)", file=sys.stderr)
            return 2

    if use_gcalcli:
        return run_gcalcli_backend(args, now)
    return run_ical_backend(args, now)


if __name__ == "__main__":
    sys.exit(main())
