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

            RowLayout {
                id: idBarLayout

                spacing: Globals.spacing

                anchors {
                    fill: parent
                    leftMargin: Globals.horizontalBarMargin
                    rightMargin: Globals.horizontalBarMargin
                    topMargin: Globals.moduleMargin
                }

                // Left cluster
                Clock {}
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
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: Globals.moduleMargin / 2
                }
            }
        }
    }
}
