pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.config

// One history notification card inside the notification center (ticket 03).
// Shares the toast card's fill and typography — Colors.background so cards
// read as dark slabs on the group's lighter backgroundSecondary frame — but
// carries no decay countdown: history persists until explicitly dismissed
// or cleared. Inset controls (action pills, reply field) ride
// backgroundSecondary, the inverse of the card, mirroring the toast pairing.
//
// Inline quick reply (frozen decision 3A): the "↩ Reply" pill expands an
// auto-focused TextInput; Enter sends via sendInlineReply() and dismisses,
// Escape collapses the field.
Rectangle {
    id: root

    required property Notification notification

    readonly property bool isCritical: notification !== null && notification.urgency === NotificationUrgency.Critical

    property bool replyExpanded: false

    implicitWidth: parent ? parent.width : 0
    implicitHeight: idCardLayout.implicitHeight
        + idCardLayout.anchors.topMargin + idCardLayout.anchors.bottomMargin

    radius: 6
    color: root.isCritical ? Colors.criticalCard : Colors.background
    border.width: 1
    border.color: root.isCritical ? Colors.criticalCardBorder : Colors.surface

    ColumnLayout {
        id: idCardLayout

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        spacing: 6

        RowLayout {
            id: idHeaderRow

            Layout.fillWidth: true

            spacing: 8

            Text {
                id: idSummaryLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                visible: root.notification !== null && root.notification.summary !== ""
                textFormat: Text.PlainText
                elide: Text.ElideRight

                text: root.notification !== null ? root.notification.summary : ""
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiTitleSize
                    weight: Font.DemiBold
                }
            }

            Item {
                id: idCloseButton

                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                Text {
                    anchors.centerIn: parent

                    text: "✕"
                    color: idCloseMouseArea.containsMouse ? Colors.text : Colors.textSecondary

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                MouseArea {
                    id: idCloseMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notification.dismiss()
                }
            }
        }

        Text {
            id: idBodyLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            visible: root.notification !== null && root.notification.body !== ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            elide: Text.ElideRight

            text: root.notification !== null ? root.notification.body : ""
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Flow {
            id: idActionsRow

            Layout.fillWidth: true
            Layout.topMargin: 2

            spacing: 5
            visible: root.notification !== null
                && (root.notification.actions.length > 0 || root.notification.hasInlineReply)

            Repeater {
                model: root.notification !== null ? root.notification.actions : []

                // qmllint disable uncreatable-type
                PillButton {
                    required property NotificationAction modelData

                    // Null-guarded: the server deletes/recreates action objects
                    // on update, so delegates briefly hold a dead modelData
                    // during rebuild (log-observed TypeError otherwise).
                    // No baseColor: the default backgroundSecondary is the
                    // inset control on this card's background fill.
                    text: modelData ? modelData.text : ""
                    // invoke() dismisses non-resident notifications
                    // server-side; the closed handler retires the card.
                    onClicked: modelData.invoke()
                }
            }

            // Inline-reply trigger pill (3A). The DBus inline-reply action is
            // not part of `actions`; it surfaces as hasInlineReply instead.
            PillButton {
                id: idReplyButton

                visible: root.notification !== null && root.notification.hasInlineReply
                text: "↩ Reply"
                highlighted: root.replyExpanded

                onClicked: {
                    root.replyExpanded = true;
                    // Focus once the field is actually visible; a hidden
                    // TextInput refuses active focus.
                    Qt.callLater(() => idReplyInput.forceActiveFocus());
                }
            }
        }

        RowLayout {
            id: idReplyRow

            Layout.fillWidth: true

            spacing: 5
            visible: root.replyExpanded

            Rectangle {
                id: idReplyField

                Layout.fillWidth: true
                Layout.preferredHeight: idReplyInput.implicitHeight + 10

                radius: 4
                color: Colors.backgroundSecondary
                border.width: 1
                border.color: idReplyInput.activeFocus ? Colors.lavender : Colors.surface

                TextInput {
                    id: idReplyInput

                    anchors.fill: parent
                    anchors.margins: 5

                    clip: true
                    color: Colors.text
                    wrapMode: TextInput.Wrap
                    selectByMouse: true
                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: idReplyInput.text === "" && !idReplyInput.activeFocus

                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: root.notification !== null && root.notification.inlineReplyPlaceholder !== ""
                            ? root.notification.inlineReplyPlaceholder : qsTr("Reply…")
                        color: Colors.textSubtle

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                        }
                    }

                    Keys.onReturnPressed: root.sendReply()
                    Keys.onEnterPressed: root.sendReply()
                    Keys.onEscapePressed: root.collapseReply()
                }
            }

            PillButton {
                id: idSendButton

                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                Layout.alignment: Qt.AlignVCenter

                text: qsTr("Send")
                onClicked: root.sendReply()
            }
        }
    }

    function sendReply() {
        const text = idReplyInput.text.trim();
        if (text === "")
            return;
        if (root.notification === null)
            return;
        // Read before sending: sendInlineReply closes non-resident
        // notifications itself (the closed signal retires the card), so
        // touching the object afterwards would race its destruction.
        const resident = root.notification.resident;
        root.collapseReply();
        root.notification.sendInlineReply(text);
        // Spec 3A: the card always dismisses on send; resident notifications
        // are the ones sendInlineReply leaves behind.
        if (resident)
            root.notification.dismiss();
    }

    function collapseReply() {
        root.replyExpanded = false;
        idReplyInput.text = "";
    }
}
