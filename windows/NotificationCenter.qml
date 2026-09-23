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
    onOutsideClicked: NotificationServer.closeCenterFromOutside()

    property var expandedGroups: ({})

    function toggleGroup(appName: string) {
        const next = Object.assign({}, root.expandedGroups);
        next[appName] = next[appName] !== true;
        root.expandedGroups = next;
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

    Flickable {
        id: idGroupsFlickable

        Layout.fillWidth: true
        Layout.preferredHeight: idGroupsColumn.implicitHeight
        Layout.maximumHeight: Globals.centerMaxHeight

        visible: NotificationServer.historyModel.count > 0
        contentWidth: width
        contentHeight: idGroupsColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: idGroupsColumn

            width: idGroupsFlickable.width

            spacing: 8

            Repeater {
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
