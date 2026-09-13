pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// StatusNotifier icons matching waybar sizing (14px icons, 10 spacing).
ModuleBox {
    id: root

    enableMouseArea: false
    visible: idTrayRepeater.count > 0

    // Stash: the cursorpos reply arrives after this function returns.
    property string pendingFocusAddress: ""

    // Activate alone never raises Ayatana windows, so focus too; harmless where Activate already did.
    function focusAppWindow(item): bool {
        if (!item)
            return false;
        const rawTokens = [item.id, item.title, item.tooltipTitle];
        const keys = [];
        for (let i = 0; i < rawTokens.length; i++) {
            const token = String(rawTokens[i] ?? "").toLowerCase().trim();
            if (!token)
                continue;
            const base = token.split(/[^a-z0-9]+/)[0];
            if (base && !keys.includes(base))
                keys.push(base);
        }
        if (keys.length === 0)
            return false;
        const toplevels = Hyprland.toplevels?.values ?? [];
        // Gather matches first so title overlap beats list order (Steam owns two windows).
        const candidates = [];
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const ipc = toplevel.lastIpcObject ?? {};
            // Classes can be reverse-DNS, so match any segment.
            const classSegments = String(ipc["class"] ?? "").toLowerCase().split(/[^a-z0-9]+/);
            const initialSegments = String(ipc["initialClass"] ?? "").toLowerCase().split(/[^a-z0-9]+/);
            for (let k = 0; k < keys.length; k++) {
                if (classSegments.includes(keys[k]) || initialSegments.includes(keys[k])) {
                    candidates.push(toplevel);
                    break;
                }
            }
        }
        if (candidates.length === 0)
            return false;
        let target = candidates[0];
        let foundTitleMatch = false;
        for (let i = 0; i < candidates.length && !foundTitleMatch; i++) {
            const titleIpc = candidates[i].lastIpcObject ?? {};
            const windowTitle = String(titleIpc["title"] ?? "").toLowerCase();
            for (let k = 0; k < keys.length; k++) {
                if (keys[k].length >= 3 && windowTitle.includes(keys[k])) {
                    target = candidates[i];
                    foundTitleMatch = true;
                    break;
                }
            }
        }
        const rawAddress = String(target.address ?? "");
        if (!rawAddress)
            return false;
        // HyprlandToplevel.address omits the 0x prefix, but the window selector needs it.
        const selectorAddress = rawAddress.startsWith("0x") ? rawAddress : "0x" + rawAddress;
        if (selectorAddress === "0x")
            return false;
        if (idCursorPosProcess.running) {
            // A previous click is still resolving; focus now and skip the restore.
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${selectorAddress}" })`);
        } else {
            root.pendingFocusAddress = selectorAddress;
            idCursorPosProcess.running = true;
        }
        return true;
    }

    // Hyprland warps to the focused window, so snapshot the tray position and restore it after.
    Process {
        id: idCursorPosProcess

        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            id: idCursorPosCollector

            onStreamFinished: {
                const match = idCursorPosCollector.text.trim().match(/(-?\d+)\s*,\s*(-?\d+)/);
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${root.pendingFocusAddress}" })`);
                if (match)
                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${match[1]}, y = ${match[2]} })`);
            }
        }
    }

    Repeater {
        id: idTrayRepeater

        model: SystemTray.items

        delegate: Rectangle {
            id: idTrayItem

            Layout.alignment: Qt.AlignVCenter

            required property SystemTrayItem modelData

            readonly property bool isHovered: idTrayItemMouseArea.containsMouse
            readonly property bool isPressed: idTrayItemMouseArea.pressed

            // Panel theme icons draw currentColor as black, so tint them; pixmaps stay full-color.
            readonly property string iconSource: String(idTrayItem.modelData.icon)
            readonly property bool isThemedIcon: idTrayItem.iconSource.startsWith("image://icon/")

            implicitWidth: 22
            implicitHeight: 20
            radius: Globals.radius
            color: idTrayItem.isPressed ? Colors.surface : idTrayItem.isHovered ? Colors.backgroundSecondary : "transparent"
            scale: idPressScale.scale

            PressFeedback {
                id: idPressFeedback

                active: idTrayItem.isHovered
            }

            PressScale {
                id: idPressScale

                pressed: idTrayItem.isPressed
                pressedScale: Globals.pressScalePill
            }

            QsMenuAnchor {
                id: idTrayMenuAnchor

                anchor.item: idTrayItem
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                menu: idTrayItem.modelData.menu
            }

            IconImage {
                id: idTrayItemIcon

                anchors.centerIn: parent
                implicitSize: 14
                width: 14
                height: 14
                source: idTrayItem.modelData.icon
                // Hidden: MultiEffect re-renders the source, so visible would draw every icon twice.
                visible: false
            }

            MultiEffect {
                id: idTrayItemEffect

                anchors.fill: idTrayItemIcon
                source: idTrayItemIcon
                colorization: idTrayItem.isThemedIcon ? 1.0 : 0.0
                colorizationColor: Colors.text
            }

            MouseArea {
                id: idTrayItemMouseArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    idPressFeedback.pulse();
                    switch (mouse.button) {
                    case Qt.LeftButton:
                        // onlyMenu items have no activation action.
                        if (idTrayItem.modelData.onlyMenu && idTrayItem.modelData.hasMenu) {
                            idTrayMenuAnchor.open();
                        } else {
                            idTrayItem.modelData.activate();
                            root.focusAppWindow(idTrayItem.modelData);
                        }
                        break;
                    case Qt.MiddleButton:
                        idTrayItem.modelData.secondaryActivate();
                        break;
                    case Qt.RightButton:
                        if (idTrayItem.modelData.hasMenu)
                            idTrayMenuAnchor.open();
                        else
                            idTrayItem.modelData.secondaryActivate();
                        break;
                    }
                }

                onWheel: wheel => {
                    if (wheel.angleDelta.y !== 0) {
                        idTrayItem.modelData.scroll(wheel.angleDelta.y, false);
                    } else if (wheel.angleDelta.x !== 0) {
                        idTrayItem.modelData.scroll(wheel.angleDelta.x, true);
                    }
                }
            }
        }
    }
}
