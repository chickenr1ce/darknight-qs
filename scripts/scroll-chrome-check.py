#!/usr/bin/env python3
# Per-view scroll-chrome gate (ticket 09, hardened 2026-10-09).
#
# The original gate was per-file: any file holding one inert view was skipped
# entirely, and one attached ScrollBar excused every view in the file. This
# scans each Flickable/ListView/GridView/ScrollView declaration on its own:
#   * a view with `interactive: false` in its own block is skipped (the toast
#     stack is deliberately inert);
#   * every other view needs an id, a shared ScrollBar attached in its own
#     block, and a SmoothWheel in the same file whose `flickable:` names it.
#
# Usage: scroll-chrome-check.py ROOT
import os
import re
import sys

DECL_RE = re.compile(r"^\s*(Flickable|ListView|GridView|ScrollView)\s*\{")
ID_RE = re.compile(r"^\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
INTERACTIVE_FALSE_RE = re.compile(r"\binteractive:\s*false\b")
SCROLLBAR_RE = re.compile(r"Controls\.ScrollBar\.vertical:\s*ScrollBar")
FLICKABLE_RE = re.compile(r"^\s*flickable:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")


def sanitize(line):
    """Drop string bodies and `//` comments so brace counting is safe."""
    out = []
    i = 0
    quote = None
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in ('"', "'"):
            quote = c
            i += 1
            continue
        if c == "/" and i + 1 < len(line) and line[i + 1] == "/":
            break
        out.append(c)
        i += 1
    return "".join(out)


def block_end(lines, start):
    depth = 0
    for k in range(start, len(lines)):
        clean = sanitize(lines[k])
        depth += clean.count("{") - clean.count("}")
        if k > start and depth <= 0:
            return k
    return len(lines) - 1


def check_file(path):
    """Return a list of violation strings for one QML file."""
    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
    # SmoothWheel targets available anywhere in the file.
    targets = set()
    for line in lines:
        m = FLICKABLE_RE.match(line)
        if m:
            targets.add(m.group(1))

    problems = []
    for k, line in enumerate(lines):
        m = DECL_RE.match(line)
        if not m:
            continue
        end = block_end(lines, k)
        block = lines[k:end + 1]
        body = "\n".join(block)
        if INTERACTIVE_FALSE_RE.search(body):
            continue
        view_id = None
        for bl in block:
            im = ID_RE.match(bl)
            if im:
                view_id = im.group(1)
                break
        label = "%s:%d" % (os.path.basename(path), k + 1)
        if view_id is None:
            problems.append("%s (%s) scrolls but has no id" % (label, m.group(1)))
            continue
        if not SCROLLBAR_RE.search(body):
            problems.append("%s [%s] scrolls but does not attach the shared ScrollBar" % (label, view_id))
        if view_id not in targets:
            problems.append("%s [%s] scrolls but no SmoothWheel targets it" % (label, view_id))
    return problems


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: scroll-chrome-check.py ROOT\n")
        return 2
    root = sys.argv[1]
    qml = []
    found_decl = False
    for sub in ("windows", "components"):
        d = os.path.join(root, sub)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".qml"):
                continue
            path = os.path.join(d, name)
            with open(path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if DECL_RE.match(line):
                        found_decl = True
                        break
            qml.append(path)

    if not found_decl:
        sys.stderr.write("scroll-chrome-check: found no scrollable views; the scan is broken\n")
        return 1

    problems = []
    for path in qml:
        problems.extend(check_file(path))
    if problems:
        for p in problems:
            sys.stderr.write("scroll-chrome-check: %s\n" % p)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
