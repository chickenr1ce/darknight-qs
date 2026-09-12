pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.services

// Floating notification center (ticket 03), frozen decision 1A: 380px panel,
// 540px max height, slab radius, floating 8px below the bar and right-aligned
// toward the notification module. Pure notification focus per decision 4A:
// unread badge, DND toggle and Clear All in one header row.
//
// Same fixed-canvas pattern as the toast layer: window height never binds to
// content during transitions (docs/coding-conventions.md §4); the input mask
// Region tracks the real panel size instead, and the fade-out keeps the
// window mapped until opacity reaches zero.

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Keyboard focus for the inline-reply TextInput (3A): without this the
    // compositor never routes keys to the panel and typing lands in the
    // focused app window. OnDemand (the default mode behind this flag) only
    // takes focus on click, so an open-but-untouched center never steals it.
    focusable: true

    anchors {
        top: true
        right: true
    }

    margins {
        top: Globals.barHeight + Globals.moduleMargin + 8
        right: Globals.horizontalBarMargin + Globals.slabEdgePadding
    }

    implicitWidth: Globals.centerWidth
    implicitHeight: Globals.centerMaxHeight

    // Fade/slide register: 140ms open, 120ms close. The animation lives on
    // the inner panel (a Window has neither opacity-as-Item nor transform);
    // `visible` stays true for the whole close animation so the fade renders.
    visible: NotificationServer.centerVisible || idPanel.opacity > 0

    // Click-through everywhere except the panel itself; emptied while hidden
    // so a faded-out frame can never swallow input.
    mask: Region {
        x: 0
        y: 0
        width: root.visible ? idPanel.width : 0
        height: root.visible ? idPanel.height : 0
    }

    // Expansion state keyed by app name so accordions survive history-driven
    // rebuilds of the grouped model. Reassign (never mutate) so bindings on
    // the map re-evaluate.
    property var expandedGroups: ({})

    function toggleGroup(appName: string) {
        const next = Object.assign({}, root.expandedGroups);
        next[appName] = next[appName] !== true;
        root.expandedGroups = next;
    }

    // Groups in arrival order (newest last). Scans historyModel by count so
    // this re-evaluates on every append/remove.
    readonly property var groups: {
        const order = [];
        const byName = {};
        const model = NotificationServer.historyModel;
        for (let i = 0; i < model.count; i++) {
            const notification = model.get(i).notification;
            if (!notification)
                continue;
            if (!(notification.appName in byName)) {
                byName[notification.appName] = [];
                order.push(notification.appName);
            }
            byName[notification.appName].push(notification);
        }
        return order.map(appName => ({ appName: appName, notifications: byName[appName] }));
    }

    Rectangle {
        id: idPanel

        anchors.left: parent.left
        anchors.right: parent.right

        // Slide rides the animated opacity, so fade and move stay in
        // lockstep: 8px above rest position when fully hidden.
        y: -8 * (1 - opacity)
        opacity: NotificationServer.centerVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: NotificationServer.centerVisible ? Globals.centerOpenMs : Globals.centerCloseMs
                easing.type: Easing.OutCubic
            }
        }

        height: Math.min(Globals.centerMaxHeight, idCenterLayout.implicitHeight + 24)

        radius: Globals.slabRadius
        color: Colors.background
        border.width: 1
        border.color: Colors.surface

        ColumnLayout {
            id: idCenterLayout

            anchors.fill: parent
            anchors.margins: 12

            spacing: 10

            RowLayout {
                id: idHeaderRow

                Layout.fillWidth: true

                spacing: 8

                Text {
                    id: idTitleLabel

                    textFormat: Text.PlainText
                    text: qsTr("Notifications")
                    color: Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiTitleSize
                        weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: idUnreadBadge

                    Layout.preferredWidth: Math.max(idUnreadLabel.implicitWidth + 12, 18)
                    Layout.preferredHeight: idUnreadLabel.implicitHeight + 4
                    Layout.alignment: Qt.AlignVCenter

                    radius: height / 2
                    visible: NotificationServer.unreadCount > 0
                    color: Colors.lavender

                    Text {
                        id: idUnreadLabel

                        anchors.centerIn: parent

                        textFormat: Text.PlainText
                        text: NotificationServer.unreadCount
                        color: Colors.background

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiCaptionSize
                            weight: Font.DemiBold
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                PillButton {
                    id: idDndButton

                    Layout.alignment: Qt.AlignVCenter

                    text: qsTr("DND")
                    highlighted: NotificationServer.dndEnabled
                    onClicked: NotificationServer.toggleDnd()
                }

                PillButton {
                    id: idClearAllButton

                    Layout.alignment: Qt.AlignVCenter

                    // Always laid out (disabled when empty) so DND never
                    // slides sideways when this pill appears/disappears.
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
    }
}
