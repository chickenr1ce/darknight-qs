pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

RowLayout {
    id: root

    spacing: Globals.rowSpacing

    Repeater {
        id: idTabsRepeater

        model: DashboardService.tabs

        delegate: Item {
            id: idTab

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            required property var modelData

            readonly property bool isActive: idTab.modelData.key === DashboardService.activeTab
            readonly property bool hovered: idTabMouse.containsMouse && !idTab.isActive

            implicitHeight: idTabColumn.implicitHeight

            Accessible.role: Accessible.Button
            Accessible.name: idTab.modelData.title

            ColumnLayout {
                id: idTabColumn

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                spacing: Globals.dayCellGap

                Text {
                    id: idTabLabel

                    Layout.fillWidth: true

                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: idTab.modelData.title
                    color: idTab.isActive || idTab.hovered ? Colors.text : Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                        weight: idTab.isActive ? Font.DemiBold : Font.Normal
                    }
                }

                Rectangle {
                    id: idTabUnderline

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.armedEdgeWidth

                    opacity: idTab.isActive ? 1 : 0
                    radius: Globals.armedEdgeWidth / 2
                    color: Colors.accent
                }
            }

            MouseArea {
                id: idTabMouse

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DashboardService.selectTab(idTab.modelData.key)
            }
        }
    }
}
