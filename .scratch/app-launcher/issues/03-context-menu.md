# 03: Right-click context menu

**Status:** done

**Blocked by:** 02

**Blocking:** 04, 05, 06

**What to build:** A shared context menu component and the launcher's menu.
Right-click on a row, or Shift+F10 / Menu on the selected row, opens it. This
ticket ships the items that need no window matching or workspace mapping;
tickets 04 and 05 add theirs.

## Acceptance criteria

- [x] New `components/ContextMenu.qml`: header (icon, name, generic name),
  items with glyph, label, and key hint, separators, section labels, a danger
  style (`Colors.danger`), and one level of submenu. Tokens only; glyphs via
  `config/Icons.qml` (add any missing ones there).
- [x] The menu opens at the pointer for right-click and under the row for the
  keyboard, and clamps inside the dashboard card (the panel clips outside its
  layout). Outside click and Esc close it; the click that dismisses it does
  not also launch.
- [x] Keyboard: ↑/↓ move, → opens a submenu, ← / Esc leave it, Enter runs.
  Hover moves the highlight.
- [x] Items in this ticket: Open (↵), Open and keep dashboard (middle-click),
  the entry's `actions` under an "Actions" label (each runs
  `DesktopAction.execute()`), Pin / Unpin (Ctrl+P), Hide from launcher, Copy
  launch command (the joined `entry.command` through `wl-copy`). The "Run"
  row's menu has only Run and Copy command.
- [x] Hide writes the id to `hidden` in the `app-launcher` state file; hidden
  entries leave every section and the ranked list.
- [ ] Live: every item works on firefox (two desktop actions) and on an app
  with none.

## Amendments (2026-10-09)

- `components/ContextMenu.qml` is generic and launcher-agnostic. Properties:
  `opened`, `items` (descriptor list), `header`, `anchorX`/`anchorY`,
  `activeLevel`/`activeIndex`/`submenuFor`, and read-only `contentWidth` /
  `contentHeight`. Signals: `closed()` and `triggered(var item)`. Functions:
  `openAt(x, y)`, `closeMenu()`, `handleKey(event)`, plus navigation helpers.
  Descriptor shape: `{ kind: "item"|"separator"|"label", id, text, hint,
  danger, enabled, image, glyph, actionIndex, submenu: [...] }`; `image` is a
  resolved icon source, `glyph` a font glyph, `submenu` one level deep.
- The panel sizes its card from content, so the menu cannot float outside it.
  The view grows `implicitHeight` by `anchorY + contentHeight + margin` while
  the menu is open and the menu clamps to that grown box — the same in-flow
  growth `components/Dropdown.qml` uses. A full-view scrim sits under the menu
  and above the rows, so the dismissing click never reaches a row.
- Launcher wiring lives in `windows/DashboardAppsView.qml`: the pure descriptor
  list is `AppLogic.menuItems(entry, pinned, isRun)` (node-tested), the view
  maps descriptor ids to glyphs and to `AppService` actions. `AppService` gains
  `hide(id)`, `launchAction(entry, index)` (records the launch and closes),
  `copyCommand(entry)`, `copyText(text)`, and `iconForName(name)`; `AppLogic`
  gains `hide(hiddenIds, id)` and `menuItems(...)`. Right-click selects the row
  then opens at the pointer; Shift+F10 / Menu open under the selection. The
  menu's `Keys.onShortcutOverride` swallows Escape while open so `PanelShell`'s
  Escape `Shortcut` closes only the menu. Reduced motion gates both menu
  fades.
- New tokens `Globals.menuWidth` (236), `menuItemHeight` (30),
  `menuHeaderHeight` (40), `menuGlyphWidth` (16), `menuMargin` (4); new glyphs
  `Icons.open`, `Icons.copy`, `Icons.eyeOff`, `Icons.starOutline`
  (`md-open_in_new`, `md-content_copy`, `md-eye_off`, `md-star_outline`,
  verified against the installed GeistMono Nerd Font). `wl-copy` is present at
  `/usr/bin/wl-copy`.
- Three deliberate `property var` descriptors (two in `ContextMenu`, one
  `menuRow` in the view) bring the baseline to 62 via
  `scripts/lint-review.sh --update-baseline`; no other baseline line changed.
- Clean seams for 04/05: add items to `AppLogic.menuItems` with a `submenu`
  array (the component already renders one level and clamps it), and give
  ticket 04's row `⋯` button a call to `openMenuAt(row, point)` behind an
  anchor item.
- Live-only, pending `scripts/restart.sh --probe`: every menu item on firefox
  (two desktop actions) and on an app with none, pointer placement and card
  clamping, outside-click dismissal without launching, and the keyboard
  navigation.
- Supersedes the `implicitHeight`-growth bullet above: the card no longer
  changes height when the menu opens. `ContextMenu` fits inside the view's
  existing bounds — it opens at the anchor, shifts up on bottom overflow, caps
  its height at `view.height - 2 × Globals.menuMargin`, and scrolls its item
  column (`idMenuList` / `idSubmenuList` Flickables) with the highlighted row
  kept in view; the submenu shifts up and flips left under the same cap.
  `DashboardAppsView.implicitHeight` is just the search field plus the capped
  list, so the list area never resizes.
- 2026-10-09 review fixes: the scrim takes `Qt.AllButtons` and closes on any
  press; printable keys close the menu and forward through `typedText(string)`
  to the search field (`DashboardAppsView.forwardTypedText`); new tokens
  `Globals.menuSeparatorHeight` / `menuLabelHeight` / `menuSubmenuGap` replace
  raw pixels; `Icons.openInApp` (`md-open_in_app`, codepoint verified against
  the installed GeistMono Nerd Font) distinguishes open-keep from Copy, and
  iconless desktop actions render no glyph while the label column keeps its
  width; `scripts/test-app-launcher.sh` asserts all of the above.

