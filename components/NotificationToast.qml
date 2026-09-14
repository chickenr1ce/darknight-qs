pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
// Aliased: the bare name resolves to the C++ type, shadowing the singleton (conventions §4).
import Quickshell.Services.Notifications as Notif
import qs.components
import qs.config
import qs.services

// Transient toast: hover-paused decay; critical toasts never expire and dismiss on click.
Rectangle {
    id: root

    required property Notif.Notification toast

    readonly property bool isCritical: toast !== null && toast.urgency === Notif.NotificationUrgency.Critical
    // expireTimeout arrives in milliseconds despite the docs claiming seconds; 0 = never expire, -1 falls back to 5s.
    readonly property int timeoutMs: Math.round(toast !== null && toast.expireTimeout > 0 ? toast.expireTimeout : 5000)
    readonly property bool sticky: root.isCritical || (toast !== null && toast.expireTimeout === 0)
    readonly property bool hovered: idToastHoverArea.containsMouse

    property real decayProgress: 1.0

    implicitWidth: Globals.toastWidth
    implicitHeight: idToastLayout.implicitHeight
        + idToastLayout.anchors.topMargin + idToastLayout.anchors.bottomMargin

    radius: Globals.cardRadius
    color: root.isCritical ? Colors.criticalCard : Colors.card
    border.width: 1
    border.color: root.isCritical ? Colors.criticalCardBorder : Colors.border

    Component.onCompleted: idEntranceAnimator.start()

    ParallelAnimation {
        id: idEntranceAnimator

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Globals.toastMs
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: idEntranceSlide
            property: "x"
            from: 48
            to: 0
            duration: Globals.toastMs
            easing.type: Easing.OutCubic
        }
    }

    // Pause (not restart) on hover, so hovering can't extend dismissal past the timeout.
    NumberAnimation {
        id: idDecayAnimator

        target: root
        property: "decayProgress"
        duration: Math.max(root.timeoutMs, 1)
        from: 1.0
        to: 0.0
        easing.type: Easing.Linear
        // Requesting paused on a stopped animator warns, so gate on running (sticky toasts never run).
        running: !root.sticky
        paused: running && root.hovered
        // Timeout hides the popup only; history persists until dismissed, so retire instead of expiring.
        // The row can be retired while decay still runs; the retire scan no-ops then.
        onFinished: {
            if (root.toast !== null)
                NotificationServer.retireToast(root.toast);
        }
    }

    transform: Translate {
        id: idEntranceSlide
    }

    // Under the pills and close button so their handlers win; a bare click dismisses (this clears sticky criticals).
    MouseArea {
        id: idCardClickArea

        anchors.fill: parent
        onClicked: root.toast.dismiss()
    }

    ColumnLayout {
        id: idToastLayout

        anchors {
            fill: parent
            margins: Globals.cardPadding
            leftMargin: Globals.cardHPadding
            rightMargin: Globals.cardHPadding
        }

        spacing: 6

        RowLayout {
            id: idHeaderRow

            Layout.fillWidth: true

            spacing: 8

            Text {
                id: idAppLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                textFormat: Text.PlainText
                elide: Text.ElideRight

                text: root.toast !== null ? root.toast.appName.toUpperCase() : ""
                color: root.isCritical ? Colors.danger : Colors.accent

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    letterSpacing: 0.6
                }
            }

            IconButton {
                id: idCloseButton

                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                // Hover comes from probeOver, not containsMouse: the topmost probe captures all hover above this button.
                probeHovered: root.probeOver(idCloseButton)
                onClicked: root.toast.dismiss()
            }
        }

        Text {
            id: idSummaryLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            visible: root.toast !== null && root.toast.summary !== ""
            textFormat: Text.PlainText
            elide: Text.ElideRight

            text: root.toast !== null ? root.toast.summary : ""
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiTitleSize
                weight: Font.DemiBold
            }
        }

        Text {
            id: idBodyLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            visible: root.toast !== null && root.toast.body !== ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight

            text: root.toast !== null ? root.toast.body : ""
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
            visible: root.toast !== null && root.toast.actions.length > 0

            Repeater {
                model: root.toast !== null ? root.toast.actions : []

                // qmllint disable uncreatable-type
                PillButton {
                    id: idActionPill

                    required property Notif.NotificationAction modelData

                    // Delegates outlive their action during displaced teardown; null-guard the dead modelData.
                    text: modelData ? modelData.text : ""
                    probeHovered: root.probeOver(idActionPill)
                    // Focus first: invoke() dismisses non-resident notifications server-side, killing the object.
                    onClicked: {
                        NotificationServer.focusApp(root.toast);
                        modelData.invoke();
                    }
                }
            }
        }
    }

    Rectangle {
        id: idDecayTrack

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        height: 2
        radius: 1
        color: Colors.cardSecondary
        visible: !root.sticky

        Rectangle {
            id: idDecayFill

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }

            width: parent.width * root.decayProgress
            radius: 1
            color: Colors.accent
        }
    }

    // On top: StyledText accepts hover itself and would shadow a probe underneath; Qt.NoButton keeps clicks passing through.
    MouseArea {
        id: idToastHoverArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    // Pills/close never receive hover (probe sits above); they bind highlight to probe-relative geometry.
    function probeOver(item) {
        if (!root.hovered)
            return false;
        const p = item.mapFromItem(root, idToastHoverArea.mouseX, idToastHoverArea.mouseY);
        return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height;
    }
}
