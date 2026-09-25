pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    property int activeIndex: 0

    readonly property var tabs: [qsTr("Dashboard"), qsTr("Media"), qsTr("Performance"), qsTr("Workspaces")]

    spacing: Globals.rowSpacing

    Repeater {
        id: idTabsRepeater

        model: root.tabs

        delegate: ColumnLayout {
            id: idTabColumn

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            required property string modelData
            required property int index

            readonly property bool isActive: index === root.activeIndex

            spacing: Globals.dayCellGap

            Text {
                id: idTabLabel

                Layout.fillWidth: true

                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idTabColumn.modelData
                color: idTabColumn.isActive ? Colors.text : Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                    weight: idTabColumn.isActive ? Font.DemiBold : Font.Normal
                }
            }

            Rectangle {
                id: idTabUnderline

                Layout.fillWidth: true
                Layout.preferredHeight: Globals.armedEdgeWidth

                visible: idTabColumn.isActive
                radius: Globals.armedEdgeWidth / 2
                color: Colors.accent
            }
        }
    }
}
