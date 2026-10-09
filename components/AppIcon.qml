pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Shared app artwork: the resolved icon when there is one, else a tinted
// letter tile (or a glyph tile when the caller supplies one, e.g. the
// launcher's Run row). The launcher row and the settings row both compose it.
Item {
    id: root

    property string source: ""
    property string name: ""
    property string glyph: ""
    property int size: Globals.appIconSize
    property color tileColor: Colors.appColor(root.name)

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: idAppIconImage

        anchors.fill: parent

        visible: root.source !== ""
        source: root.source
        sourceSize.width: root.size
        sourceSize.height: root.size
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Rectangle {
        id: idAppIconTile

        anchors.fill: parent

        visible: root.source === ""
        radius: Globals.cardRadius
        color: root.tileColor

        Icon {
            id: idAppIconGlyph

            anchors.centerIn: parent

            visible: root.glyph !== ""
            text: root.glyph
            size: Globals.uiBodySize
            color: Colors.textSubtle
        }

        Text {
            id: idAppIconLetter

            anchors.centerIn: parent

            visible: root.glyph === ""
            textFormat: Text.PlainText
            text: root.name ? root.name.charAt(0).toUpperCase() : "?"
            color: Colors.tileInk

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.DemiBold
            }
        }
    }
}
