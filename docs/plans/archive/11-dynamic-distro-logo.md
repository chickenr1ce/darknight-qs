# 11 — Dynamic distro logo (power menu icon, dashboard system block)

Status: implemented. Base `main` at `0075e5f`. Worktree
`~/worktrees/quickshell-distro-logo`.

## Problem

The bar's power-menu icon (`modules/PowerMenu.qml:29`) and the dashboard's
distro row (`windows/DashboardSystemBlock.qml:97`) both render the hard-coded
`Icons.distro` (`config/Icons.qml:50`, the CachyOS glyph U+F385). Only the
dashboard *text* is live (`SystemInfo.distro`, from fastfetch `prettyName`). On
any other distro the shell shows the CachyOS logo.

## Verified facts

- `SystemInfo.refresh()` runs fastfetch only when the dashboard opens
  (`DashboardCenter` open hook). The bar icon renders at login, long before
  that, so it cannot depend on the fastfetch run without a new boot-time spawn.
- `SystemLogic.parseFastfetch` already receives `result.id` and `result.idLike`
  for the `OS` module and drops them. Its output shape is asserted with deep
  equality in `scripts/test-dashboard-data.sh` (~lines 661-676).
- `/etc/os-release` is static for a session, universal across every distro this
  shell can run on (needs Wayland + Quickshell), and carries `ID`, `ID_LIKE`,
  `PRETTY_NAME`. Fastfetch derives its own OS fields from it.
- Installed `ttf-nerd-fonts-symbols` 3.5.1 has every `nf-linux-*` glyph
  U+F300-U+F385 (checked with fontTools). The current icon font resolves
  U+F385 through fontconfig fallback to it.

## Design

**Source of truth: os-release, not fastfetch.** A `FileView` in `SystemInfo`
reads `/etc/os-release` (fallback `/usr/lib/os-release`) once at load. No
process, no dashboard dependency, correct from the first bar frame. Fastfetch
keeps owning the dashboard's pretty name and the other rows.

**Pure logic in a new `services/DistroLogic.js`** (`.pragma library`, node
tested, per `docs/dev/CODING_STANDARDS.md`):

- `parseOsRelease(text)` -> `{ id, idLike: [..], prettyName }`. Handles
  `KEY=value`, `KEY="value"`, single quotes, blank and `#` lines, CRLF; lower-
  cases `id`/`idLike`; splits `ID_LIKE` on whitespace.
- `distroGlyph(id, idLike)` -> glyph. Order: exact `ID` in the table, then each
  `ID_LIKE` token left to right, then the generic Tux glyph (U+F31A). Empty
  input returns the Tux glyph, never an empty string.
- The table is one object literal, glyph literal plus a `// nf-linux-<name>
  U+Fxxx` comment per row, matching `Icons.qml` style.

**Table coverage** (exact `ID` -> glyph; derivatives with no own glyph resolve
through `ID_LIKE`):

| Family | IDs with their own glyph | Falls back via ID_LIKE |
| --- | --- | --- |
| Arch | `arch`, `cachyos`, `endeavouros`, `manjaro`, `garuda`, `artix`, `arcolinux`, `archcraft`, `archlabs`, `parabola`, `hyperbola`, `biglinux` | SteamOS, Omarchy, Arch derivatives (`arch`) |
| Debian | `debian`, `ubuntu`, `pop`, `linuxmint`, `elementary`, `zorin`, `kali`, `parrot`, `raspbian`, `deepin`, `mx`, `devuan`, `tails`, `trisquel`, `postmarketos` | PureOS, Neon (`kde-neon`), Ubuntu flavours, LMDE (`debian`) |
| Red Hat | `fedora`, `nobara`, `rhel`, `centos`, `rocky`, `almalinux` | Bazzite, Bluefin, Aurora, Universal Blue (`fedora`), Oracle Linux (`rhel`) |
| SUSE | `opensuse-tumbleweed`, `opensuse-leap`, `opensuse` | `opensuse-slowroll`, SLES/SLED (`suse`, `opensuse`) |
| Independent | `nixos`, `gentoo`, `void`, `alpine`, `slackware`, `solus`, `guix`, `qubes`, `mageia`, `openwrt` | Funtoo, Calculate (`gentoo`) |
| BSD | `freebsd`, `openbsd` | rarely relevant, cheap to include |

