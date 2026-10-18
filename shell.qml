//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.dev
import qs.modules
import qs.windows
import qs.services
import "services/BarLayoutLogic.js" as BarLayoutLogic


ShellRoot {
    id: root

    Variants {
        id: idScreenVariants
        model: Quickshell.screens

        // qmllint disable uncreatable-type
        PanelWindow {
            id: idPanelWindow

            required property ShellScreen modelData
            property string monitorName: modelData ? modelData.name : ""

            screen: modelData

            implicitHeight: Globals.barHeight + Globals.barTopMargin
            color: "transparent"

            // Hyprland hides a Top layer mapped before a fullscreen window but
            // draws a panel mapped after it, so a dashboard opened over a game
            // would hang from a missing bar. Overlay draws above fullscreen.
            WlrLayershell.layer: PanelGrab.shownScreens.includes(idPanelWindow.modelData) ? WlrLayer.Overlay : WlrLayer.Top

            Component.onCompleted: PanelGrab.registerBar(idPanelWindow)
            Component.onDestruction: PanelGrab.unregisterBar(idPanelWindow)

            anchors {
                top: true
                left: true
                right: true
            }

            Rectangle {
                id: idSlab

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: Globals.barTopMargin
                    leftMargin: Globals.barSideMargin
                    rightMargin: Globals.barSideMargin
                }

                height: Globals.barHeight
                radius: Globals.slabRadius
                color: Colors.background

                readonly property real leftClusterEdge: idBarModules.layout.leftEnd + Globals.slabEdgePadding
                readonly property real rightClusterEdge: idBarModules.layout.rightStart + Globals.slabEdgePadding

                Rectangle {
                    id: idLeftHairline

                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 - idActiveWindow.width / 2 - Globals.spacing - width

                    width: 2
                    height: parent.height - 2 * Globals.hairlineVerticalInset
                    color: Colors.textSecondary
                    opacity: 0.5
                    visible: idActiveWindow.hasTitle && x >= idSlab.leftClusterEdge
                }

                Rectangle {
                    id: idRightHairline

                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 + idActiveWindow.width / 2 + Globals.spacing

                    width: 2
                    height: parent.height - 2 * Globals.hairlineVerticalInset
                    color: Colors.textSecondary
                    opacity: 0.5
                    visible: idActiveWindow.hasTitle && x + width <= idSlab.rightClusterEdge
                }
            }

            Item {
                id: idBarModules

                readonly property var slots: [idClockSlot, idWorkspacesSlot, idTraySlot, idCavaSlot, idMediaSlot, idAudioSlot, idNotificationsSlot, idPowerSlot]
                readonly property var widths: idBarModules.measure(slot => slot.implicitWidth)
                readonly property var visibleMap: idBarModules.measure(slot => slot.shown)
                readonly property var dragGeometry: ({ widths: idBarModules.widths, visible: idBarModules.visibleMap, spacing: Globals.spacing, width: idBarModules.width })
                readonly property Item armedSlot: idBarModules.slots.find(slot => slot.armed) ?? null
                readonly property var layout: BarLayoutLogic.positions(BarLayoutService.previewOrder, idBarModules.widths, idBarModules.visibleMap, Globals.spacing, idBarModules.width)

                anchors {
                    fill: parent
                    leftMargin: Globals.slabInset
                    rightMargin: Globals.slabInset
                    topMargin: Globals.barTopMargin
                }

                BarDropPreview {
                    id: idDropPreview

                    x: idBarModules.armedSlot !== null ? idBarModules.layoutX(idBarModules.armedSlot.key) : 0
                    width: idBarModules.armedSlot !== null ? idBarModules.armedSlot.width : 0
                    height: Globals.barHeight
                    active: idBarModules.armedSlot !== null
                }

                BarSlot {
                    id: idClockSlot

                    key: "clock"
                    x: idBarModules.slotX(idClockSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Clock {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                BarSlot {
                    id: idWorkspacesSlot

                    key: "workspaces"
                    x: idBarModules.slotX(idWorkspacesSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Workspaces {
                        monitorName: idPanelWindow.monitorName
                    }
                }

                BarSlot {
                    id: idTraySlot

                    key: "tray"
                    x: idBarModules.slotX(idTraySlot)
                    dragGeometry: idBarModules.dragGeometry

                    Tray {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                BarSlot {
                    id: idCavaSlot

                    key: "cava"
                    x: idBarModules.slotX(idCavaSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Cava {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                BarSlot {
                    id: idMediaSlot

                    key: "media"
                    x: idBarModules.slotX(idMediaSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Media {
                        monitorName: idPanelWindow.monitorName
                    }
                }

                BarSlot {
                    id: idAudioSlot

                    key: "audio"
                    x: idBarModules.slotX(idAudioSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Audio {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                BarSlot {
                    id: idNotificationsSlot

                    key: "notifications"
                    x: idBarModules.slotX(idNotificationsSlot)
                    dragGeometry: idBarModules.dragGeometry

                    Notifications {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                BarSlot {
                    id: idPowerSlot

                    key: "power"
                    x: idBarModules.slotX(idPowerSlot)
                    dragGeometry: idBarModules.dragGeometry

                    PowerMenu {
                        monitorName: idPanelWindow.monitorName
                        triggerScreen: idPanelWindow.modelData
                    }
                }

                function measure(pick) {
                    const out = {};
                    for (let i = 0; i < idBarModules.slots.length; i++)
                        out[idBarModules.slots[i].key] = pick(idBarModules.slots[i]);
                    return out;
                }

                function defersDismissAt(x, y) {
                    for (let i = 0; i < idBarModules.slots.length; i++) {
                        const slot = idBarModules.slots[i];
                        if (slot.shown && !(slot.key === "tray") && x >= slot.x && x < slot.x + slot.width && y >= slot.y && y < slot.y + slot.height)
                            return true;
                    }
                    return false;
                }

                function layoutX(key) {
                    const x = idBarModules.layout.x[key];
                    return Number.isFinite(x) ? x : 0;
                }

                function slotX(slot) {
                    if (BarLayoutService.dragging && slot.armed)
                        return BarLayoutLogic.dragX(BarLayoutService.pointerX, slot.width, idBarModules.width);
                    return idBarModules.layoutX(slot.key);
                }
            }

            ActiveWindow {
                id: idActiveWindow

                triggerScreen: idPanelWindow.modelData

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: Globals.barTopMargin / 2
                }
            }

            MouseArea {
                id: idBarDismissArea

                anchors.fill: parent
                z: 100
                acceptedButtons: Qt.AllButtons
                onPressed: mouse => {
                    const point = idBarModules.mapFromItem(idBarDismissArea, mouse.x, mouse.y);
                    if (!idBarModules.defersDismissAt(point.x, point.y))
                        TrayMenuService.dismiss();
                    mouse.accepted = false;
                }
            }
        }
    }

    NotificationPopups {}

    VolumeOsd {}

    DashboardCenter {}

    NotificationCenter {}

    CalendarCenter {}

    CavaCenter {}

    AudioCenter {}

    PowerCenter {}

    TrayMenu {}

    PolkitDialog {}

    DevProbe {}
}

