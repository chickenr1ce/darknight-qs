pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property bool visible: false
    property ShellScreen anchorScreen: null

    readonly property var sections: [
        {
            key: "cava",
            title: qsTr("Cava"),
            options: [qsTr("Style"), qsTr("Sensitivity"), qsTr("Auto sensitivity"), qsTr("Bars"), qsTr("Max height")],
            comingSoon: false
        },
        { key: "calendar", title: qsTr("Calendar"), options: [qsTr("World clock"), qsTr("Zones"), qsTr("Feeds")], comingSoon: false },
        { key: "notifications", title: qsTr("Notifications"), options: [qsTr("Do not disturb"), qsTr("DND")], comingSoon: false },
        { key: "motion", title: qsTr("Motion"), options: [qsTr("Reduced motion"), qsTr("Animation")], comingSoon: false },
        {
            key: "layout",
            title: qsTr("Layout"),
            options: [qsTr("Bar visibility")].concat(BarVisibilityService.modules.map(module => module.title)),
            comingSoon: false
        },
        { key: "weather", title: qsTr("Weather"), options: [qsTr("City"), qsTr("Location")], comingSoon: false }
    ]

    function open(screen): void {
        if (screen)
            root.anchorScreen = screen;
        DashboardService.close();
        root.visible = true;
    }

    function close(): void {
        root.visible = false;
    }
}
