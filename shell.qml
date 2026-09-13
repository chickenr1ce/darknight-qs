pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules
import qs.windows

// One PanelWindow per screen; ActiveWindow stays centered, and the right cluster (DP-1 only)
// holds Media, Audio, Cpu, Notifications, Tray, PowerMenu.

ShellRoot {
    id: root

    Variants {
        id: idScreenVariants
        model: Quickshell.screens

        // qmllint disable uncreatable-type
        PanelWindow {
            id: idPanelWindow

            required property ShellScreen modelData
            property string monitorName: modelData.name

            screen: modelData

            implicitHeight: Globals.barHeight + Globals.moduleMargin
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }

            // One full-width surface behind all regions; modules render transparently on top.
            Rectangle {
                id: idSlab

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: Globals.moduleMargin
                    leftMargin: Globals.horizontalBarMargin
                    rightMargin: Globals.horizontalBarMargin
                }

                height: Globals.barHeight
                radius: Globals.slabRadius
                color: Colors.background

                // idSpacer is measured in layout coordinates; +slabEdgePadding converts to slab coordinates.
                readonly property real leftClusterEdge: idSpacer.x + Globals.slabEdgePadding
                readonly property real rightClusterEdge: idSpacer.x + idSpacer.width + Globals.slabEdgePadding

                // Flank the center region only; hidden rather than colliding with side modules on narrow bars.
                Rectangle {
                    id: idLeftHairline

                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 - idActiveWindow.width / 2 - Globals.spacing - width

                    width: 2
                    height: parent.height - 2 * Globals.hairlineVerticalInset
                    color: Colors.textSecondary
                    opacity: 0.5
                    visible: idActiveWindow.visible && x >= idSlab.leftClusterEdge
                }

                Rectangle {
                    id: idRightHairline

                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width / 2 + idActiveWindow.width / 2 + Globals.spacing

                    width: 2
                    height: parent.height - 2 * Globals.hairlineVerticalInset
                    color: Colors.textSecondary
                    opacity: 0.5
                    visible: idActiveWindow.visible && x + width <= idSlab.rightClusterEdge
                }
            }

            RowLayout {
                id: idBarLayout

                spacing: Globals.spacing

                anchors {
                    fill: parent
                    leftMargin: Globals.slabInset
                    rightMargin: Globals.slabInset
                    topMargin: Globals.moduleMargin
                }

                Clock {
                    enableHover: false
                    enableMouseArea: false
                }
                Workspaces {
                    monitorName: idPanelWindow.monitorName
                }
                Tray {
                    visible: idPanelWindow.monitorName === "DP-1"
                }

                Item {
                    id: idSpacer
                    Layout.fillWidth: true
                }

                Media {
                    visible: idPanelWindow.monitorName === "DP-1"
                }
                Audio {
                    visible: idPanelWindow.monitorName === "DP-1"
                }
                Cpu {
                    visible: idPanelWindow.monitorName === "DP-1"
                }
                Notifications {
                    visible: idPanelWindow.monitorName === "DP-1"
                }

                PowerMenu {
                    visible: idPanelWindow.monitorName === "DP-1"
                }
            }

            // Stays centered regardless of side widths; may overlap edge modules on very long titles (as in waybar).
            ActiveWindow {
                id: idActiveWindow

                enableHover: false
                enableMouseArea: false

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: Globals.moduleMargin / 2
                }
            }
        }
    }

    NotificationPopups {}

    NotificationCenter {}
}
