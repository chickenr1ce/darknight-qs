pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Panel header: title plus count badge, actions slot on the right.
// Owners pass buttons as children; the inner row keeps them grouped and centered.
RowLayout {
    id: root

    property string title: ""
    property int badgeCount: 0
    property bool showBadge: false

    default property alias actions: idHeaderActions.data

    spacing: 8

    Text {
        id: idHeaderTitle

        textFormat: Text.PlainText
        text: root.title
        color: Colors.text

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiTitleSize
            weight: Font.DemiBold
        }
    }

    Rectangle {
        id: idHeaderBadge

        Layout.preferredWidth: Math.max(idHeaderBadgeLabel.implicitWidth + 12, 18)
        Layout.preferredHeight: idHeaderBadgeLabel.implicitHeight + 4
        Layout.alignment: Qt.AlignVCenter

        visible: root.showBadge && root.badgeCount > 0
        radius: height / 2
        color: Colors.accent

        Text {
            id: idHeaderBadgeLabel

            anchors.centerIn: parent

            textFormat: Text.PlainText
            text: root.badgeCount
            color: Colors.onAccent

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.DemiBold
            }
        }
    }

    Item {
        id: idHeaderSpacer

        Layout.fillWidth: true
        Layout.minimumWidth: 0
    }

    RowLayout {
        id: idHeaderActions

        Layout.alignment: Qt.AlignVCenter

        spacing: 8
    }
}
