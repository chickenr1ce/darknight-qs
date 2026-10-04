pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property string targetSection: ""

    readonly property var sections: [
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
            options: [qsTr("Audio outputs")].concat(AudioService.sinkNodes.map(node => AudioService.rawLabelFor(node))),
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
            options: [qsTr("Bar visibility")].concat(BarVisibilityService.modules.map(module => module.title)),
            comingSoon: false
        },
        {
            key: "monitors",
            title: qsTr("Monitors"),
            options: [qsTr("Primary monitor"), qsTr("Workspaces per monitor")].concat(MonitorService.screenNames),
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
        { key: "weather", title: qsTr("Weather"), options: [qsTr("City"), qsTr("Location")], comingSoon: false }
    ]

    function requestSection(sectionKey: string): void {
        root.targetSection = sectionKey;
    }
}
