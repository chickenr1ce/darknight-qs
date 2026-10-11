pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    readonly property PanelState panel: TrayMenuService.panelState
    readonly property bool panelVisible: root.panel.visible
    property bool loaded: false

    readonly property ShellScreen anchorScreen: root.panel.anchorScreen
    readonly property real screenWidth: root.anchorScreen ? root.anchorScreen.width : 0
    readonly property real screenHeight: root.anchorScreen ? root.anchorScreen.height : 0
    readonly property real iconLeft: root.panel.anchorCenterX - Globals.trayIconWidth / 2
    readonly property real topMargin: Globals.barHeight + Globals.barTopMargin + Globals.trayMenuGap - Globals.menuMargin
    readonly property int windowWidth: Math.round(Math.min(root.screenWidth,
        2 * Globals.menuMaxWidth + Globals.menuSubmenuGap + 2 * Globals.menuMargin))
    readonly property int windowLeft: Math.round(Math.max(0,
        Math.min(root.iconLeft - Globals.menuMargin, root.screenWidth - root.windowWidth)))
    readonly property real anchorX: root.iconLeft - root.windowLeft

    signal outsideClicked()

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: root.anchorScreen
    visible: root.panelVisible || root.loaded || idTrayContextMenu.shown
    implicitWidth: root.windowWidth
    implicitHeight: Math.max(0, root.screenHeight - Math.round(root.topMargin))

    anchors {
        top: true
        left: true
    }

    margins {
        top: Math.round(root.topMargin)
        left: root.windowLeft
    }

    mask: Region {
        item: idTrayContextMenu.inputBox
    }

    Component.onCompleted: PanelGrab.register(root)
    Component.onDestruction: PanelGrab.unregister(root)

    onOutsideClicked: root.panel.closeFromOutside()
    onPanelVisibleChanged: Qt.callLater(root.sync)

    Connections {
        target: TrayMenuService

        function onItemsChanged() {
            Qt.callLater(root.sync);
        }

        function onItemChanged() {
            root.loaded = false;
            Qt.callLater(root.sync);
        }
    }

    Timer {
        id: idTrayMenuLoadTimer

        interval: Globals.trayMenuLoadTimeoutMs
        running: root.panelVisible && !root.loaded
        onTriggered: root.panel.closeFromOutside()
    }

    ContextMenu {
        id: idTrayContextMenu

        anchors.fill: parent
        visible: root.loaded || !root.panelVisible
        items: TrayMenuService.items

        onShownChanged: TrayMenuService.menuShown = idTrayContextMenu.shown

        onClosed: {
            if (root.loaded)
                root.panel.closeFromOutside();
        }

        onTriggered: item => {
            if (item && item.entry)
                item.entry.triggered();
        }
    }

    function sync(): void {
        if (!root.panelVisible) {
            root.loaded = false;
            idTrayContextMenu.closeMenu();
            return;
        }
        if (root.loaded || TrayMenuService.items.length === 0)
            return;
        root.loaded = true;
        idTrayContextMenu.openAt(root.anchorX, Globals.menuMargin);
    }
}
