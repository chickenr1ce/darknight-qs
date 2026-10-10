pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property string targetSection: ""

    readonly property var sectionRegistry: [
        { key: "calendar", title: qsTr("Calendar"), options: [qsTr("World clock"), qsTr("Zones"), qsTr("Feeds")], comingSoon: false },
        {
            key: "cava",
            title: qsTr("Cava"),
            options: [qsTr("Style"), qsTr("Sensitivity"), qsTr("Auto sensitivity"), qsTr("Bars"), qsTr("Max height")],
            comingSoon: false
        },
        { key: "dashboard", title: qsTr("Dashboard"), options: [qsTr("Seam radius")], comingSoon: false },
        {
            key: "audio",
            title: qsTr("Audio"),
            options: [qsTr("Audio outputs"), qsTr("Volume OSD")].concat(AudioService.sinkNodes.map(node => AudioService.rawLabelFor(node))),
            comingSoon: false
        },
        {
            key: "fonts",
            title: qsTr("Fonts"),
            options: [qsTr("Font")].concat(FontService.roles.map(role => role.label)),
            comingSoon: false
        },
        {
            key: "layout",
            title: qsTr("Layout"),
            options: [qsTr("Bar visibility")]
                .concat(
                    BarVisibilityService.modules.map(module => module.title),
                    BarMarginService.rows.map(row => row.label)
                ),
            comingSoon: false
        },
        {
            key: "media",
            title: qsTr("Media"),
            options: [qsTr("Player"), qsTr("Apps")].concat(MprisPlayers.seenPlayers.map(player => player.label)),
            comingSoon: false
        },
        {
            key: "apps",
            title: qsTr("Apps"),
            options: [qsTr("Hidden"), qsTr("Launcher"), qsTr("Terminal")].concat(AppService.hiddenEntries.map(app => app.name)),
            comingSoon: false
        },
        {
            key: "monitors",
            title: qsTr("Monitors"),
            options: [qsTr("Primary monitor"), qsTr("Displays"), qsTr("Workspaces per monitor")]
                .concat(
                    MonitorService.screenNames,
                    MonitorService.monitors.map(monitor => monitor.name),
                    MonitorService.monitors.map(monitor => monitor.model).filter(label => label !== ""),
                    MonitorService.monitors.map(monitor => monitor.description).filter(label => label !== "")
                ),
            comingSoon: false
        },
        { key: "motion", title: qsTr("Motion"), options: [qsTr("Reduced motion"), qsTr("Animation")], comingSoon: false },
        { key: "notifications", title: qsTr("Notifications"), options: [qsTr("Do not disturb"), qsTr("DND")], comingSoon: false },
        {
            key: "theme",
            title: qsTr("Theme"),
            options: [qsTr("Theme")].concat(ThemeService.catalog.map(theme => theme.name), ThemeService.catalog.map(theme => theme.displayName)),
            comingSoon: false
        },
        { key: "themed-apps", title: qsTr("Themed apps"), options: ThemeService.themeTargets.map(target => target.title), comingSoon: false },
        { key: "weather", title: qsTr("Weather"), options: [qsTr("City"), qsTr("Location")], comingSoon: false }
    ]

    readonly property var sections: [...root.sectionRegistry].sort((a, b) => a.title.localeCompare(b.title))

    function requestSection(sectionKey: string): void {
        root.targetSection = sectionKey;
    }
}
