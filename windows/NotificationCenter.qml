pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    property var expandedGroups: ({})
    property string pendingScrollApp: ""

    panel: NotificationServer.panelState

    function toggleGroup(appName: string) {
        const expanding = root.expandedGroups[appName] !== true;
        const next = Object.assign({}, root.expandedGroups);
        next[appName] = next[appName] !== true;
        root.expandedGroups = next;
        if (expanding) {
            root.pendingScrollApp = appName;
            idExpandScrollTimer.restart();
        }
    }

    function ensureGroupVisible(appName: string) {
        root.pendingScrollApp = "";
        if (appName === "" || root.expandedGroups[appName] !== true)
            return;
        const index = NotificationServer.groups.findIndex(group => group.appName === appName);
        if (index < 0)
            return;
        const delegate = idGroupsRepeater.itemAt(index);
        const viewHeight = idGroupsFlickable.height;
        if (!delegate || !(viewHeight > 0))
            return;
        // qmllint disable missing-property
        const finalHeight = delegate.expandedTargetHeight;
        const bottom = delegate.y + finalHeight;
        const finalContent = idGroupsFlickable.contentHeight - delegate.height + finalHeight;
        const maxY = Math.max(0, finalContent - viewHeight);
        let destination = idGroupsFlickable.contentY;
        if (bottom > destination + viewHeight)
            destination = bottom - viewHeight;
        if (delegate.y < destination)
            destination = delegate.y;
        idGroupsSmoothWheel.stop();
        idScrollAnimator.to = Math.max(0, Math.min(destination, maxY));
        idScrollAnimator.restart();
    }

    readonly property int groupsScrollMax: Math.max(Globals.bodyScrollMin,
        Globals.centerMaxHeight - 2 * Globals.panelPadding - idCenterHeader.implicitHeight - Globals.spacing)

    PanelHeader {
        id: idCenterHeader

        title: qsTr("Notifications")
        badgeCount: NotificationServer.unreadCount
        showBadge: true

        PillButton {
            id: idDndButton

            Layout.alignment: Qt.AlignVCenter

            quiet: true
            text: qsTr("DND")
            highlighted: NotificationServer.dndEnabled
            onClicked: NotificationServer.toggleDnd()
        }

        PillButton {
            id: idClearAllButton

            Layout.alignment: Qt.AlignVCenter

            quiet: true
            disabled: NotificationServer.unreadCount === 0
            text: qsTr("Clear All")
            onClicked: NotificationServer.dismissAll()
        }
    }

    Text {
        id: idEmptyState

        Layout.fillWidth: true
        Layout.preferredHeight: 60

        visible: NotificationServer.notifications.count === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        textFormat: Text.PlainText
        text: qsTr("No notifications")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
        }
    }

    Timer {
        id: idExpandScrollTimer

        interval: 0
        repeat: false
        onTriggered: root.ensureGroupVisible(root.pendingScrollApp)
    }

    NumberAnimation {
        id: idScrollAnimator

        target: idGroupsFlickable
        property: "contentY"
        duration: Globals.reducedMotion ? 0 : Globals.centerOpenMs
        easing.type: Easing.OutCubic
    }

    Item {
        id: idGroupsSlot

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(idGroupsColumn.implicitHeight, root.groupsScrollMax)
        Layout.maximumHeight: root.groupsScrollMax

        visible: NotificationServer.notifications.count > 0

        Flickable {
            id: idGroupsFlickable

            anchors.fill: parent

            contentWidth: width
            contentHeight: idGroupsColumn.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: ScrollBar { id: idGroupsScrollBar }

            Column {
                id: idGroupsColumn

                width: idGroupsFlickable.width - Globals.scrollbarWidth

                spacing: Globals.rowSpacing

                Repeater {
                    id: idGroupsRepeater

                    model: NotificationServer.groups

                    delegate: NotificationGroup {
                        required property var modelData

                        appName: modelData.appName
                        notifications: modelData.notifications
                        expanded: root.expandedGroups[modelData.appName] === true
                        onToggleRequested: root.toggleGroup(modelData.appName)
                    }
                }
            }
        }

        SmoothWheel {
            id: idGroupsSmoothWheel

            flickable: idGroupsFlickable
            onWheelStarted: idScrollAnimator.stop()
        }
    }
}
