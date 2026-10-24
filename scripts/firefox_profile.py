#!/usr/bin/env python3
"""Resolve Firefox's default profile directory from its ini files.

installs.ini names the default profile and profiles.ini supplies IsRelative or
an absolute Path. Read-only: nothing is written. scripts/render-theme.sh
imports this module and scripts/wire-themed-apps.sh runs it, so both callers
share one discovery step instead of two mirrored copies.

As a command it prints the resolved absolute profile directory and exits 0, or
prints nothing and exits 1 when no profile resolves.
"""

from __future__ import annotations

import os
import re
import sys

INSTALL_SECTION = re.compile(r"^(?:Install)?[0-9A-Fa-f]+$")


def parse_ini_text(text):
    """Ordered (section, key/value dict) pairs from INI text."""
    entries = []
    section = None
    values = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped[0] in "#;":
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            if section is not None:
                entries.append((section, values))
            section = stripped[1:-1].strip()
            values = {}
            continue
        if section is None or "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        values[key.strip()] = value.strip()
    if section is not None:
        entries.append((section, values))
    return entries


def parse_ini(path):
    """Ordered (section, key/value dict) pairs; a missing file yields none."""
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return []
    return parse_ini_text(text)


def firefox_root():
    config_home = os.environ.get("XDG_CONFIG_HOME", "")
    if not config_home:
        config_home = os.path.join(os.environ.get("HOME", ""), ".config")
    candidate = os.path.join(config_home, "mozilla", "firefox")
    if os.path.isdir(candidate):
        return candidate
    return os.path.join(os.environ.get("HOME", ""), ".mozilla", "firefox")


def firefox_profile():
    """The default profile directory, or None. installs.ini names it; a
    profiles.ini entry, matched by the exact Path name, supplies IsRelative or
    an absolute Path. The symlinked profile path is never resolved, so a psd
    target under /run stays writable."""
    root = firefox_root()
    default_name = None
    install_sections = [
        (section, values)
        for section, values in parse_ini(os.path.join(root, "installs.ini"))
        if INSTALL_SECTION.match(section)]
    winner = None
    for section, values in install_sections:
        if values.get("Default"):
            winner = (section, values)
            break
    if len(install_sections) > 1 and winner is not None:
        sys.stderr.write(
            "firefox: multiple install sections; using %s\n" % winner[0])
    if winner is None:
        return None
    default_name = winner[1]["Default"]
    profile = os.path.join(root, default_name)
    for section, values in parse_ini(os.path.join(root, "profiles.ini")):
        if not section.startswith("Profile"):
            continue
        path = values.get("Path", "")
        if path != default_name and os.path.basename(path) != default_name:
            continue
        profile = path if values.get("IsRelative") == "0" else os.path.join(root, path)
        break
    if not os.path.isdir(profile):
        return None
    return profile


def main():
    profile = firefox_profile()
    if profile is None:
        return 1
    sys.stdout.write(profile + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
