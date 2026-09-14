pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// Aliased: the bare name resolves to the C++ type, shadowing the singleton (conventions §4).
import Quickshell.Services.Notifications as Notif
import qs.config
import qs.services

// History card: toast styling without the decay countdown; inline reply via the "↩ Reply" pill.
Rectangle {
    id: root

    required property Notif.Notification notification

    readonly property bool isCritical: notification !== null && notification.urgency === Notif.NotificationUrgency.Critical

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
                    required property Notif.NotificationAction modelData

                    // The server deletes/recreates actions on update; delegates briefly hold dead modelData (log-observed TypeError).
                    // No baseColor: the default backgroundSecondary is the inset control on this card's background fill.
                    text: modelData ? modelData.text : ""
                    // invoke() dismisses non-resident notifications server-side; focus first while the object is alive.
                    onClicked: {
                        NotificationServer.focusApp(root.notification);
                        modelData.invoke();
                    }
                }
            }

            // The DBus inline-reply action isn't in `actions`; it surfaces as hasInlineReply instead.
            PillButton {
                id: idReplyButton

                visible: root.notification !== null && root.notification.hasInlineReply
                text: "↩ Reply"
                highlighted: root.replyExpanded

                onClicked: {
                    root.replyExpanded = true;
                    // A hidden TextInput refuses focus; focus once the field is visible.
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
        // Read resident first: sendInlineReply closes non-resident notifications itself, racing later access.
        const resident = root.notification.resident;
        root.collapseReply();
        root.notification.sendInlineReply(text);
        // The card always dismisses on send; resident notifications are the ones left behind.
        if (resident)
            root.notification.dismiss();
    }

    function collapseReply() {
        root.replyExpanded = false;
        idReplyInput.text = "";
    }
}
