pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

Singleton {
    id: root

    // The member contract, by name, for every window that calls register():
    //   visible          the surface is mapped, closing slide included
    //   panelVisible     the panel is open; false through the closing slide
    //   screen           the ShellScreen to raise the bar over a fullscreen window
    //   outsideClicked() the dismissal a grab clear routes to
    // components/PanelShell.qml and windows/TrayMenu.qml conform. Bar windows
    // register through registerBar and only need to be windows.
    readonly property var visiblePanels: root.members.filter(member => member.panelVisible)
    readonly property bool closing: root.members.some(member => member.visible && !member.panelVisible)
    // Panels still mapped, closing slide included. The grab holds until the
    // last one unmaps, so the compositor hands focus back once, after the
    // surface is gone (PanelKeyboardLogic.js has the why).
    readonly property var shownPanels: root.members.filter(member => member.visible)
    readonly property var windows: root.shownPanels.length > 0 ? root.barWindows.concat(root.shownPanels) : []
    // Screens with a panel or tray menu on them, closing slide included, so
    // the bar there can rise above a fullscreen window while it shows.
    readonly property var shownScreens: root.shownPanels.map(member => member.screen)

    property var barWindows: []
    property var members: []
    property int shownCount: 0

    HyprlandFocusGrab {
        id: idFocusGrab

        active: root.shownPanels.length > 0
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
                const point = HyprlandDispatch.parseCursorPos(idRefocusCollector.text);
                if (!point) {
                    console.warn("PanelGrab: cannot parse hyprctl cursorpos, skipping refocus");
                    return;
                }
                HyprlandDispatch.moveCursor(point.x, point.y);
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
