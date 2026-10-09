# App launcher

The dashboard's Apps tab is the launcher: a searchable list of installed apps
with pinned and recent shortcuts, inline controls for a running app, and a
context menu for everything else. It lists the installed desktop entries, so an
installed app shows up here without any extra setup.

## Entry points

- Bind a key to `quickshell ipc call dashboard apps`. The Super setup below is
  the intended one. The call opens the dashboard on Apps with the search field
  focused, switches to Apps when the dashboard is open on another tab, and
  closes the dashboard when Apps is already showing.
- The tabs row inside the dashboard opens Apps directly.
- Clicking the bar title still opens the Dashboard page, unchanged.

## The list

With no query the list has up to three sections:

- Pinned, in the order you pinned them.
- Recent, the last launches that are not pinned, at most 4.
- All apps, every entry A–Z, with a count.

Typing replaces the sections with one ranked list. Ranking is name prefix first,
then word start, substring, subsequence, then keyword, generic name, or id; the
matched letters are highlighted. With no match the list offers one
`Run "query"` row, which runs the text as a shell command in a terminal.

The card grows downward with the list, up to most of the screen height. A list
longer than that scrolls in place, with a thin bar on the right edge.

The card ends with a fixed footer of key hints under a hairline: `↵` Open,
`ctrl 1–9, 0` On workspace (the tenth workspace is Ctrl+0; with fewer
workspaces the range stops at the last one, up to 9), and `→` More, with a
faint "hover a row for actions" reminder on the right. The footer never moves;
the list shrinks instead.

## Mouse

- Hover selects a row. A selected or hovered app row shows its inline buttons;
  Focus and Kill stay dim and inert until the app has a window.
- Left-click a row opens the app and closes the dashboard.
- Middle-click a row opens the app and keeps the dashboard up, so you can start
  several in a row.
- Right-click a row opens its context menu at the pointer.
- The inline buttons are Focus, Kill, Pin/Unpin, and `⋯` for the menu.
- A selected or hovered row swaps the running dot, window count, and pin star
  for those buttons. Focus and Kill are dim and inert when the app has no
  window, so the row never moves.
- The mouse wheel glides about four rows per notch; a high-resolution wheel
  scales its partial chunks proportionally, and a trackpad scrolls with the
  fingers. With reduced motion on, the wheel jumps instead of gliding.
- The scrollbar appears only when the list overflows. Drag it to scroll, or
  click the track above or below it to page.

## Keyboard

The search field keeps keyboard focus while the tab is open, so typing filters
from anywhere in the card.

| Key | Action |
| --- | --- |
| ↑ / ↓ | move the selection by one row |
| PageUp / PageDown | move the selection by five rows |
| Tab / Shift+Tab | move the selection down / up |
| Enter | open the selected app (or run the `Run` row) |
| Alt+Enter | open and keep the dashboard |
| Ctrl+P | pin or unpin the selected app |
| Ctrl+1…9 | open the selected app on absolute workspace 1–9 |
| Ctrl+0 | open the selected app on absolute workspace 10 |
| → | open the context menu on the selected row (cursor at the end of the query) |
| Menu | open the context menu on the selected row |
| Esc | clear the query; when it is already empty, close the dashboard |

Ctrl+N opens on workspace N, and Ctrl+0 is workspace 10. A key past the
available workspace count is consumed and does nothing.

## Context menu

The menu opens on the selected row from → (when the search cursor is at the
end of the query) or the Menu key, and at the pointer on right-click. ↑/↓
move, → opens the "Open on workspace" submenu, ← leaves a submenu and on the
top level closes the menu back to search, and Enter runs the highlighted item.
Typing a printable character closes the menu and sends the text to the search
field. The menu is as wide as its widest item, up to a cap, so a long label
like "Open, keep dashboard" is never cut off; it stays inside the card and the
submenu fits its own content the same way. Items, in order:

