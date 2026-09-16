#!/usr/bin/env python3
import argparse
import sys
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def local_tz():
    return datetime.now().astimezone().tzinfo


def main(argv=None):
    parser = argparse.ArgumentParser(description="Format current HH:MM per zone.")
    parser.add_argument("zones", nargs="*")
    parser.add_argument("--now", help="pin now as ISO (deterministic tests)")
    args = parser.parse_args(argv)

    if args.now:
        try:
            pinned = datetime.fromisoformat(args.now)
        except ValueError:
            print(f"error: cannot parse --now {args.now!r}", file=sys.stderr)
            return 2
        now = pinned if pinned.tzinfo is not None else pinned.replace(tzinfo=local_tz())
    else:
        now = datetime.now().astimezone()

    for zone in args.zones:
        try:
            zoned = now.astimezone(ZoneInfo(zone))
            diff = round((zoned.utcoffset() - now.utcoffset()).total_seconds() / 60)
            print(f"{zone}=" + zoned.strftime("%H:%M") + f" {diff:+d}")
        except (ZoneInfoNotFoundError, ValueError):
            print(f"{zone}=")
    return 0


if __name__ == "__main__":
    sys.exit(main())
