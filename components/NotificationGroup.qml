pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// Aliased: the bare name `NotificationServer` must resolve to our
// qs.services singleton (dismissGroup lives there). An unaliased import of
// this module exposes quickshell's C++ NotificationServer type under the
// same name, which shadows the singleton and breaks per-app clearing at
// runtime (TypeError, click silently dies). Only the delegate's role type
// needs this module.
import Quickshell.Services.Notifications as Notif
import qs.components
import qs.config
import qs.services

// Collapsible per-app accordion (ticket 03, frozen decision 2A): header with
// app glyph, title + count badge, chevron and a "Clear" button; content is
// one NotificationCard per tracked notification of that app.
//
// Expansion state lives in the owner (windows/NotificationCenter.qml), not
// here: the grouped model rebuilds whenever history changes, which would
// reset a locally-stored flag. This component only reports toggleRequested().
//
// Height animation note: the accordion animates its own height with clip;
// Column siblings below snap to their new position instantly (Column
// repositioning bypasses Behavior — docs/coding-conventions.md §4). At 140ms
// the gap-close is imperceptible; a displaced-style fix does not exist for
// sibling height changes.
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

    // Header hit area sits UNDER the header controls (declaration order =
    // z-order) so Clear keeps its own clicks; it only toggles expansion.
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
