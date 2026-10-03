# qs-theme

`qs-theme` installs theme directories and drives the running shell's theme
service. The shell owns the catalog, the selection, and the backgrounds;
`install`, `remove`, and `add-background` write the theme directory itself and
every other verb is a thin client over the `theme` IPC target on
`services/ThemeService.qml`.

## Put it on PATH

The script is committed at `scripts/qs-theme.sh`. Symlink it once:

```
ln -s ~/.config/quickshell/scripts/qs-theme.sh ~/.local/bin/qs-theme
```

`~/.local/bin` is on the fish `PATH`, so `qs-theme` resolves after that. A
worktree can point the same symlink at its own `scripts/qs-theme.sh`.

## Commands

```
qs-theme install <git-url>[#subdir]
qs-theme remove <name>
qs-theme list
qs-theme current
qs-theme set <name>
qs-theme background <file>
qs-theme add-background [--theme <name>] [--force] <file>...
```

### install

`install` clones into a temporary directory beside the theme root, then moves
the theme directory into `~/.local/share/quickshell/themes/<name>`. The clone
runs with `git clone --depth 1 --no-recurse-submodules` and `GIT_LFS_SKIP_SMUDGE=1`,
so it never pulls submodules or LFS content. A URL carrying a git transport
helper (a `::` scheme such as `ext::`) is refused before the clone runs.

The source is refused when it holds any symlink, and the move only ever writes
`<theme root>/<name>` and removes that same path to replace an existing theme.
The only other path removed is the temporary clone directory this run created.
The clone never survives the run.

The theme name is a slug derived from the repository or the `#subdir` name.
Without `#subdir`, the name comes from the repository basename after stripping
`.git`, a leading `omarchy-`, and a trailing `-theme`, lowercased. With
`#subdir`, the last path segment of the subdir is the name. A name is rejected
before any write when it is empty, holds `/`, holds `..`, or starts with a dot;
the remaining characters must be in `a-z0-9._+-`. The subdir itself must be a
relative path with no `..`, empty segment, or symlinked component.

A theme directory with no `colors.toml` is refused. If the theme is nested in
the repository, as in omarchy's `themes/` layout, name it with `#subdir`:

```
qs-theme install https://github.com/basecamp/omarchy#themes/tokyo-night
qs-theme install https://github.com/example/omarchy-nord-theme
```

On success `install` pings the shell to refresh the catalog. If the shell is
down it still succeeds, and the next shell start discovers the theme.

`install` reports progress on stderr (an animated `cloning <url>` line when
stderr is a terminal, then `installing <name>`) and the result
`installed <name>` on stdout, so a slow clone is visible rather than silent.

A theme whose `colors.toml` predates the semantic palette — ANSI `color0`–`color15`
plus a few named roles — is still switchable. The shell resolves it through
omarchy's own cascade, so an omarchy v4 theme works whether or not it was
regenerated with the named roles, and the directory is never rewritten.

### remove

`remove <name>` deletes `<theme root>/<name>` and pings the shell to refresh the
catalog. The name is validated as a slug first, so the command can only ever
delete one directory directly under the theme root; a symlinked theme directory
is refused. Removing the active theme is allowed: the shell drops it from the
selection when the refreshed catalog no longer lists it, and the bar falls back
to its default palette until another theme is chosen.

```
qs-theme remove outpost
```

### add-background

`add-background` copies one or more local images into a theme's `backgrounds/`
directory, where the dashboard picker lists them. It targets the active theme by
default, or a named one with `--theme`:

```
qs-theme add-background ~/Pictures/forest.png
qs-theme add-background --theme darknight ~/Pictures/*.png
```

The destination is `<theme root>/<name>/backgrounds/<basename>`. A file is
refused unless it is a regular file with extension jpg, jpeg, png, webp, or bmp,
at most 32 MB, and a plain basename (no leading dot, no `..`, no control
character or `|`). The `backgrounds/` directory is created when missing; a
symlinked theme directory or a symlinked `backgrounds/` directory is refused. An
existing name is refused unless `--force` is given, which replaces it.

The verb writes the theme directory itself, like `install` and `remove`. On
success it pings the shell so the picker lists the new image without a restart;
with the shell down the copy still succeeds and the next start lists it.

### list, current, set, background

These call the shell over IPC and print the result. When the shell is not
running, or is running a build that predates this feature and so has no `theme`
service, they exit non-zero with a plain message.

- `list` prints the catalog, marking the active theme with `*`.
- `current` prints the active theme, or `no theme`.
- `set <name>` makes a catalog theme active. An unknown name exits non-zero.
- `background <file>` remembers the file for the active theme in the selection
  state and applies it with `awww` when the file is one of that theme's listed
  backgrounds. The file must be an image with extension jpg, jpeg, png, webp, or
  bmp. Only the basename is kept and it is resolved under the theme's
  `backgrounds/` directory, so a path can never point outside the theme. The
  dashboard picker drives the same seam, so there is one writer.

The switch is owned by the shell: the CLI never edits the selection state
file, the palette, or the rendered desktop files itself.
