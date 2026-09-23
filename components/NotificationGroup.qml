pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// Aliased: the bare name resolves to the C++ type, shadowing the singleton (conventions §4).
import Quickshell.Services.Notifications as Notif
import qs.components
import qs.config
import qs.services

Item {
    id: root

    required property string appName
    required property var notifications // history entries

    property bool expanded: false
    property real relativeTimeNow: Date.now()

    signal toggleRequested()

    onExpandedChanged: {
        if (root.expanded)
            root.relativeTimeNow = Date.now();
    }

    readonly property int headerHeight: Globals.headerHeight
    readonly property bool hasCritical: {
        for (let i = 0; i < root.notifications.length; i++) {
            const notification = root.notifications[i].notification;
            if (notification !== null && notification.urgency === Notif.NotificationUrgency.Critical)
                return true;
        }
        return false;
    }
    readonly property color groupColor: root.hasCritical ? Colors.danger : Colors.appColor(root.appName)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: headerHeight
        + (expanded ? idContentColumn.implicitHeight + 8 : 0)

    clip: true

    Behavior on implicitHeight {
        enabled: !Globals.reducedMotion
        NumberAnimation {
            duration: Globals.centerOpenMs
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: idTimeTimer

        interval: 60000
        repeat: true
        running: root.expanded
        onTriggered: root.relativeTimeNow = Date.now()
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

    // Fixed 34px zone; the row takes its implicit height (tallest child, the
    // Clear pill) so nothing overflows the row, and centers in the full zone.
    Item {
        id: idHeaderZone

        height: root.headerHeight

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }

    TextMetrics {
        id: idAppCountMetrics

        font.family: Globals.uiFontFamily
        font.pixelSize: Globals.uiCaptionSize
        text: "88"
    }

    RowLayout {
        id: idHeaderRow

        spacing: 8

        // Explicit fractional margin, not a center anchor: (34-23)/2 must land
        // on 5.5, and the anchor rounds it down to 5 (measured live via IPC).
        anchors {
            top: idHeaderZone.top
            left: parent.left
            right: parent.right
            topMargin: (root.headerHeight - idHeaderRow.implicitHeight) / 2
            leftMargin: 8
            rightMargin: 8
        }

        Rectangle {
            id: idAppDot

            Layout.preferredWidth: Globals.appDotSize
            Layout.preferredHeight: Globals.appDotSize
            Layout.alignment: Qt.AlignVCenter

            radius: Globals.appDotSize / 2
            color: root.groupColor

            Accessible.ignored: true
        }

        Text {
            id: idAppName

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            text: root.appName !== "" ? root.appName.toUpperCase() : qsTr("Unknown").toUpperCase()
            color: root.groupColor

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiPillSize
                weight: Font.DemiBold
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        Text {
            id: idAppCount

            Layout.preferredWidth: Math.max(idAppCountMetrics.advanceWidth, idAppCount.implicitWidth)
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            text: root.notifications.length
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
            }
        }

        PillButton {
            id: idClearButton

            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter

            visible: root.notifications.length > 0
            quiet: true
            text: qsTr("Clear")
            onClicked: NotificationServer.dismissGroup(root.appName)
        }

        Text {
            id: idChevron

            Layout.preferredWidth: 14
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter

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

        spacing: 0
        visible: root.expanded

        Repeater {

            model: root.notifications

            delegate: NotificationRow {
                required property var modelData
                required property int index

                entry: modelData
                appColor: Colors.appColor(root.appName)
                relativeTimeNow: root.relativeTimeNow
                showDivider: index < root.notifications.length - 1
            }
        }
    }
}
