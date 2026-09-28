pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var visiblePanels: root.members.filter(member => member.panelVisible)
    readonly property bool active: root.visiblePanels.length > 0
    readonly property var windows: root.active ? root.barWindows.concat(root.visiblePanels) : []

    property var barWindows: []
    property var members: []

    HyprlandFocusGrab {
        id: idFocusGrab

        active: root.active
        windows: root.windows
        onCleared: root.dismiss()
    }

    function registerBar(window) {
        if (root.barWindows.includes(window))
            return;
        root.barWindows = root.barWindows.concat([window]);
    }

    function unregisterBar(window) {
        root.barWindows = root.barWindows.filter(entry => !(entry === window));
    }

    function register(member) {
        if (root.members.includes(member))
            return;
        root.members = root.members.concat([member]);
    }

    function unregister(member) {
        root.members = root.members.filter(entry => !(entry === member));
    }

    function dismiss() {
        const openPanels = root.visiblePanels.slice();
        for (let i = 0; i < openPanels.length; i++)
            openPanels[i].outsideClicked();
    }
}
