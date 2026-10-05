#!/bin/sh
# qs-theme: install omarchy v4 theme directories and drive the running shell.
#
#   qs-theme install <git-url>[#subdir]   clone a theme into the theme root
#   qs-theme remove <name>                delete an installed theme
#   qs-theme list                         list the catalog
#   qs-theme current                      print the active theme
#   qs-theme set <name>                   switch the active theme
#   qs-theme background <file>            remember the active theme's background
#   qs-theme add-background [--theme <name>] [--force] <file>...
#                                         copy local image(s) into a theme
#   qs-theme remove-background [--theme <name>] [--] <name>...
#                                         delete local image(s) from a theme
#
# install, remove, add-background, and remove-background write the theme
# directory themselves.
# Every other verb is a thin client over the shell's "theme" IPC target, so the
# shell stays the one source of truth. They still succeed when the shell is down;
# the next start lists the change. Setup and the PATH symlink: docs/user/qs-theme.md.
set -eu

data_home=${XDG_DATA_HOME:-${HOME}/.local/share}
theme_root=$data_home/quickshell/themes
background_max_bytes=33554432

die() { printf 'qs-theme: %s\n' "$*" >&2; exit 1; }

say() { printf 'qs-theme: %s\n' "$*" >&2; }

# Strip control characters from untrusted text before printing it, so a
# newline or escape sequence in a URL, name, or shell error cannot inject
# extra terminal lines.
safe() { printf '%s' "$1" | LC_ALL=C tr -d '[:cntrl:]'; }

# Like safe, but keeps newlines so a multi-line listing keeps its shape; a
# carriage return or escape sequence embedded in a theme name is still removed.
safe_lines() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\011\013-\037\177'; }

usage() {
    cat <<'USAGE'
usage: qs-theme <command> [args]

  install <git-url>[#subdir]   clone a theme into the theme root
  remove <name>                delete an installed theme
  list                         list the installed themes
  current                      print the active theme
  set <name>                   switch the active theme
  background <file>            remember the active theme's background
  add-background [--theme <name>] [--force] <file>...
                               copy local image(s) into a theme's backgrounds
  remove-background [--theme <name>] [--] <name>...
                               delete image(s) from a theme's backgrounds
USAGE
}

slug_of() {
    name=$(printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    [ -n "$name" ] || return 1
    case $name in
        .*|*/*|*..*) return 1 ;;
        *[!a-z0-9._+-]*) return 1 ;;
    esac
    case $name in
        [a-z0-9]*) ;;
        *) return 1 ;;
    esac
    printf '%s' "$name"
}

# Mirror of ThemeParsers.backgroundName: take the segment after the last / or \,
# then trim surrounding whitespace, so the stored name is the one the picker
# lists (a scanned name is kept only when backgroundName(name) === name). The
# scan also skips a control character or a pipe, so those are refused here too
# rather than copied in to be ignored.
background_name_of() {
    base=${1##*/}
    base=${base##*\\}
    base=$(printf '%s' "$base" | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$base" ] || return 1
    case $base in
        .*|*..*) return 1 ;;
        *[[:cntrl:]]*|*'|'*) return 1 ;;
    esac
    lower=$(printf '%s' "$base" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    case $lower in
        *.jpg|*.jpeg|*.png|*.webp|*.bmp) ;;
        *) return 1 ;;
    esac
    printf '%s' "$base"
}

clone_with_spinner() {
    url_display=$(safe "$1")
    if [ ! -t 2 ]; then
        say "cloning $url_display"
        GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 \
            git clone --depth 1 --no-recurse-submodules --quiet -- "$1" "$tmp/repo"
        return
    fi
    GIT_LFS_SKIP_SMUDGE=1 GIT_TERMINAL_PROMPT=0 \
        git clone --depth 1 --no-recurse-submodules --quiet -- "$1" "$tmp/repo" &
    clone_pid=$!
    spin=0
    while kill -0 "$clone_pid" 2>/dev/null; do
        case $((spin % 4)) in
            0) frame='|' ;;
            1) frame='/' ;;
            2) frame='-' ;;
            3) frame='\' ;;
        esac
        printf '\rqs-theme: cloning %s %s' "$url_display" "$frame" >&2
        spin=$((spin + 1))
        sleep 0.1
    done
    status=0
    wait "$clone_pid" || status=$?
    printf '\r\033[K' >&2
    return "$status"
}

