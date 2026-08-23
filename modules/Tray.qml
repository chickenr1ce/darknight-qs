pragma ComponentBehavior: Bound

import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// System tray — StatusNotifierItem icons via Quickshell.Services.SystemTray.
// Matches waybar: icon-size 14, spacing 10. See docs/tray-module.md.
ModuleBox {
    id: root

    enableMouseArea: false
    visible: idTrayRepeater.count > 0

    Repeater {
        id: idTrayRepeater

        model: SystemTray.items

        delegate: Rectangle {
            id: idTrayItem

            required property SystemTrayItem modelData

            property bool isHovered: idTrayItemMouseArea.containsMouse
            property bool isPressed: idTrayItemMouseArea.pressed

            // Monochrome symbolic icons often render near-black on the dark
            // bar; tint them to the text color. Full-color icons pass through
            // untinted (colorization 0 leaves the image unchanged).
            readonly property bool isSymbolicIcon: String(idTrayItem.modelData.icon).includes("symbolic")

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 22
            implicitHeight: 20
            radius: Globals.radius
            color: idTrayItem.isPressed ? Colors.surface : idTrayItem.isHovered ? Colors.backgroundSecondary : "transparent"

            QsMenuAnchor {
                id: idTrayMenuAnchor

                anchor.item: idTrayItem
                menu: idTrayItem.modelData.menu
            }

            IconImage {
                id: idTrayItemIcon

                anchors.centerIn: parent
                implicitSize: 14
                width: 14
                height: 14
                source: idTrayItem.modelData.icon
                // Hidden because MultiEffect below re-renders it; leaving it
                // visible would draw every icon twice.
                visible: false
            }

            MultiEffect {
                id: idTrayItemEffect

                anchors.fill: idTrayItemIcon
                source: idTrayItemIcon
                colorization: idTrayItem.isSymbolicIcon ? 1.0 : 0.0
                colorizationColor: Colors.text
            }

            MouseArea {
                id: idTrayItemMouseArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    switch (mouse.button) {
                    case Qt.LeftButton:
                        // onlyMenu items have no activation action.
                        if (idTrayItem.modelData.onlyMenu && idTrayItem.modelData.hasMenu)
                            idTrayMenuAnchor.open();
                        else
                            idTrayItem.modelData.activate();
                        break;
                    case Qt.MiddleButton:
                        idTrayItem.modelData.secondaryActivate();
                        break;
                    case Qt.RightButton:
                        // Fall back to secondary activation for items
                        // without a menu.
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
