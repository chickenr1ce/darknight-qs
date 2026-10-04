pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Shared dismiss/action control; glyphSize sets the glyph, the hit box follows
// with equal padding. probeHovered routes hover when a topmost probe captures it.
Item {
    id: root

    property string glyph: Icons.close
    property bool probeHovered: false
    property bool disabled: false
    property string accessibleName: qsTr("Close")
    property int glyphSize: Globals.uiBodySize
    property color restColor: Colors.textSecondary

    signal clicked()

    readonly property bool hovered: idButtonMouseArea.containsMouse || root.probeHovered

    enabled: !root.disabled
    implicitWidth: root.glyphSize + 2 * Globals.iconButtonPadding
    implicitHeight: root.glyphSize + 2 * Globals.iconButtonPadding

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName

    Icon {
        id: idButtonGlyph

        anchors.centerIn: parent

        text: root.glyph
        size: root.glyphSize
        // Dim tone is fine: the glyph is decorative, never read.
        color: root.disabled ? Colors.textFaint : (root.hovered ? Colors.text : root.restColor)
    }

    MouseArea {
        id: idButtonMouseArea

        anchors.fill: parent
        enabled: !root.disabled
        hoverEnabled: true
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