install_theme() {
    [ $# -ge 1 ] || die "usage: qs-theme install <git-url>[#subdir]"
    spec=$1

    case $spec in
        *'#'*)
            url=${spec%%#*}
            subdir=${spec#*#}
            ;;
        *)
            url=$spec
            subdir=
            ;;
    esac

    [ -n "$url" ] || die "empty git url"
    case $url in
        -*) die "refusing a git url that starts with '-': $(safe "$url")" ;;
    esac
    case $url in
        *::*) die "refusing a git url with a transport helper: $(safe "$url")" ;;
    esac

    if [ -n "$subdir" ]; then
        case $subdir in
            /*|*/) die "subdir must be a relative path with no trailing slash: $(safe "$subdir")" ;;
        esac
        rest=$subdir
        while [ -n "$rest" ]; do
            case $rest in
                */*)
                    segment=${rest%%/*}
                    rest=${rest#*/}
                    ;;
                *)
                    segment=$rest
                    rest=
                    ;;
            esac
            case $segment in
                ''|.|..) die "subdir has an unusable path segment: $(safe "$subdir")" ;;
            esac
        done
        raw_name=${subdir##*/}
    else
        repo_path=$url
        case $repo_path in
            *://*)
                repo_path=${repo_path#*://}
                repo_path=${repo_path#*/}
                ;;
            *:*)
                case ${repo_path%%:*} in
                    */*) ;;
                    *) repo_path=${repo_path#*:} ;;
                esac
                ;;
        esac
        raw_name=${repo_path##*/}
        raw_name=${raw_name%.git}
        case $raw_name in
            omarchy-*) raw_name=${raw_name#omarchy-} ;;
        esac
        case $raw_name in
            *-theme) raw_name=${raw_name%-theme} ;;
        esac
    fi

    name=$(slug_of "$raw_name") || die "$(safe "$spec") does not give a usable theme name"
    dest=$theme_root/$name

    parent=$data_home/quickshell
    mkdir -p "$parent" || die "cannot create $parent"
    tmp=$(mktemp -d "$parent/.qs-theme-XXXXXX") || die "cannot create a temporary directory under $parent"
    backup=
    cleanup() {
        # A signal between moving the old theme aside and moving the new one
        # in would otherwise delete the only copy with the temp directory.
        if [ -n "$backup" ] && { [ -e "$backup" ] || [ -L "$backup" ]; } && [ ! -e "$dest" ]; then
            mv -- "$backup" "$dest" 2>/dev/null || true
        fi
        rm -rf "$tmp"
    }
    trap cleanup EXIT HUP INT TERM

    if ! clone_with_spinner "$url"; then
        die "git clone failed for $(safe "$url")"
    fi

    if [ -n "$subdir" ]; then
        source=$tmp/repo
        rest=$subdir
        while [ -n "$rest" ]; do
            case $rest in
                */*)
                    segment=${rest%%/*}
                    rest=${rest#*/}
                    ;;
                *)
                    segment=$rest
                    rest=
                    ;;
            esac
            source=$source/$segment
            if [ -L "$source" ]; then
                die "$(safe "$spec") crosses a symlinked path in the repository; refusing to install"
            fi
        done
    else
        source=$tmp/repo
        rm -rf "$source/.git"
    fi

    [ -d "$source" ] || die "no theme directory at $(safe "${subdir:-.}") in $(safe "$url")"
    [ -f "$source/colors.toml" ] || die "no colors.toml in $(safe "${subdir:-the repository}"); pass #subdir if the theme is nested"
    if [ -n "$(find "$source" -type l -print -quit)" ]; then
        die "$(safe "$spec") contains a symlink; refusing to install"
    fi

    say "installing $name"
    mkdir -p "$theme_root" || die "cannot create the theme root"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        backup=$tmp/previous
        mv -- "$dest" "$backup" || die "cannot replace $dest"
    fi
    if ! mv -- "$source" "$dest"; then
        if [ -n "$backup" ]; then
            mv -- "$backup" "$dest" || true
        fi
        die "cannot move the theme into $theme_root"
    fi

    quickshell ipc call theme refresh >/dev/null 2>&1 || true
    printf 'installed %s\n' "$name"
}

