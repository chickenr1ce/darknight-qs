pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// The fill always shows the true state; hover never touches it, so a resting
// cursor can't mask on/off. probeHovered is the toast's hover routing, where
// the topmost decay-pause probe captures all hover above the pills.
Item {
    id: root

    property string text: ""
    property string accessibleName: ""
    property color baseColor: Colors.cardSecondary
    property color highlightColor: Colors.accent
    property bool highlighted: false
    property bool probeHovered: false
    // Disabled pills keep their slot but go inert, so the header never reflows.
    property bool disabled: false
    property bool quiet: false
    // Ghost pills carry no resting fill; hover or an active state reveals one.
    property bool ghost: false
    // Subtle active state: a dim accent tint with an accent glyph, not a solid fill.
    property bool subtle: false
    // Optional leading icon-font glyph (qs.config Icons).
    property string icon: ""
    property int iconSize: Globals.uiPillSize
    // Measured optical nudge for a glyph whose ink sits off its advance centre.
    property int iconNudge: 0
    // Optional cap on the label width; 0 keeps the label at its natural width.
    property int maxLabelWidth: 0

    readonly property bool hovered: idMouseArea.containsMouse || root.probeHovered
    readonly property bool pressed: idMouseArea.containsPress

    signal clicked()

    implicitWidth: idPillContent.implicitWidth + (root.quiet ? 2 * Globals.quietButtonHPadding : 2 * Globals.pillHPadding)
    implicitHeight: idPillContent.implicitHeight + (root.quiet ? 2 * Globals.quietButtonVPadding : 2 * Globals.pillVPadding)
    scale: idPressScale.scale

    Accessible.role: Accessible.Button
    Accessible.name: !(root.accessibleName === "") ? root.accessibleName : root.text

    Rectangle {
        id: idPillBackground

        anchors.fill: parent

        visible: !root.quiet && (!root.ghost || root.hovered || root.highlighted)
        radius: Globals.pillRadius
        color: root.disabled ? root.baseColor : (root.highlighted ? (root.subtle ? Colors.accentDim : root.highlightColor) : root.baseColor)
        border.width: !root.disabled && root.hovered ? 1 : 0
        border.color: root.highlighted ? (root.subtle ? Colors.accent : Colors.onAccent) : Colors.accent
    }

    Row {
        id: idPillContent

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.iconNudge
        spacing: (!(root.icon === "") && !(root.text === "")) ? 5 : 0

        Icon {
            id: idPillIcon

            visible: !(root.icon === "")

            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: root.iconSize
            color: idLabel.color
        }

        Text {
            id: idLabel

            anchors.verticalCenter: parent.verticalCenter

            width: root.maxLabelWidth > 0 ? Math.min(implicitWidth, root.maxLabelWidth) : implicitWidth
            elide: root.maxLabelWidth > 0 ? Text.ElideRight : Text.ElideNone
            textFormat: Text.PlainText
            text: root.text
            color: !root.disabled && root.highlighted ? ((root.quiet || root.subtle) ? Colors.accent : Colors.onAccent) : (!root.disabled && root.hovered ? Colors.text : Colors.textSubtle)

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiPillSize
                weight: Font.Medium
            }
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
}
