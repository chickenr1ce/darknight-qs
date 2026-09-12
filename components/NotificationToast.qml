pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.config

// One transient toast card (ticket 02). Owns its decay countdown (linear,
// paused while hovered), renders action pills, and styles critical urgency
// with a quiet red-tinted card (prototype verdict); critical toasts never
// expire and leave on click. Typography pass 2026-08-24: all-Geist card at
// Globals' named ui* scale, body/pills on Colors.textSubtle for contrast.
Rectangle {
    id: root

    required property Notification toast

    readonly property bool isCritical: toast !== null && toast.urgency === NotificationUrgency.Critical
    // NOTE: verified empirically against quickshell 0.3.1 — expireTimeout
    // arrives in milliseconds despite the docs claiming seconds.
    // 0 means the sender explicitly asked for "never expire"; -1 (server
    // decides) and other non-positive values fall back to the 5s default.
    readonly property int timeoutMs: Math.round(toast !== null && toast.expireTimeout > 0 ? toast.expireTimeout : 5000)
    readonly property bool sticky: root.isCritical || (toast !== null && toast.expireTimeout === 0)
    readonly property bool hovered: idToastHoverArea.containsMouse

    // Driven imperatively by idDecayAnimator; feeds the countdown bar fill.
    property real decayProgress: 1.0

    implicitWidth: Globals.toastWidth
    // Content-driven height: the inner layout keeps a fixed inset from the
    // card edges (width via side anchors) while this height wraps it.
    implicitHeight: idToastLayout.implicitHeight
        + idToastLayout.anchors.topMargin + idToastLayout.anchors.bottomMargin

    radius: 6
    color: root.isCritical ? Colors.criticalCard : Colors.background
    border.width: 1
    border.color: root.isCritical ? Colors.criticalCardBorder : Colors.surface

    Component.onCompleted: idEntranceAnimator.start()

    // Globals.toastMs ease-out slide-from-right + fade entrance.
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

    // Linear decay; pause/resume keeps the exact remaining time instead of
    // restarting, so hovering cannot extend dismissal past the timeout.
    NumberAnimation {
        id: idDecayAnimator

        target: root
        property: "decayProgress"
        duration: Math.max(root.timeoutMs, 1)
        from: 1.0
        to: 0.0
        easing.type: Easing.Linear
        // `running && ...`: requesting paused on a stopped animator (sticky
        // toasts) warns and is meaningless, so gate it on running.
        running: !root.sticky
        paused: running && root.hovered
        // Null-guarded: the row can be retired (cap eviction, manual dismiss)
        // while decay is still running; a dead toast has nothing to expire.
        onFinished: {
            if (root.toast !== null)
                root.toast.expire();
        }
    }

    transform: Translate {
        id: idEntranceSlide
    }

    // Click-to-dismiss surface sits under the close button and action pills
    // so their own handlers win; a bare click anywhere else dismisses (this
    // is what makes sticky critical notifications clickable away).
    MouseArea {
        id: idCardClickArea

        anchors.fill: parent
        onClicked: root.toast.dismiss()
    }

    ColumnLayout {
        id: idToastLayout

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
                id: idAppLabel

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                textFormat: Text.PlainText
                elide: Text.ElideRight

                text: root.toast !== null ? root.toast.appName.toUpperCase() : ""
                color: root.isCritical ? Colors.red : Colors.lavender

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    letterSpacing: 0.6
                }
            }

            Item {
                id: idCloseButton

                Layout.preferredWidth: 18
                Layout.preferredHeight: 18

                Text {
                    id: idCloseGlyph

                    anchors.centerIn: parent

                    text: "✕"
                    // Decorative glyph only — the dim textSecondary tone is
                    // acceptable here precisely because it must not be read.
                    // Size rides the body step of the ui* scale (§4: no
                    // hardcoded pixel sizes on reading surfaces).
                    // Hover comes from probeOver, not containsMouse: the
                    // topmost decay-pause probe captures all hover above this
                    // button (the OR keeps the highlight if restacked).
                    color: idCloseMouseArea.containsMouse || root.probeOver(idCloseButton) ? Colors.text : Colors.textSecondary

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
                    onClicked: root.toast.dismiss()
                }
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

                    required property NotificationAction modelData

                    // Null-guarded like the card's pills: delegates outlive
                    // their action during ListView displaced teardown.
                    text: modelData ? modelData.text : ""
                    probeHovered: root.probeOver(idActionPill)
                    onClicked: modelData.invoke()
                }
            }
        }
    }

    // Linear countdown indicator decaying over timeoutMs along the bottom.
    Rectangle {
        id: idDecayTrack

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        height: 2
        radius: 1
        color: Colors.backgroundSecondary
        visible: !root.sticky

        Rectangle {
            id: idDecayFill

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left

            width: parent.width * root.decayProgress
            radius: 1
            color: Colors.lavender
        }
    }

    // Hover probe must sit ON TOP of all content: text items rendering
    // StyledText accept hover events themselves and would otherwise shadow
    // a probe placed underneath. It never consumes clicks, so the close
    // button, action pills, and the dismiss surface below keep working.
    MouseArea {
        id: idToastHoverArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    // Probe-relative hover routing for the interactive elements beneath the
    // probe (action pills, close button): they never receive containsMouse
    // themselves, so they bind their highlight to this instead. Maps the
    // probe-reported cursor into the item's own geometry; re-evaluates on
    // every cursor move via the probe's mouseX/mouseY. Gated on hovered so
    // a stale cursor position can't light anything up from outside the card.
    function probeOver(item) {
        if (!root.hovered)
            return false;
        const p = item.mapFromItem(root, idToastHoverArea.mouseX, idToastHoverArea.mouseY);
        return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height;
    }
}
