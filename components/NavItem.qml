pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property bool active: false
    property bool disabled: false

    signal clicked()

    readonly property bool hovered: idNavMouseArea.containsMouse && !root.disabled
    readonly property bool pressed: idNavMouseArea.containsPress

    implicitWidth: idNavLabel.implicitWidth + 2 * Globals.cardHPadding
    implicitHeight: idNavLabel.implicitHeight + 2 * Globals.fieldPadding
    scale: idNavPress.scale

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    Rectangle {
        id: idNavWash

        anchors.fill: parent

        radius: Globals.cardRadius
        color: Colors.cardSecondary
        opacity: root.active || root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.reducedMotion ? 0 : Globals.hoverMs
            }
        }
    }

    Rectangle {
        id: idNavEdge

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        width: Globals.armedEdgeWidth
        height: Math.max(0, root.height - 2 * Globals.fieldPadding)

        radius: Globals.armedEdgeWidth / 2
        color: Colors.accent
        visible: root.active
    }

    Text {
        id: idNavLabel

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Globals.cardHPadding
            rightMargin: Globals.cardHPadding
        }

        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: root.text
        color: root.disabled ? Colors.textSecondary : (root.active ? Colors.text : Colors.textSubtle)

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
            weight: root.active ? Font.DemiBold : Font.Normal
        }
    }

    PressScale {
        id: idNavPress

        pressed: root.pressed
        pressedScale: Globals.pressScaleRow
    }

    MouseArea {
        id: idNavMouseArea

        anchors.fill: parent
        enabled: !root.disabled
        hoverEnabled: true
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