remove_theme() {
    [ $# -ge 1 ] || die "usage: qs-theme remove <name>"
    name=$(slug_of "$1") || die "not a theme name: $(safe "$1")"
    dest=$theme_root/$name
    [ -e "$dest" ] || die "no theme named $name is installed"
    if [ -L "$dest" ]; then
        die "refusing to remove a symlink: $dest"
    fi
    [ -d "$dest" ] || die "not a theme directory: $dest"
    rm -rf -- "$dest" || die "cannot remove $dest"
    quickshell ipc call theme refresh >/dev/null 2>&1 || true
    printf 'removed %s\n' "$name"
}

add_backgrounds() {
    theme=
    force=0
    while [ $# -gt 0 ]; do
        case $1 in
            --theme)
                [ $# -ge 2 ] || die "--theme needs a name"
                theme=$(slug_of "$2") || die "not a theme name: $(safe "$2")"
                shift 2
                ;;
            --force)
                force=1
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "unknown option: $(safe "$1")"
                ;;
            *)
                break
                ;;
        esac
    done
    [ $# -ge 1 ] || die "usage: qs-theme add-background [--theme <name>] [--force] <file>..."

    if [ -z "$theme" ]; then
        theme=$(ipc current) || true
        [ -n "$theme" ] || die "no active theme; pass --theme <name>"
        theme=$(slug_of "$theme") || die "the active theme is not a usable name"
    fi

    dir=$theme_root/$theme
    if [ -L "$dir" ]; then
        die "refusing a symlinked theme directory: $dir"
    fi
    [ -d "$dir" ] || die "no theme named $theme is installed"

    bg=$dir/backgrounds
    if [ -L "$bg" ]; then
        die "refusing a symlinked backgrounds directory: $bg"
    fi
    if [ ! -d "$bg" ]; then
        mkdir -p "$bg" || die "cannot create $bg"
    fi

    seen=
    for file in "$@"; do
        [ -f "$file" ] || die "not a file: $(safe "$file")"
        base=$(background_name_of "$file") || die "not a background image (jpg, jpeg, png, webp, bmp): $(safe "$file")"
        case "|$seen|" in
            *"|$base|"*)
                if [ "$force" != 1 ]; then
                    die "more than one input is named $(safe "$base"); use --force to keep only the last"
                fi
                ;;
        esac
        seen="$seen|$base"
        size=$(stat -c %s -- "$file" 2>/dev/null) || die "cannot read $(safe "$file")"
        [ "$size" -le "$background_max_bytes" ] || die "$(safe "$base") is larger than 32 MB"
        dest=$bg/$base
        if { [ -e "$dest" ] || [ -L "$dest" ]; } && [ "$force" != 1 ]; then
            die "a background named $(safe "$base") already exists in $theme; use --force to replace it"
        fi
    done

    for file in "$@"; do
        base=$(background_name_of "$file")
        dest=$bg/$base
        src_id=$(stat -L -c '%d:%i' -- "$file" 2>/dev/null) || src_id=
        dest_id=$(stat -L -c '%d:%i' -- "$dest" 2>/dev/null) || dest_id=
        if [ -n "$src_id" ] && [ "$src_id" = "$dest_id" ]; then
            say "$(safe "$base") is already in $theme"
            continue
        fi
        tmp_file=$(mktemp "$bg/.qs-theme-add-XXXXXX") || die "cannot create a temporary file in $bg"
        if ! cp -- "$file" "$tmp_file"; then
            rm -f "$tmp_file"
            die "cannot copy $(safe "$file")"
        fi
        if ! mv -f -- "$tmp_file" "$dest"; then
            rm -f "$tmp_file"
            die "cannot place $(safe "$base") in $bg"
        fi
        printf 'added %s\n' "$base"
    done

    quickshell ipc call theme refresh >/dev/null 2>&1 || true
}

