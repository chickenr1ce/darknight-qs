pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    readonly property string question: PowerService.armedAction === "" ? qsTr("Pick an action.") : qsTr("%1? Confirm to run.").arg(PowerService.armedLabel)
    readonly property string headerSub: {
        const host = PowerService.hostName;
        const up = PowerService.uptime;
        if (!(host === "") && !(up === ""))
            return qsTr("%1 · up %2").arg(host).arg(up);
        if (!(host === ""))
            return host;
        return up;
    }
    readonly property int glyphBoxSize: 28
    readonly property int glyphOpticalNudge: 1
    readonly property int rowHeight: root.glyphBoxSize + 2 * Globals.cardPadding

    anchorScreen: PowerService.anchorScreen
    anchorCenterX: PowerService.anchorCenterX
    panelVisible: PowerService.powerVisible
    onOutsideClicked: PowerService.closePowerFromOutside()

    Shortcut {
        id: idPowerKey1

        enabled: root.panelVisible
        sequence: "1"
        onActivated: PowerService.arm("lock")
    }

    Shortcut {
        id: idPowerKey2

        enabled: root.panelVisible
        sequence: "2"
        onActivated: PowerService.arm("suspend")
    }

    Shortcut {
        id: idPowerKey3

        enabled: root.panelVisible
        sequence: "3"
        onActivated: PowerService.arm("logout")
    }

    Shortcut {
        id: idPowerKey4

        enabled: root.panelVisible
        sequence: "4"
        onActivated: PowerService.arm("reboot")
    }

    Shortcut {
        id: idPowerKey5

        enabled: root.panelVisible
        sequence: "5"
        onActivated: PowerService.arm("shutdown")
    }

    Shortcut {
        id: idPowerKeyReturn

        enabled: root.panelVisible
        sequence: "Return"
        onActivated: PowerService.confirmArmed()
    }

    Shortcut {
        id: idPowerKeyEnter

        enabled: root.panelVisible
        sequence: "Enter"
        onActivated: PowerService.confirmArmed()
    }

    PanelHeader {
        id: idPowerHeader

        title: qsTr("Power")
        showBadge: false
    }

    Text {
        id: idPowerHostLine

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.minimumHeight: idPowerHostMetrics.height

        textFormat: Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        text: root.headerSub
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    TextMetrics {
        id: idPowerHostMetrics

        text: "Mq"

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    ColumnLayout {
        id: idPowerList

        Layout.fillWidth: true

        spacing: 0

        Repeater {
            id: idPowerRepeater

            model: PowerService.actions

            delegate: Item {
                id: idPowerRowItem

                Layout.fillWidth: true
                Layout.preferredHeight: root.rowHeight + (index < PowerService.actions.length - 1 ? Globals.hairlineHeight : 0)

                required property var modelData
                required property int index

                readonly property bool isArmed: PowerService.armedAction === (modelData ? modelData.actionId : "")
                readonly property bool isHovered: idPowerRowMouseArea.containsMouse
                readonly property bool isPressed: idPowerRowMouseArea.containsPress
                readonly property string rowLabel: modelData ? modelData.label : ""
                readonly property string rowGlyph: modelData ? modelData.glyph : ""
                readonly property string rowHint: modelData ? modelData.hint : ""
                readonly property string rowActionId: modelData ? modelData.actionId : ""

                scale: idPowerRowPress.scale
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: idPowerRowItem.rowLabel

                Rectangle {
                    id: idPowerRowWash

                    anchors.fill: parent

                    color: Colors.cardSecondary
                    opacity: idPowerRowItem.isArmed || idPowerRowItem.isHovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Globals.reducedMotion ? 0 : Globals.hoverMs
                        }
                    }
                }

                Rectangle {
                    id: idPowerRowEdge

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    width: Globals.armedEdgeWidth
                    height: root.rowHeight - 2 * Globals.cardPadding

                    color: Colors.accent
                    opacity: idPowerRowItem.isArmed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Globals.reducedMotion ? 0 : Globals.hoverMs
                        }
                    }
                }

                RowLayout {
                    id: idPowerRowLayout

                    anchors {
                        fill: parent
                        leftMargin: Globals.cardHPadding
                        rightMargin: Globals.cardHPadding
                    }

                    height: root.rowHeight
                    spacing: Globals.rowSpacing

                    Rectangle {
                        id: idPowerGlyphBox

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.glyphBoxSize
                        Layout.preferredHeight: root.glyphBoxSize

                        radius: Globals.cardRadius
                        color: Colors.cardSecondary
                        scale: idPowerRowItem.isPressed ? Globals.pressScaleModule : (idPowerRowItem.isArmed ? 1.08 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: Globals.reducedMotion ? 0 : (idPowerRowItem.isPressed ? Globals.pressMs : Globals.hoverMs)
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            id: idPowerGlyphGlow

                            anchors.fill: parent

                            radius: Globals.cardRadius
                            color: Colors.surface
                            opacity: idPowerRowItem.isArmed ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Globals.reducedMotion ? 0 : Globals.hoverMs
                                }
                            }
                        }

                        Text {
                            id: idPowerGlyph

                            anchors {
                                centerIn: parent
                                horizontalCenterOffset: root.glyphOpticalNudge
                            }

                            textFormat: Text.PlainText
                            text: idPowerRowItem.rowGlyph
                            color: Colors.lavender

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.fontPixelSize
                                weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        id: idPowerLabel

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter

                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: idPowerRowItem.rowLabel
                        color: Colors.text

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                        }
                    }

                    Rectangle {
                        id: idPowerHintChip

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: idPowerHintLabel.implicitWidth + 2 * Globals.fieldPadding
                        Layout.preferredHeight: idPowerHintLabel.implicitHeight + 2 * Globals.hairlineHeight

                        radius: Globals.pillRadius
                        color: "transparent"
                        border.width: Globals.hairlineHeight
                        border.color: idPowerRowItem.isArmed ? Colors.accent : Colors.border

                        Text {
                            id: idPowerHintLabel

                            anchors.centerIn: parent

                            textFormat: Text.PlainText
                            text: idPowerRowItem.rowHint
                            color: idPowerRowItem.isArmed ? Colors.text : Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }
                    }
                }

                PressScale {
                    id: idPowerRowPress

                    pressed: idPowerRowItem.isPressed
                    pressedScale: Globals.pressScaleRow
                }

                MouseArea {
                    id: idPowerRowMouseArea

                    anchors.fill: parent

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PowerService.arm(idPowerRowItem.rowActionId)
                }

                Rectangle {
                    id: idPowerDivider

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: Globals.cardHPadding
                        rightMargin: Globals.cardHPadding
                    }

                    height: Globals.hairlineHeight
                    visible: index < PowerService.actions.length - 1
                    color: Colors.border
                }
            }
        }
    }

    RowLayout {
        id: idPowerFooter

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idPowerQuestion

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.question
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }

            onTextChanged: {
                if (!Globals.reducedMotion)
                    idQuestionSwap.restart();
            }
        }

        PillButton {
            id: idPowerCancel

            Layout.alignment: Qt.AlignVCenter

            disabled: PowerService.armedAction === ""
            text: qsTr("Cancel")
            onClicked: PowerService.cancel()
        }

        PillButton {
            id: idPowerConfirm

            Layout.alignment: Qt.AlignVCenter

            disabled: PowerService.armedAction === ""
            highlighted: !(PowerService.armedAction === "")
            text: qsTr("Confirm")
            onClicked: PowerService.confirmArmed()
        }

        SequentialAnimation {
            id: idQuestionSwap

            NumberAnimation {
                target: idPowerQuestion
                property: "opacity"
                to: 0
                duration: Globals.reducedMotion ? 0 : Math.round(Globals.hoverMs / 2)
            }

            NumberAnimation {
                target: idPowerQuestion
                property: "opacity"
                to: 1
                duration: Globals.reducedMotion ? 0 : Math.round(Globals.hoverMs / 2)
            }
        }
    }
}
