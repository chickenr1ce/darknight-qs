pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    anchorScreen: NotificationServer.anchorScreen
    anchorCenterX: NotificationServer.anchorCenterX

    panelVisible: NotificationServer.centerVisible

    property var expandedGroups: ({})
    property string pendingScrollApp: ""

    onOutsideClicked: NotificationServer.closeCenterFromOutside()

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
        const index = root.groups.findIndex(group => group.appName === appName);
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
        idScrollAnimator.to = Math.max(0, Math.min(destination, maxY));
        idScrollAnimator.restart();
    }

    readonly property var groups: {
        const order = [];
        const byName = {};
        const model = NotificationServer.historyModel;
        for (let i = 0; i < model.count; i++) {
            const entry = model.get(i);
            const notification = entry.notification;
            if (!notification)
                continue;
            if (!(notification.appName in byName)) {
                byName[notification.appName] = [];
                order.push(notification.appName);
            }
            byName[notification.appName].push({ notification: notification, arrivedAt: entry.arrivedAt });
        }
        return order.map(appName => ({ appName: appName, notifications: byName[appName] }));
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

        visible: NotificationServer.historyModel.count === 0
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

    Flickable {
        id: idGroupsFlickable

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: Math.min(idGroupsColumn.implicitHeight, root.groupsScrollMax)
        Layout.maximumHeight: root.groupsScrollMax

        visible: NotificationServer.historyModel.count > 0
        contentWidth: width
        contentHeight: idGroupsColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: idGroupsColumn

            width: idGroupsFlickable.width

            spacing: Globals.rowSpacing

            Repeater {
                id: idGroupsRepeater

                model: root.groups

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
}
