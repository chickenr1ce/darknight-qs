//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules
import qs.windows


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

                readonly property real leftClusterEdge: idSpacer.x + Globals.slabEdgePadding
                readonly property real rightClusterEdge: idSpacer.x + idSpacer.width + Globals.slabEdgePadding

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
                    monitorName: idPanelWindow.monitorName
                    triggerScreen: idPanelWindow.modelData
                }
                Workspaces {
                    monitorName: idPanelWindow.monitorName
                }
                Tray {
                    monitorName: idPanelWindow.monitorName
                }

                Item {
                    id: idSpacer
                    Layout.fillWidth: true
                }

                Cava {
                    monitorName: idPanelWindow.monitorName
                    triggerScreen: idPanelWindow.modelData
                }
                Media {
                    monitorName: idPanelWindow.monitorName
                }
                Audio {
                    monitorName: idPanelWindow.monitorName
                }
                Notifications {
                    monitorName: idPanelWindow.monitorName
                    triggerScreen: idPanelWindow.modelData
                }

                PowerMenu {
                    monitorName: idPanelWindow.monitorName
                    triggerScreen: idPanelWindow.modelData
                }
            }

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

    CalendarCenter {}

    CavaCenter {}

    PowerCenter {}
}
