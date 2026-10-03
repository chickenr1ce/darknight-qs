pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config

// Shared selectable background thumbnail: cropped art with a selected ring and
// a check badge, plus hover and press feedback.
ClippingRectangle {
    id: root

    property string source: ""
    property string accessibleName: ""
    property bool active: false

    signal clicked()

    implicitWidth: Math.round(Globals.backgroundTileHeight * 16 / 9)
    implicitHeight: Globals.backgroundTileHeight

    radius: Globals.cardRadius
    color: Colors.cardSecondary
    border.width: Globals.hairlineHeight
    border.color: root.active || idTileMouseArea.containsMouse ? Colors.accent : Colors.border
    scale: idTilePressScale.scale

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.selected: root.active

    Image {
        id: idTileImage

        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.max(1, Math.round(root.implicitWidth)) * 2
        sourceSize.height: Math.max(1, Math.round(root.implicitHeight)) * 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready

        Accessible.ignored: true
    }

    Rectangle {
        id: idTileCheckBackdrop

        anchors {
            top: parent.top
            right: parent.right
            margins: Globals.fieldPadding
        }

        width: Globals.uiCaptionSize + 2 * Globals.fieldPadding
        height: width
        radius: width / 2
        color: Colors.card
        opacity: 0.85
        visible: root.active

        Icon {
            id: idTileCheck

            anchors.centerIn: parent

            text: Icons.check
            size: Globals.uiCaptionSize
            color: Colors.accent

            Accessible.ignored: true
        }
    }

    PressScale {
        id: idTilePressScale

        pressed: idTileMouseArea.pressed
        pressedScale: Globals.pressScalePill
    }

    MouseArea {
        id: idTileMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
