# Adding a settings section

`windows/SettingsView.qml` renders the dashboard's Settings tab. It edits the
same service state as the quick panels, so a change in either place shows in the
other. A section has three parts, and each one has a single home.

## 1. State: a service singleton

Put the mutable property on the service that owns the domain under `services/`,
or on `config/Globals.qml` when it is a shell-wide switch. Settings writes that
one property and panels read it — never keep a second copy in the view.

- `CavaService.qml` — cava tuning.
- `CalendarService.qml` — zones and hidden feeds.
- `NotificationServer.qml` — `dndEnabled`.
- `WeatherService.qml` — city, coordinates, and weather reading.
- `BarVisibilityService.qml` — per-module bar visibility.
- `DashboardService.qml` — junction radius.
- `FontService.qml` — Interface, Bar, and Icons families (writes the `Globals` role properties).
- `Globals.qml` — `reducedMotion`.

## 2. View: a component in `windows/`

Root the view at `ColumnLayout` and give it a `filter: string` property. Every
option row binds its own `visible` to a `matches(label)` check, so an empty
query shows all and a query narrows the body. When two rows or sections share a
shape, compose one shared component (`components/SettingsToggleRow.qml`) instead
of copying it.

Filtering has one shape: the `services/SettingsFilter.qml` singleton, which
exposes `filtering(filter)` and `matches(filter, label)`. Have each view supply
its labels to `matches()` rather than copying the predicates into every view. A
label a view wants searchable is reachable only if it is passed to `matches()`;
a label the body never tests is invisible to the search even when the same
string sits in `options`.

## 3. Registration: `SettingsService.sectionRegistry` plus `SettingsView`

Add an entry to `SettingsService.sectionRegistry` with a `key`, a `title`, the
searchable `options` labels, and `comingSoon: false`. Insertion order is
irrelevant: `SettingsService.sections` is the derived view the rail renders,
sorted by title, so the category list is always alphabetical. Then compose the
view in `SettingsView.qml`'s card body, gated on the section and handed the
search filter:

```qml
MySettingsView {
    Layout.fillWidth: true
    visible: root.hasSection && root.currentSection.key === "my"
    filter: root.bodyFilter
}
```

The sidebar lists every section whose `title` or `options` match the query;
when a title matches, the body filter is cleared so the whole section shows.

Every label in `options` must be reachable by the view's filter: either the
view's `matches()` tests that exact label, or the label derives from the same
source the view filters. A section-level label such as `Bar visibility` reveals
a group, so `LayoutSettingsView` treats it as group-relevant and shows every row
in it; a label the body never tests selects the section and renders an empty
body. Do not re-spell a view's labels in `options`; derive them from the shared
source list where one exists (`BarVisibilityService.modules`), or the two lists
drift apart.

## Checklist

- [ ] State lives in one service; settings and panels bind the same property.
- [ ] The new section is added to `SettingsService.sectionRegistry`; the rail
      renders `sections`, sorted by title, so insertion order never matters.
- [ ] The view filters by `filter`; an empty query shows everything.
- [ ] Search labels live in `options` and the view's `matches()` uses them;
      every registered label is reachable, so no `options` entry (e.g.
      `Bar visibility` in Layout) selects a section and shows an empty body.
- [ ] Filtering routes through `services/SettingsFilter.qml`, not a per-view
      copy of the predicates.
- [ ] Repeated rows or sections share one component, not a copy.
- [ ] Add `<key>` assertions to `scripts/test-panel-logic.sh` section 10
      (search labels, mirror binding, shared component).
