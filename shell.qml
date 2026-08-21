pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "config"
import "modules"

// Quickshell panel config.
// One PanelWindow per connected screen (Variants over Quickshell.screens).
// Left:  Clock (+ monitor name placeholder)
// Right: Mpris, Audio, Cpu, Notifications, PowerMenu  (DP-1 only for now)
// Workspaces / People / Tray / visualizer land in a later pass.

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
                spacing: Globals.moduleMargin

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
        }
    }
}
