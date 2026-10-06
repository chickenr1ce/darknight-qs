pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    readonly property var flow: PolkitService.flow
    readonly property string message: root.flow ? root.flow.message : ""
    readonly property string actionId: root.flow ? root.flow.actionId : ""
    readonly property string prompt: root.flow ? root.flow.inputPrompt : ""
    readonly property string supplementary: root.flow ? root.flow.supplementaryMessage : ""
    readonly property bool supplementaryIsError: root.flow ? root.flow.supplementaryIsError : false
    readonly property bool failed: root.flow ? root.flow.failed : false
    readonly property bool responseRequired: root.flow ? root.flow.isResponseRequired : false
    readonly property bool passwordHidden: root.flow ? !root.flow.responseVisible : true
    readonly property bool hasMessage: root.supplementary !== "" || root.failed
    readonly property bool messageIsError: root.supplementaryIsError || root.failed
    readonly property string messageText: root.supplementary !== "" ? root.supplementary : qsTr("Authentication failed. Try again.")
    readonly property bool verifying: root.flow !== null && !root.responseRequired

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: PolkitService.isActive

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (root.visible) {
            idPasswordInput.clear();
            idRunnerEntrance.restart();
            idPasswordInput.forceActiveFocus();
        } else {
            idPasswordInput.clear();
        }
    }

    onHasMessageChanged: {
        if (root.hasMessage)
            root.shakeIfMessage();
    }

    function submit(): void {
        if (!root.responseRequired)
            return;
        PolkitService.submit(idPasswordInput.text);
    }

    function shakeIfMessage(): void {
        Qt.callLater(root.runShake);
    }

    function runShake(): void {
        if (root.hasMessage && !Globals.reducedMotion)
            idErrorShake.restart();
    }

    Shortcut {
        id: idShortcutReturn

        sequence: "Return"
        autoRepeat: false
        enabled: root.responseRequired
        onActivated: root.submit()
    }

    Shortcut {
        id: idShortcutEnter

        sequence: "Enter"
        autoRepeat: false
        enabled: root.responseRequired
        onActivated: root.submit()
    }

    Shortcut {
        id: idShortcutEscape

        sequence: "Escape"
        autoRepeat: false
        enabled: root.visible
        onActivated: PolkitService.cancel()
    }

    Shortcut {
        id: idShortcutSwitchIdentity

        sequence: "Tab"
        autoRepeat: false
        enabled: root.responseRequired && PolkitService.hasMultipleIdentities
        onActivated: PolkitService.cycleIdentity()
    }

    Connections {
        id: idFlowConnections

        target: PolkitService.flow

        function onIsResponseRequiredChanged(): void {
            if (!root.responseRequired)
                return;
            idPasswordInput.clear();
            idPasswordInput.forceActiveFocus();
            root.shakeIfMessage();
        }

        function onSupplementaryMessageChanged(): void {
            root.shakeIfMessage();
        }

        function onSupplementaryIsErrorChanged(): void {
            root.shakeIfMessage();
        }

        function onFailedChanged(): void {
            root.shakeIfMessage();
        }
    }

    Rectangle {
        id: idScrim

        anchors.fill: parent
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, Globals.polkitScrimOpacity)

        MouseArea {
            id: idScrimMouseArea

            anchors.fill: parent
            onClicked: PolkitService.cancel()
        }
    }

    Item {
        id: idRunnerSlot

        anchors.centerIn: parent

        implicitWidth: idRunner.width
        implicitHeight: idRunner.height

        Rectangle {
            id: idRunner

            width: Globals.polkitWidth
            height: idRunnerColumn.implicitHeight
            radius: Globals.panelRadius
            color: Colors.panel
            border.width: Globals.hairlineHeight
            border.color: Colors.panelBorder

            MouseArea {
                id: idRunnerClickGuard

                anchors.fill: parent
            }

            ColumnLayout {
                id: idRunnerColumn

                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: idMetaRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.polkitMetaHeight

                    color: Colors.panel

                    RowLayout {
                        id: idMetaLayout

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding
                        }

                        spacing: Globals.rowSpacing

                        Text {
                            id: idMetaBrand

                            Layout.alignment: Qt.AlignVCenter

                            textFormat: Text.PlainText
                            text: qsTr("POLKIT")
                            color: Colors.accent

                            font {
                                family: Globals.fontFamily
                                pixelSize: Globals.uiCaptionSize
                                weight: Font.DemiBold
                                letterSpacing: Globals.uiLetterSpacing
                            }
                        }

                        Text {
                            id: idMetaMessage

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: root.message
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }
                    }
                }

                Rectangle {
                    id: idMetaSeparator

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.hairlineHeight
                    color: Colors.border
                }

                Item {
                    id: idProgressTrack

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.hairlineHeight * 2
                    visible: root.verifying
                    clip: true

                    Rectangle {
                        id: idProgressBar

                        width: idProgressTrack.width * 0.35
                        height: idProgressTrack.height
                        color: Colors.accent

                        NumberAnimation on x {
                            running: idProgressTrack.visible && !Globals.reducedMotion
                            loops: Animation.Infinite
                            from: -idProgressBar.width
                            to: idProgressTrack.width
                            duration: 1200
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    id: idInputRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.polkitInputHeight

                    color: Colors.panel

                    RowLayout {
                        id: idInputLayout

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding
                        }

                        spacing: Globals.rowSpacing

                        Icon {
                            id: idInputGlyph

                            Layout.alignment: Qt.AlignVCenter

                            text: Icons.lock
                            size: Globals.uiIconSize
                            color: Colors.accent
                        }

                        TextInput {
                            id: idPasswordInput

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter

                            enabled: root.responseRequired
                            clip: true
                            selectByMouse: true
                            echoMode: root.passwordHidden ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "•"
                            color: Colors.text

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }

                            onAccepted: root.submit()

                            Text {
                                id: idInputPlaceholder

                                anchors.fill: parent

                                verticalAlignment: Text.AlignVCenter
                                visible: idPasswordInput.text === ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                text: root.prompt !== "" ? root.prompt : qsTr("Passphrase for %1…").arg(PolkitService.identityName)
                                color: Colors.textSubtle

                                font {
                                    family: Globals.uiFontFamily
                                    pixelSize: Globals.uiBodySize
                                }
                            }
                        }

                        PillButton {
                            id: idUnlockButton

                            Layout.alignment: Qt.AlignVCenter

                            text: qsTr("Unlock")
                            highlighted: true
                            disabled: !root.responseRequired
                            onClicked: root.submit()
                        }
                    }
                }

                Rectangle {
                    id: idMessageRow

                    Layout.fillWidth: true

                    visible: root.hasMessage
                    implicitHeight: idMessageLabel.implicitHeight + 2 * Globals.cardPadding
                    color: root.messageIsError ? Colors.criticalCard : Colors.cardSecondary
                    border.width: Globals.hairlineHeight
                    border.color: root.messageIsError ? Colors.criticalCardBorder : Colors.border

                    transform: Translate {
                        id: idMessageTranslate

                        x: 0
                    }

                    Text {
                        id: idMessageLabel

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding
                            topMargin: Globals.cardPadding
                            bottomMargin: Globals.cardPadding
                        }

                        verticalAlignment: Text.AlignVCenter
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: root.messageText
                        color: root.messageIsError ? Colors.danger : Colors.warning

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiCaptionSize
                        }
                    }

                    SequentialAnimation {
                        id: idErrorShake

                        NumberAnimation { target: idMessageTranslate; property: "x"; to: -1; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: 2; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: -3; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: 3; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: -3; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: 3; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: -3; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: 2; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: -1; duration: 28 }
                        NumberAnimation { target: idMessageTranslate; property: "x"; to: 0; duration: 28 }
                    }
                }

                Rectangle {
                    id: idFooterSeparator

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.hairlineHeight
                    color: Colors.border
                }

                Rectangle {
                    id: idFooter

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.polkitFooterHeight

                    color: Colors.panel

                    RowLayout {
                        id: idFooterLayout

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding
                        }

                        spacing: Globals.spacing

                        KeyHint {
                            id: idFooterUnlock

                            Layout.alignment: Qt.AlignVCenter

                            key: "↵"
                            label: qsTr("unlock")
                        }

                        KeyHint {
                            id: idFooterCancel

                            Layout.alignment: Qt.AlignVCenter

                            key: "Esc"
                            label: qsTr("cancel")
                        }

                        Item {
                            id: idFooterSpacer

                            Layout.fillWidth: true
                        }

                        KeyHint {
                            id: idFooterIdentityKey

                            Layout.alignment: Qt.AlignVCenter
                            Layout.maximumWidth: Math.round(Globals.polkitWidth * 0.4)
                            visible: PolkitService.hasMultipleIdentities

                            key: "Tab"
                            label: PolkitService.identityName
                        }

                        Text {
                            id: idFooterIdentity

                            Layout.alignment: Qt.AlignVCenter
                            visible: !PolkitService.hasMultipleIdentities

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: PolkitService.identityName
                            color: Colors.textSubtle

                            font {
                                family: Globals.fontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }

                        Text {
                            id: idFooterAction

                            Layout.maximumWidth: Math.round(Globals.polkitWidth * 0.4)
                            Layout.alignment: Qt.AlignVCenter

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: root.actionId
                            color: Colors.textSecondary

                            font {
                                family: Globals.fontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }
                    }
                }
            }

            ParallelAnimation {
                id: idRunnerEntrance

                NumberAnimation {
                    target: idRunner
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: Globals.reducedMotion ? 0 : Globals.centerOpenMs
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: idRunnerSlot
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Globals.reducedMotion ? 0 : Globals.centerOpenMs
                }
            }
        }
    }
}
