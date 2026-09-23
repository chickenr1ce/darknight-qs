pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    id: root

    property bool visible: false
    property double lastOutsideCloseAt: 0
    property ShellScreen anchorScreen: null
    property real anchorCenterX: 0

    function toggle() {
        if (!root.visible && Date.now() - root.lastOutsideCloseAt < 300)
            return;
        root.visible = !root.visible;
    }

    function toggleAt(screen, centerX) {
        if (screen) {
            const prevName = root.anchorScreen ? root.anchorScreen.name : "";
            const moved = root.visible && !(prevName === "") && !(screen.name === prevName);
            root.anchorScreen = screen;
            root.anchorCenterX = centerX;
            if (moved)
                return;
        }
        root.toggle();
    }

    function closeFromOutside() {
        if (root.visible) {
            root.lastOutsideCloseAt = Date.now();
            root.visible = false;
        }
    }
}