Implementation re-checks each ID against the font's real glyph names before
writing the table (fontTools one-liner used here), and drops any row whose
glyph is missing.

**Wiring**

- `SystemInfo`: add `osId`, `osIdLike`, `osPrettyName`, plus
  `readonly property string distroGlyph: DistroLogic.distroGlyph(...)`. Until
  the file loads (and if it is unreadable) `distroGlyph` is the Tux glyph.
- `PowerMenu.qml`: `text: SystemInfo.distroGlyph`.
- `DashboardSystemBlock.qml`: `icon: SystemInfo.distroGlyph`; value stays
  `SystemInfo.distro`, but falls back to `osPrettyName` before `"Unknown"`, so
  a machine without fastfetch still shows its name.
- `Icons.distro` is removed (no remaining readers) so the CachyOS logo cannot
  leak back in as a default. `Icons.qml` keeps no logo constants; the table
  lives with its logic.
- Follow `docs/dev/quickshell-io-notes.md` for `FileView` use (no
  `watchChanges`, one read).
- **Deviation:** `SystemInfo.osIdLike` is a space-joined string, not a list,
  because the lint forbids `var` and list properties. `applyOsRelease` joins
  `parseOsRelease`'s `idLike` array, and `distroGlyph` splits the string back
  into tokens, so the ID_LIKE precedence is unchanged.

**Out of scope** (note, do not build): a Settings override to pick a logo
manually; colored/SVG logos from `/usr/share/pixmaps`; reading the freedesktop
`LOGO=` key; BSD-specific shell support.

## Steps

Small, scoped, in order; one commit each (conventional commits).

1. **`DistroLogic.js` + node tests.** New file, `tests/fixtures/os-release-*`
   (cachyos, ubuntu, bazzite with `ID_LIKE="fedora"`, quoted/unquoted, CRLF,
   empty, garbage). Tests in `scripts/test-dashboard-data.sh` via
   `tests/qmljs.js`: parse cases; every table row maps to its expected glyph;
   `ID_LIKE` left-to-right precedence (`ID=bazzite ID_LIKE=fedora` -> Fedora;
   `ID=steamos ID_LIKE=arch` -> Arch; `ID=linuxmint ID_LIKE="ubuntu debian"` ->
   Mint, not Ubuntu); unknown and empty -> Tux; every glyph codepoint within
   U+F300-U+F385.
2. **`SystemInfo` reads os-release** and exposes `distroGlyph`, `osPrettyName`.
   Structural greps added to the same test script.
3. **Rewire `PowerMenu.qml` and `DashboardSystemBlock.qml`**, delete
   `Icons.distro`; update the existing structural assertions that name
   `Icons.distro`.
4. **Docs.** `CONTEXT.md` gets the term if one is introduced; plans README row
   for plan 11; a line in the relevant dev doc that the logo comes from
   os-release and how to add a distro (one table row plus one test row).

## Verification

- `scripts/check.sh` passes; `scripts/boot-check.sh <worktree>` reports
  `loaded`.
- Live: `scripts/restart.sh --probe <worktree>`; the bar icon and dashboard
  row show the host's logo. Spoof other distros without touching the system by
  pointing the FileView path at a fixture through a temporary local edit
  (reverted before commit) and checking Arch, Ubuntu, Fedora, openSUSE, NixOS,
  and an unknown ID (Tux).
- Optical check of a few glyphs against `docs/dev/CODING_STANDARDS.md` "Nerd
  glyphs need a measured optical nudge": `nf-linux-*` bearings differ from
  the md-* icons the bar uses next to it.

## Risks

- **Icon font lacking `nf-linux-*`**: the Settings -> Fonts icon family is
  user-selectable. A family without these glyphs falls back through fontconfig
  to Symbols Nerd Font (same as today for U+F385). Document the dependency.
- **Newest glyphs** (`nobara` U+F380, `cachyos` U+F385) need Nerd Fonts >= 3.4;
  older installs show tofu. Same exposure as today.
- **Derivative IDs not in the table** show their parent's logo, not Tux; that
  is intended, but the test table must cover the `ID_LIKE` path so it does not
  regress.
