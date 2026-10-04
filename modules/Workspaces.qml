pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Each monitor owns a contiguous block of MonitorService.workspacesPerMonitor
// workspaces; the block starts at MonitorService.firstWorkspaceFor(monitorName).
ModuleBox {
    id: root

    property string monitorName: ""
    readonly property int firstWorkspaceId: MonitorService.firstWorkspaceFor(root.monitorName)

    visible: BarVisibilityService.isVisible("workspaces")

    // Own buttons handle clicks, so disable the parent glass pane.
    enableMouseArea: false
    horizontalPadding: 5

    RowLayout {
        id: idWorkspaceRow
        spacing: 0

        Repeater {
            id: idWorkspaceRepeater
            model: MonitorService.workspacesPerMonitor

            delegate: Rectangle {
                id: idWorkspaceButton

                Layout.alignment: Qt.AlignVCenter

                required property int index

                readonly property int workspaceId: root.firstWorkspaceId + index

                readonly property var workspace: {
                    const allWorkspaces = Hyprland.workspaces?.values ?? [];
                    for (let i = 0; i < allWorkspaces.length; i++) {
                        if (allWorkspaces[i].id === idWorkspaceButton.workspaceId)
                            return allWorkspaces[i];
                    }
                    return null;
                }

                readonly property bool isActiveWorkspace: {
                    if (Hyprland.focusedWorkspace?.id === idWorkspaceButton.workspaceId)
                        return true;
                    if (idWorkspaceButton.workspace?.active)
                        return true;
                    if (idWorkspaceButton.workspace?.focused)
                        return true;
                    const allMonitors = Hyprland.monitors?.values ?? [];
                    for (let i = 0; i < allMonitors.length; i++) {
                        const monitor = allMonitors[i];
                        if (monitor.name === root.monitorName && monitor.activeWorkspace?.id === idWorkspaceButton.workspaceId)
                            return true;
                    }
                    return false;
                }

                readonly property bool isUrgentWorkspace: idWorkspaceButton.workspace?.urgent ?? false
                readonly property bool isHovered: idWorkspaceMouseArea.containsMouse
                readonly property bool isPressed: idWorkspaceMouseArea.pressed

                implicitWidth: idWorkspaceLabel.implicitWidth + 16
                implicitHeight: 20
                radius: Globals.radius
                color: (idWorkspaceButton.isActiveWorkspace || idWorkspaceButton.isHovered) ? Colors.backgroundSecondary : "transparent"
                scale: idPressScale.scale

                PressFeedback {
                    id: idPressFeedback

                    active: idWorkspaceButton.isHovered
                }

                PressScale {
                    id: idPressScale

                    pressed: idWorkspaceButton.isPressed
                    pressedScale: Globals.pressScalePill
                }

                Text {
                    id: idWorkspaceLabel

                    anchors.centerIn: parent

                    text: idWorkspaceButton.workspace?.name ?? String(idWorkspaceButton.workspaceId)
                    color: idWorkspaceButton.isUrgentWorkspace ? Colors.red : idWorkspaceButton.isHovered ? Colors.text : idWorkspaceButton.isActiveWorkspace ? Colors.lavender : Colors.textSecondary
                    font {
                        family: Globals.fontFamily
                        pixelSize: Globals.fontPixelSize
                        weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: idWorkspaceMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton

                    // Hyprland ≥0.56 evaluates IPC as Lua: the legacy "workspace N" string fails; use hl.dsp.focus.
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            idPressFeedback.pulse();
                            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${idWorkspaceButton.workspaceId} })`);
                        }
                    }
                }
            }
        }
    }
}
