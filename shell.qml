//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules

// Quickshell panel config.
// One PanelWindow per connected screen (Variants over Quickshell.screens).
// Left:  Clock, Workspaces
// Center: ActiveWindow (focused client title, all outputs)
// Right: Mpris, Audio, Cpu, Notifications, Tray, PowerMenu (DP-1 only for now)
// Visualizer lands in a later pass.

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

            // Unified slab — one full-width surface behind all regions
            // (Phase 6a, D-01). Floating placement per D-06; modules render
            // transparently on top of it.
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

                // Side-cluster footprints in slab coordinates. idSpacer.x is
                // measured in idBarLayout coordinates; converting to slab
                // coordinates: layout adds Globals.slabInset of panel inset
                // while the slab itself is inset horizontalBarMargin, leaving
                // a net +slabEdgePadding.
                readonly property real leftClusterEdge: idSpacer.x + Globals.slabEdgePadding
                readonly property real rightClusterEdge: idSpacer.x + idSpacer.width + Globals.slabEdgePadding

                // Cluster hairlines flanking the center ActiveWindow region
                // only (D-07). Children of the slab so they never participate
                // in hover. Track idActiveWindow's width to stay clear of it,
                // and hide rather than collide with side modules on narrow
                // bars or when the center region is empty.
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

                // Left cluster
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

                // Right cluster (full bar only)
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

            // Center module — anchored to the bar itself so it stays in the
            // exact horizontal center regardless of side-cluster widths
            // (mirrors waybar's absolutely-positioned center section). May
            // overlap edge modules on very long titles, same as waybar.
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
}