1. Open (↵)
2. Open on workspace ▸: a label per enabled monitor, the dashboard's monitor
   first, then one item per workspace in that monitor's block with its absolute
   number. Each monitor's current workspace is marked and occupied workspaces
   keep their marker. Every item shows its absolute shortcut: `ctrl N` for
   workspaces 1–9 and `ctrl 0` for workspace 10. "New empty workspace" adds the
   first free slot in the dashboard monitor's block, hidden when that block is
   full.

   Just after a reload, before the monitor list is known, the submenu falls back
   to the dashboard monitor's block alone, so the item is always there.
3. Open, keep dashboard (middle-click)
4. Focus window (N open), only while the app has windows
5. The entry's desktop actions, under an "Actions" label, only when it
   declares them
6. Pin / Unpin (Ctrl+P)
7. Hide from launcher
8. Copy launch command
9. Kill <name>, danger-styled, only while the app is running

The `Run "query"` row's menu has only Run (↵) and Copy command.

## Terminal apps

An entry marked `Terminal=true` (btop, yazi, nvim, and the like) opens inside a
terminal: the shell runs `kitty -e` plus the entry's command. The `Run "query"`
row runs its text with `kitty -e sh -c`. The terminal is fixed to `kitty`, so
kitty must be installed: without it, terminal entries and the `Run "query"` row
have no terminal to open.

## Pin, hide, and unhide

Pin an app from its inline star, Ctrl+P, or the menu. Pins survive a restart and
show in the Pinned section.

Hide an app with "Hide from launcher" in its menu. It leaves every launcher
section. Bring it back in Settings → Apps: each hidden app has an Unhide button.
An id whose app is no longer installed shows its raw id and can still be
unhidden. Hidden app names are searchable in Settings, so typing a hidden app's
name finds its row.

## Kill

Kill closes every window the launcher matches to the app, through the window's
Wayland close request. It is a graceful close, not a signal: an app may show a
"save your work?" prompt. The dashboard stays open and the row updates when the
windows go. There is no force-kill for a hung app.

Matching is exact: the app's `StartupWMClass`, its desktop id, or the id's last
reverse-DNS segment must equal the window's class. This is stricter than the
shell's notification and tray matching, so Kill cannot close a window belonging
to a different app.

## Where the state lives

Pins, hidden ids, and the recent list persist in
`${XDG_STATE_HOME:-~/.local/state}/quickshell/app-launcher` as
`{ "pinned": [...], "hidden": [...], "recent": [...] }`. The recent list keeps
the last 8 launches. A missing or unreadable file reads as three empty lists.

## Set up the Super key

The bind lives in your own Hyprland config, not in this repo. In
`~/.config/hypr/modules/binds.lua`, replace the two rofi launcher lines:

```lua
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("/home/alexiz/.config/rofi/launchers/type-1/launcher.sh"))
hl.bind(mainMod .. " + SUPER_R", hl.dsp.exec_cmd("/home/alexiz/.config/rofi/launchers/type-1/launcher.sh"))
```

with:

```lua
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("quickshell ipc call dashboard apps"))
hl.bind(mainMod .. " + SUPER_R", hl.dsp.exec_cmd("quickshell ipc call dashboard apps"))
```

`mainMod` is `"SUPER"` in the shipped config. Run `hyprctl reload`, then Super
opens the launcher from any focused window with the cursor already in search.
Keep the rofi script in place until the native path has a week of daily use.

## Known limits

- An app whose window class differs from its desktop id and whose entry has no
  `StartupWMClass` shows no running dot, because the matcher cannot pair it with
  its window. T3 Code Nightly is one example. Adding `StartupWMClass` to the
  entry fixes it.
- No force-kill of a hung app.
- The terminal is fixed to `kitty`.
- Out of scope: category filters or pills, a detail pane, drag-to-reorder,
  calculator, file, web, or command-history search, and editing desktop
  entries.