remove_backgrounds() {
    theme=
    while [ $# -gt 0 ]; do
        case $1 in
            --theme)
                [ $# -ge 2 ] || die "--theme needs a name"
                theme=$(slug_of "$2") || die "not a theme name: $(safe "$2")"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "unknown option: $(safe "$1")"
                ;;
            *)
                break
                ;;
        esac
    done
    [ $# -ge 1 ] || die "usage: qs-theme remove-background [--theme <name>] <name>..."

    if [ -z "$theme" ]; then
        theme=$(ipc current) || true
        [ -n "$theme" ] || die "no active theme; pass --theme <name>"
        theme=$(slug_of "$theme") || die "the active theme is not a usable name"
    fi

    dir=$theme_root/$theme
    if [ -L "$dir" ]; then
        die "refusing a symlinked theme directory: $dir"
    fi
    [ -d "$dir" ] || die "no theme named $theme is installed"

    bg=$dir/backgrounds
    if [ -L "$bg" ]; then
        die "refusing a symlinked backgrounds directory: $bg"
    fi
    [ -d "$bg" ] || die "theme $theme has no backgrounds"

    # Resolve and check every name before removing any, so one bad argument
    # leaves the theme untouched. background_name_of drops a directory prefix
    # and refuses a path that could escape backgrounds/, so only a plain name
    # directly under $bg is ever removed; a symlinked entry is refused, matching
    # the scan that hides it from the picker.
    names=
    for arg in "$@"; do
        base=$(background_name_of "$arg") || die "not a background image (jpg, jpeg, png, webp, bmp): $(safe "$arg")"
        dest=$bg/$base
        if [ -L "$dest" ] || [ ! -f "$dest" ]; then
            die "no background named $(safe "$base") in $theme"
        fi
        case "|$names|" in
            *"|$base|"*) continue ;;
        esac
        names="$names$base|"
    done

    rest=$names
    while [ -n "$rest" ]; do
        base=${rest%%|*}
        rest=${rest#*|}
        if ! rm -f -- "$bg/$base"; then
            die "cannot remove $bg/$base"
        fi
        printf 'removed %s\n' "$base"
    done

    quickshell ipc call theme refresh >/dev/null 2>&1 || true
}

ipc() {
    command -v quickshell >/dev/null 2>&1 || die "quickshell is not on PATH"
    out=$(quickshell ipc call theme "$@") || die "the shell is not running"
    case $out in
        "Target not found."*)
            die "the running shell has no theme service; it is not running a build with this feature"
            ;;
    esac
    printf '%s' "$out"
}

ipc_read_or() {
    out=$(ipc "$1")
    if [ -n "$out" ]; then
        printf '%s\n' "$(safe_lines "$out")"
    else
        printf '%s\n' "$2"
    fi
}

ipc_mutation() {
    out=$(ipc "$@")
    case $out in
        ok:*) printf '%s\n' "$(safe "${out#ok: }")" ;;
        error:*)
            printf 'qs-theme: %s\n' "$(safe "${out#error: }")" >&2
            exit 1
            ;;
        *) printf '%s\n' "$(safe_lines "$out")" ;;
    esac
}

do_list() {
    ipc_read_or list "no themes installed"
}

do_current() {
    ipc_read_or current "no theme"
}

do_set() {
    [ $# -ge 1 ] && [ -n "$1" ] || die "usage: qs-theme set <name>"
    ipc_mutation set "$1"
}

do_background() {
    [ $# -ge 1 ] && [ -n "$1" ] || die "usage: qs-theme background <file>"
    ipc_mutation background "$1"
}

command=${1:-}
if [ $# -gt 0 ]; then
    shift
fi

case $command in
    install) install_theme "$@" ;;
    remove) remove_theme "$@" ;;
    list) do_list ;;
    current) do_current ;;
    set) do_set "$@" ;;
    background) do_background "$@" ;;
    add-background) add_backgrounds "$@" ;;
    remove-background) remove_backgrounds "$@" ;;
    ''|-h|--help|help) usage ;;
    *) die "unknown command: $command" ;;
esac
