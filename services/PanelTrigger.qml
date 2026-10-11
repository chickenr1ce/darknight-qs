import QtQuick
import Quickshell
import qs.config
import qs.services

QtObject {
    id: root

    property BarAnchor anchor: null
    property PanelState panelState: null
    property Item trigger: null
    property ShellScreen triggerScreen: null
    property bool active: false

    property Connections toggleConnection: Connections {
        id: idPanelTriggerConnection

        target: root.anchor
        function onToggleRequested() {
            if (root.active)
                root.toggle();
        }
    }

    onActiveChanged: root.syncAnchor()
    Component.onCompleted: root.syncAnchor()
    Component.onDestruction: root.unregister()

    function toggle() {
        Panels.toggleAt(root.panelState, root.triggerScreen, Globals.triggerCenterX(root.trigger, root.triggerScreen));
    }

    function syncAnchor() {
        if (root.anchor === null)
            return;
        if (root.active)
            root.anchor.register(root.trigger);
        else
            root.anchor.unregister(root.trigger);
    }

    function unregister() {
        if (root.anchor !== null)
            root.anchor.unregister(root.trigger);
    }
}
