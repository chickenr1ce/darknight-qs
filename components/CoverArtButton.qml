pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config

// Shared clickable art tile: cropped cover art plus a music placeholder, with
// hover and press feedback.
ClippingRectangle {
    id: root

    property string source: ""
    property string accessibleName: ""
    property int artSize: Globals.playerArtSize

    signal clicked()

    implicitWidth: root.artSize
    implicitHeight: root.artSize

    radius: Globals.cardRadius
    color: Colors.cardSecondary
    border.width: Globals.hairlineHeight
    border.color: idArtMouseArea.containsMouse ? Colors.accent : Colors.border
    scale: idArtPressScale.scale

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName

    Image {
        id: idArtImage

        anchors.fill: parent
        source: root.source
        sourceSize.width: root.artSize * 2
        sourceSize.height: root.artSize * 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready

        Accessible.ignored: true
    }

    Icon {
        id: idArtPlaceholder

        anchors.centerIn: parent
        visible: idArtImage.status !== Image.Ready
        text: Icons.music
        size: Globals.uiDisplaySize
        color: Colors.textSecondary

        Accessible.ignored: true
    }

    PressScale {
        id: idArtPressScale

        pressed: idArtMouseArea.pressed
        pressedScale: Globals.pressScalePill
    }

    MouseArea {
        id: idArtMouseArea

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: root.clicked()
    }
}
