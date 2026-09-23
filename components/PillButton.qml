pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// The fill always shows the true state; hover never touches it, so a resting
// cursor can't mask on/off. probeHovered is the toast's hover routing, where
// the topmost decay-pause probe captures all hover above the pills.
Item {
    id: root

    property string text: ""
    property color baseColor: Colors.cardSecondary
    property color highlightColor: Colors.accent
    property bool highlighted: false
    property bool probeHovered: false
    // Disabled pills keep their slot but go inert, so the header never reflows.
    property bool disabled: false
    property bool quiet: false

    readonly property bool hovered: idMouseArea.containsMouse || root.probeHovered
    readonly property bool pressed: idMouseArea.containsPress

    signal clicked()

    implicitWidth: idLabel.implicitWidth + (root.quiet ? 2 * Globals.quietButtonHPadding : 2 * Globals.pillHPadding)
    implicitHeight: idLabel.implicitHeight + (root.quiet ? 2 * Globals.quietButtonVPadding : 2 * Globals.pillVPadding)
    scale: idPressScale.scale

    Rectangle {
        id: idPillBackground

        anchors.fill: parent

        visible: !root.quiet
        radius: Globals.pillRadius
        color: !root.disabled && root.highlighted ? root.highlightColor : root.baseColor
        border.width: !root.disabled && root.hovered ? 1 : 0
        border.color: root.highlighted ? Colors.onAccent : Colors.accent
    }

    Text {
        id: idLabel

        anchors.centerIn: parent

        textFormat: Text.PlainText
        text: root.text
        color: !root.disabled && root.highlighted ? Colors.onAccent : (!root.disabled && root.hovered ? Colors.text : Colors.textSubtle)

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiPillSize
            weight: Font.Medium
        }
    }

    PressScale {
        id: idPressScale

        pressed: root.pressed
        pressedScale: Globals.pressScalePill
    }

    MouseArea {
        id: idMouseArea

        anchors.fill: parent
        enabled: !root.disabled
        hoverEnabled: true
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.text
}
