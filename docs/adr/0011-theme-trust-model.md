# ADR 0011: a theme is untrusted input read through one narrow, uniform door

Date: 2026-09-30. Feature: theme-switch.

## Context

A theme is a directory of files that arrive from a git URL the user pastes. The
user raised the case of a malicious repository. Unlike omarchy, this design never
executes a theme: it reads `colors.toml` as color data, so there is no
code-execution path from a theme to the machine. What remains is file handling:
a symlinked `colors.toml` pointing outside the theme, a theme directory that is
itself a symlink, an oversized file, a repo that recurses into submodules or
pulls LFS, and an install that path-traverses.

Omarchy's own answer is tiered: a theme with a `.git` directory is treated as
repo-sourced, and for those it refuses to stage `.lua`, terminal configs,
`vscode.json`, and every symlink, while a theme the user authored is trusted.

## Decision

Trust is uniform and read-only, with no tiers.

- The loader reads exactly two kinds of thing: `colors.toml`, a regular file of
  at most 256 KB that is not a symlink, and images under `backgrounds/` that are
  regular files, of allowed extensions, at most 32 MB each, not symlinks, not in
  nested directories.
- Everything else in a theme directory is ignored. Nothing is executed.
- The rules apply to every theme, whether fetched from a repo or written by hand.
  There is no trusted tier to misjudge.
- `qs-theme install` clones with `--depth 1 --no-recurse-submodules`, LFS smudge
  disabled, into a temporary directory, validates the theme name as a slug, and
  moves it into the root atomically. It refuses symlinked entries and never
  removes a path other than `<theme root>/<validated slug>`.

## Alternatives considered

- **Trust tiers, mirroring omarchy.** More power for hand-authored themes, but it
  reintroduces the branch that has to be right every time, and no feature needs
  the extra files yet. Rejected until a concrete case asks for it.
- **A manifest or signature on themes.** Real supply-chain work with no second
  consumer yet. Rejected as more than the job needs.
- **Fetch the whole theme and read freely.** Widens the surface to every file in
  a stranger's directory for no present benefit.
- **GitHub tarball plus extraction instead of clone.** Avoids git, but tar
  extraction is the classic traversal-and-symlink trap and needs careful code to
  be as safe as a plain clone.

## Consequences and known limits

- The shell decodes background thumbnails, so Qt's image plugins are a code path
  over untrusted data. The size cap and extension allowlist bound it; this is a
  deliberate accepted risk.
- A theme that needs a file this model ignores (an icon theme, a config snippet)
  will not work without a new decision, which is the intended friction.
- Symlinked theme directories are invisible to the catalog, which also means a
  user cannot point the catalog at a working copy by symlinking it in.

## Amendments

- 2026-10-02 (theme-switch `#08`): the background size cap is 32 MB, not 8 MB.
  The 8 MB value predated real themes; every background an omarchy theme ships is
  10 MB to 15 MB, so the guard skipped all of them and the picker came up empty.
  32 MB covers the shipped set with headroom. The extension allowlist, the
  symlink and nested-directory rules, and the 256 KB `colors.toml` cap are
  unchanged.
- 2026-10-02 (theme-switch `#10`, merge review follow-up):
  - The theme name restored from the state file is validated with the same rule
    as the catalog scan before it becomes a path, and once the catalog is ready
    `ThemeService` refuses to build a path for a name it does not list. The
    invariant that the loader reads only under the theme root now holds at the
    state entry point as well as the catalog and CLI entry points.
  - The `stat` type-and-size check and the `FileView` read are separate steps, so
    replacing `colors.toml` with a symlink to a larger file between them can slip
    past the 256 KB cap. The window needs write access to the same user's theme
    root, and the read is still decoded as color data with no code path, so this
    is an accepted limit rather than a bounded-reader rewrite.
  - An eight-digit palette value is `#rrggbbaa` for the two Hyprland border
    roles, which `scripts/render-theme.sh` consumes, but `#aarrggbb` for QML.
    Required roles and the colour aliases are therefore restricted to opaque
    `#rgb` or `#rrggbb`; only `hyprland_active_border` and
    `hyprland_inactive_border` keep the eight-digit form. The renderer expands a
    three-digit `#rgb` to six digits for the raw kitty tokens, so a compact theme
    cannot hand kitty a value it would parse differently.
- 2026-10-03 (theme-switch merge review follow-up): before the catalog scan
  finishes, `ThemeService` still builds a path for the restored theme name. The
  name is already validated as one plain slug, so it cannot traverse, and the
  read stays under the theme root; once the catalog is ready
  `reconcileActiveTheme` drops a name it does not list. Reading the restored
  palette before the scan lands keeps the bar from waiting on the scan, so this
  brief window is accepted rather than gating every read on `catalogReady`.
- 2026-10-03 (theme-switch follow-up): the read set gains one empty file, the
  `light.mode` marker beside `colors.toml`. Omarchy resolves mode from it before
  falling back to the background's luminance, and the catalog scan must agree
  with the parser. It carries no data, is not a symlink, and is the only
  addition: the `colors.toml` rules, the background allowlist, and the
  no-execution rule are unchanged.
