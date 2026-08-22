pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "config"
import "modules"

// Quickshell panel config.
// One PanelWindow per connected screen (Variants over Quickshell.screens).
// Left:  Clock, Workspaces
// Center: ActiveWindow (focused client title, all outputs)
// Right: Mpris, Audio, Cpu, Notifications, PowerMenu  (DP-1 only for now)
// Tray / visualizer land in a later pass.

ShellRoot {
    id: root

    Variants {
        id: idScreenVariants
        model: Quickshell.screens

        // qmllint disable uncreatable-type
        PanelWindow {
            id: idPanelWindow

            required property var modelData
            screen: modelData
            property string monitorName: modelData.name

            anchors.top: true
            anchors.left: true
            anchors.right: true

            implicitHeight: Globals.barHeight + Globals.moduleMargin
            color: "transparent"

            RowLayout {
                id: idBarLayout

                anchors.fill: parent
                anchors.leftMargin: Globals.horizontalBarMargin
                anchors.rightMargin: Globals.horizontalBarMargin
                anchors.topMargin: Globals.moduleMargin

                spacing: Globals.spacing

                // Left cluster
                Clock {}
                Workspaces {
                    monitorName: idPanelWindow.monitorName
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
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                // RowLayout content sits below topMargin; offset by half of it
                // so this box lines up with the other modules.
                anchors.verticalCenterOffset: Globals.moduleMargin / 2
            }
        }
    }
}
