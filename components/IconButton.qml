pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Shared 18px dismiss control; probeHovered routes hover when a topmost probe captures it.
Item {
    id: root

    property string glyph: "✕"
    property bool probeHovered: false
    property string accessibleName: qsTr("Close")

    signal clicked()

    readonly property bool hovered: idButtonMouseArea.containsMouse || root.probeHovered

    implicitWidth: 18
    implicitHeight: 18

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName

    Text {
        id: idButtonGlyph

        anchors.centerIn: parent

        textFormat: Text.PlainText
        text: root.glyph
        // Dim tone is fine: the glyph is decorative, never read.
        color: root.hovered ? Colors.text : Colors.textSecondary

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
        }
    }

    MouseArea {
        id: idButtonMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
