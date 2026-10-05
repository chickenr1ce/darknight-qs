# Theme catalog

How a theme directory under the theme root becomes a catalog entry with a
preview swatch, and which file owns each step.

The loader reads a theme as data: `colors.toml` and the `light.mode` marker,
nothing else. No theme code runs (ADR 0011).

## Flow

1. `scripts/theme-catalog-scan.sh` walks the theme root, validates each
   `colors.toml` in one awk pass, and prints one line per trusted theme:

   ```
   <name>|<mode>|<accent>|<magenta>|<foreground>|<surface>|<background>
   ```

   A theme is trusted when it is a real directory holding a readable regular
   `colors.toml` within the byte cap whose palette the loader can build, so the
   catalog never lists a dead switch.
2. `services/ThemeParsers.js` `parseCatalog` splits each line, validates the
   name and mode, normalizes the five preview roles to lowercase opaque hex, and
   returns the `catalog` list.
3. `services/ThemeService.qml` exposes `catalog` and the active palette.
4. Consumers read it: `windows/ThemeSettingsView.qml` lists every theme with a
   swatch strip, and `windows/DashboardThemeBlock.qml` shows the active theme's
   strip through `Colors.themeSwatches`.

## Preview invariant

The scan resolves each preview role the way `parseColors` does, so the strip
matches the palette a theme applies. The first key holding any hex value wins,
and the resolved required role must then be opaque:

| Role | Keys, in order |
| --- | --- |
| accent | `accent` |
| magenta | `magenta`, `color5`, `purple` |
| foreground | `foreground`, `fg`, `color7` |
| background | `background`, `bg`, `color0` |
| surface | `lighter_background`, `lighter_bg`, then the background |

A value present but non-opaque is not skipped for a later key, because
`parseColors` does not skip it either. A surface that lands on the background is
stepped toward the foreground, matching the loader.

`scripts/test-panel-logic.sh` runs the real `parseColors` under node against the
scan's output for the fixture themes and fails on any mismatch, so the two
resolvers cannot drift.

## Changing the format

The scan output is positional. A new field means updating `parseCatalog` and the
Python mirror in `scripts/test-panel-logic.sh` in the same change, or the parser
silently drops it.
