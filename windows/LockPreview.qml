pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.dev
import qs.services

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    readonly property ShellScreen previewScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    visible: LockService.previewOpen && root.previewScreen !== null
    screen: root.previewScreen
    color: Colors.background
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    margins {
        top: 0
        left: 0
    }

    implicitWidth: root.previewScreen ? root.previewScreen.width : 0
    implicitHeight: root.previewScreen ? root.previewScreen.height : 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Component.onCompleted: DevGeometry.register("lock.preview", idPreviewSurface)
    Component.onDestruction: DevGeometry.unregister("lock.preview")

    Item {
        id: idPreviewSurface

        anchors.fill: parent

        LockSurface {
            anchors.fill: parent
            preview: true
        }
    }
}
