pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Shared action-pill button (review extraction, tickets 02/03): the
// label + 16/+6 inset, radius-4 pill previously hand-copied across the
// toast, notification card, accordion header and center header.
//
// State visibility (option B, 2026-09-12): the fill always shows the true
// state — `highlightColor` when `highlighted`, `baseColor` otherwise — and
// hover NEVER touches the fill, so a resting cursor can't mask on/off.
// Hover only draws a contrasting ring and brightens the label; press adds
// the Phase 6a squash (PressScale at the pill magnitude).
//
// `highlightColor` lets destructive actions swap lavender for red.
// `probeHovered` is the toast's hover routing: its topmost decay-pause probe
// captures all hover events above the pills beneath it, so the toast binds
// this from probe-relative geometry. Everywhere else the pill's own MouseArea
// delivers hover directly; either path feeds `hovered`.
Rectangle {
    id: root

    property string text: ""
    property color baseColor: Colors.backgroundSecondary
    property color highlightColor: Colors.lavender
    property bool highlighted: false
    property bool probeHovered: false
    // Disabled pills keep their layout slot but go inert and dim: used for
    // Clear All when history is empty, so the header never reflows.
    property bool disabled: false

    readonly property bool hovered: idMouseArea.containsMouse || root.probeHovered
    readonly property bool pressed: idMouseArea.containsPress

    signal clicked()

    implicitWidth: idLabel.implicitWidth + 16
    implicitHeight: idLabel.implicitHeight + 6
    radius: 4
    color: !root.disabled && root.highlighted ? root.highlightColor : root.baseColor
    border.width: !root.disabled && root.hovered ? 1 : 0
    border.color: root.highlighted ? Colors.background : Colors.lavender
    scale: idPressScale.scale

    Text {
        id: idLabel

        anchors.centerIn: parent

        textFormat: Text.PlainText
        text: root.text
        color: !root.disabled && root.highlighted ? Colors.background : (!root.disabled && root.hovered ? Colors.text : Colors.textSubtle)

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
