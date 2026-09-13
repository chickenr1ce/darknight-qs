pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

// StatusNotifier icons matching waybar sizing (14px icons, 10 spacing).
ModuleBox {
    id: root

    enableMouseArea: false
    visible: idTrayRepeater.count > 0

    Repeater {
        id: idTrayRepeater

        model: SystemTray.items

        delegate: Rectangle {
            id: idTrayItem

            Layout.alignment: Qt.AlignVCenter

            required property SystemTrayItem modelData

            readonly property bool isHovered: idTrayItemMouseArea.containsMouse
            readonly property bool isPressed: idTrayItemMouseArea.pressed

            // Symbolic icons render near-black on the dark bar, so tint them; full-color pass through untinted.
            readonly property bool isSymbolicIcon: String(idTrayItem.modelData.icon).includes("symbolic")

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
                    idPressFeedback.pulse();
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
