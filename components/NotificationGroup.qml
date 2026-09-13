pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// Aliased: the bare name resolves to the C++ type, shadowing the singleton (conventions §4).
import Quickshell.Services.Notifications as Notif
import qs.components
import qs.config
import qs.services

// Collapsible per-app accordion; expansion state lives in the owner because history rebuilds would reset a local flag.
// Height animates with clip while siblings snap (no displaced-style fix exists for sibling height changes).
Rectangle {
    id: root

    required property string appName
    required property var notifications // Notification[]

    property bool expanded: false

    signal toggleRequested()

    readonly property int headerHeight: 34

    implicitWidth: parent ? parent.width : 0
    implicitHeight: headerHeight
        + (expanded ? idContentColumn.implicitHeight + 8 : 0)

    radius: 6
    color: Colors.backgroundSecondary
    border.width: 1
    border.color: Colors.surface
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Globals.centerOpenMs
            easing.type: Easing.OutCubic
        }
    }

    // Under the header controls so Clear keeps its clicks; toggles expansion only.
    MouseArea {
        id: idHeaderClickArea

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4

        height: root.headerHeight - 8
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }

    RowLayout {
        id: idHeaderRow

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8

        height: root.headerHeight - 16

        spacing: 8

        Text {
            id: idAppGlyph

            Layout.preferredWidth: 18

            textFormat: Text.PlainText
            text: root.appName !== "" ? root.appName.charAt(0).toUpperCase() : "?"
            color: Colors.lavender

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiTitleSize
                weight: Font.DemiBold
            }
        }

        Text {
            id: idAppTitle

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight

            text: qsTr("%1 (%2)").arg(root.appName !== "" ? root.appName : qsTr("Unknown")).arg(root.notifications.length)
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        PillButton {
            id: idClearButton

            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter

            visible: root.notifications.length > 0
            text: qsTr("Clear")
            baseColor: Colors.background
            highlightColor: Colors.red
            onClicked: NotificationServer.dismissGroup(root.appName)
        }

        Text {
            id: idChevron

            Layout.preferredWidth: 14

            textFormat: Text.PlainText
            text: root.expanded ? "▾" : "▸"
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }
    }

    Column {
        id: idContentColumn

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.headerHeight + 2
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        spacing: 6
        visible: root.expanded

        Repeater {
            model: root.notifications

            delegate: NotificationCard {
                required property Notif.Notification modelData

                notification: modelData
            }
        }
    }
}
