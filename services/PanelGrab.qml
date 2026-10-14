pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var visiblePanels: root.members.filter(member => member.panelVisible)
    readonly property bool active: root.visiblePanels.length > 0
    readonly property bool closing: root.members.some(member => member.visible && !member.panelVisible)
    readonly property var windows: root.active ? root.barWindows.concat(root.visiblePanels) : []

    property var barWindows: []
    property var members: []
    property int shownCount: 0

    HyprlandFocusGrab {
        id: idFocusGrab

        active: root.active
        windows: root.windows
        onCleared: root.dismiss()
    }

    // Hyprland hands pointer focus to a keyboard-focusable layer when it maps,
    // wherever the cursor is, so the bar module under a still cursor loses hover
    // and the next click lands on the panel. A cursor move in place makes
    // Hyprland hit-test again and give pointer focus back to what is under it.
    onVisiblePanelsChanged: {
        if (root.visiblePanels.length > root.shownCount)
            idRefocusTimer.restart();
        else if (root.visiblePanels.length === 0)
            idRefocusTimer.stop();
        root.shownCount = root.visiblePanels.length;
    }

    Timer {
        id: idRefocusTimer

        interval: Globals.panelRefocusMs
        onTriggered: {
            if (idRefocusProcess.running)
                idRefocusTimer.restart();
            else
                idRefocusProcess.running = true;
        }
    }

    Process {
        id: idRefocusProcess

        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            id: idRefocusCollector

            onStreamFinished: {
                const match = idRefocusCollector.text.trim().match(/(-?\d+)\s*,\s*(-?\d+)/);
                if (!match) {
                    console.warn("PanelGrab: cannot parse hyprctl cursorpos, skipping refocus");
                    return;
                }
                Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
            }
        }
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
