# Shell scripts

Conventions for the shell scripts under `scripts/`. `scripts/lint-shell.sh`
(shellcheck at warning severity) covers the mechanical rules; this file covers
the judgement calls it cannot check. Read it before writing or reviewing a
change to a `scripts/*.sh` file.

## Shebang and dialect

A `#!/bin/sh` script stays POSIX: no `[[ ]]`, `local`, `mapfile`, arrays, or
`pipefail`. The test and lint scripts are `#!/usr/bin/env bash` and may use them.

## Errors and output

`die "message"` writes `script: message` to stderr and exits 1; fail loudly and
early. `say "message"` writes progress to stderr, so a command's stdout stays
machine-readable. Results a caller parses go to stdout, one per line.

## Untrusted text

Strip control characters from any name, URL, or tool error that came from
outside the script before printing it, so an escape sequence cannot reach the
terminal. `safe` removes every control character for a single line; `safe_lines`
keeps newlines so a block listing holds its shape.

## Validate before you write

Resolve and check every argument first, then mutate. One bad argument leaves the
target unchanged. A batch verb refuses the whole batch on the first problem
rather than half-applying it.

## Symlinks and paths

Refuse a symlinked source, destination, or any directory a write or delete
traverses. A destructive verb takes a slug: exactly one plain path segment,
lowercased, with no `/`, no `..`, no leading dot, and characters limited to
`a-z0-9._+-`. That makes the path it names the only path it can touch. Delete
only a plain file directly under the intended directory, never with `rm -r`.

## Options and operands

Long options are `--name value`. `--` ends option parsing, so an operand that
begins with `-` is reachable (`qs-theme remove-background -- -wall.png`). An
unknown `--option` is an error, not an operand.

## The theme-root seam

`qs-theme` writes the theme root itself for `install`, `remove`, and the
background verbs; the running shell owns the catalog, the selection, and the
applied background. After a theme-root write, ping the shell best-effort
(`quickshell ipc call theme refresh >/dev/null 2>&1 || true`) so it rescans
without a restart. The write still succeeds when the shell is down.

## Tests

Every `scripts/*.sh` change gets a headless `scripts/test-*.sh` check wired into
`scripts/check.sh`. The check runs offline: clone a local fixture repository
instead of reaching the network, and put a stub `quickshell` on `PATH` instead
of contacting the running shell.

The gate runs from a git hook, where git exports `GIT_DIR`, `GIT_WORK_TREE`, and
`GIT_INDEX_FILE`. A check that runs `git -C <tempdir> ...` must clear those
first or it retargets this repository; `scripts/check.sh` unsets them at the top,
so run a new git-using check through the gate rather than on its own.
