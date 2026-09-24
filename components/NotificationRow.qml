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

    required property var entry
    required property color appColor
    required property real relativeTimeNow

    property bool showDivider: true
    property bool replyExpanded: false

    readonly property Notif.Notification notification: root.entry && root.entry.notification ? root.entry.notification : null
    readonly property real arrivedAt: root.entry && root.entry.arrivedAt > 0 ? root.entry.arrivedAt : 0
    readonly property bool isCritical: !(root.notification === null) && NotificationServer.isCriticalUrgency(root.notification.urgency)
    readonly property bool actionsVisible: root.notification !== null
        && (root.notification.actions.length > 0 || root.notification.hasInlineReply)
    readonly property string relativeTime: {
        if (!(root.arrivedAt > 0))
            return "";
        const delta = Math.max(0, root.relativeTimeNow - root.arrivedAt);
        const minute = 60000;
        const hour = 3600000;
        const day = 86400000;
        if (delta < minute)
            return qsTr("just now");
        if (delta < hour)
            return qsTr("%1m").arg(Math.floor(delta / minute));
        if (delta < day)
            return qsTr("%1h").arg(Math.floor(delta / hour));
        return qsTr("%1d").arg(Math.floor(delta / day));
    }

    implicitWidth: parent ? parent.width : 0
    implicitHeight: idRowLayout.implicitHeight + 2 * Globals.listSpacing

    Rectangle {
        id: idCriticalWash

        anchors.fill: parent

        visible: root.isCritical
        color: Colors.criticalCard
    }

    RowLayout {
        id: idRowLayout

        anchors {
            fill: parent
            topMargin: Globals.listSpacing
            bottomMargin: Globals.listSpacing
            leftMargin: 0
            rightMargin: 0
        }

        spacing: Globals.rowSpacing

        Rectangle {
            id: idNotificationRail

            Layout.preferredWidth: Globals.appRailWidth
            Layout.fillHeight: true

            radius: Globals.appRailWidth / 2
            color: root.isCritical ? Colors.danger : root.appColor

            Accessible.ignored: true
        }

        ColumnLayout {
            id: idRowContent

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            spacing: Globals.listSpacing

            RowLayout {
                id: idTitleRow

                Layout.fillWidth: true

                spacing: Globals.rowSpacing

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
                    id: idTitleSpacer

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    visible: !(idSummaryLabel.visible)
                }

                IconButton {
                    id: idDismissButton

                    Layout.alignment: Qt.AlignVCenter

                    accessibleName: qsTr("Dismiss")
                    onClicked: {
                        if (root.notification !== null)
                            root.notification.dismiss();
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

            RowLayout {
                id: idMetaRow

                Layout.fillWidth: true

                spacing: Globals.listSpacing

                Flow {
                    id: idActionsFlow

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    spacing: Globals.listSpacing
                    visible: root.actionsVisible

                    Repeater {
                        model: root.notification !== null ? root.notification.actions : []

                        // qmllint disable uncreatable-type
                        PillButton {
                            required property Notif.NotificationAction modelData

                            quiet: true
                            text: modelData ? modelData.text : ""
                            onClicked: {
                                if (modelData)
                                    NotificationServer.invokeAction(root.notification, modelData);
                            }
                        }
                    }

                    PillButton {
                        id: idReplyButton

                        quiet: true
                        visible: root.notification !== null && root.notification.hasInlineReply
                        text: qsTr("Reply")
                        highlighted: root.replyExpanded

                        onClicked: {
                            root.replyExpanded = true;
                            Qt.callLater(() => idReplyInput.forceActiveFocus());
                        }
                    }
                }

                Item {
                    id: idMetaSpacer

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    visible: !root.actionsVisible
                }

                Text {
                    id: idRelativeTimeLabel

                    Layout.alignment: Qt.AlignVCenter

                    visible: root.relativeTime !== ""
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter

                    text: root.relativeTime
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiCaptionSize
                    }
                }
            }

            RowLayout {
                id: idReplyRow

                Layout.fillWidth: true

                spacing: Globals.listSpacing
                visible: root.replyExpanded

                Rectangle {
                    id: idReplyField

                    Layout.fillWidth: true
                    Layout.preferredHeight: idReplyInput.implicitHeight + 2 * Globals.fieldPadding

                    radius: Globals.pillRadius
                    color: Colors.cardSecondary
                    border.width: 1
                    border.color: idReplyInput.activeFocus ? Colors.accent : Colors.border

                    TextInput {
                        id: idReplyInput

                        anchors.fill: parent
                        anchors.margins: Globals.fieldPadding

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

                    quiet: true
                    text: qsTr("Send")
                    onClicked: root.sendReply()
                }
            }
        }
    }

    Rectangle {
        id: idRowDivider

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        visible: root.showDivider
        height: Globals.hairlineHeight
        color: Colors.border
    }

    function sendReply() {
        const text = idReplyInput.text.trim();
        if (text === "")
            return;
        if (root.notification === null)
            return;
        const resident = root.notification.resident;
        root.collapseReply();
        root.notification.sendInlineReply(text);
        if (resident)
            root.notification.dismiss();
    }

    function collapseReply() {
        root.replyExpanded = false;
        idReplyInput.clear();
    }
}
