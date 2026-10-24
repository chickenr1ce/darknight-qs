pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// StatusNotifier icons matching waybar sizing (14px icons, 10 spacing).
ModuleBox {
    id: root

    property string monitorName: ""
    property ShellScreen triggerScreen: null
    // The bar defers its tray-menu dismiss to this module's release: the menu
    // belongs to the icon the press lands on.
    readonly property bool ownsTrayMenu: true
    enableMouseArea: false
    visible: BarVisibilityService.isVisible("tray") && Globals.onPrimaryMonitor(root.monitorName) && idTrayRepeater.count > 0

    // Activate alone never raises Ayatana windows, so focus too; harmless where Activate already did.
    function focusAppWindow(item): bool {
        if (!item)
            return false;
        return HyprlandFocus.focusByTokens([item.id, item.title, item.tooltipTitle]);
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

            // Tint theme glyphs; pixmaps and app-file fallbacks keep their own colors.
            readonly property string iconSource: String(idTrayItem.modelData.icon)
            readonly property string themeIconName: idTrayItem.iconSource.startsWith("image://icon/") ? idTrayItem.iconSource.slice("image://icon/".length).split("?")[0] : ""
            readonly property bool isThemedIcon: idTrayItem.themeIconName !== "" && Quickshell.iconPath(idTrayItem.themeIconName, true) !== ""

            implicitWidth: Globals.trayIconWidth
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
                    switch (mouse.button) {
                    case Qt.LeftButton:
                        // onlyMenu items have no activation action.
                        if (idTrayItem.modelData.onlyMenu && idTrayItem.modelData.hasMenu) {
                            idTrayItem.toggleMenu();
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
                            idTrayItem.toggleMenu();
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

            function toggleMenu(): void {
                TrayMenuService.toggleFor(idTrayItem.modelData, root.triggerScreen, Globals.triggerCenterX(idTrayItem, root.triggerScreen));
            }
        }
    }
}
