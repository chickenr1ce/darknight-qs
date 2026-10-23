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

    panel: PowerService.panelState
    geometryName: "power.panel"

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
        id: idPowerKey6

        enabled: root.panelVisible
        sequence: "6"
        onActivated: PowerService.arm("winboot")
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

            delegate: PowerActionRow {
                id: idPowerRowItem

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight

                required property var modelData
                required property int index

                label: modelData ? modelData.label : ""
                glyph: modelData ? modelData.glyph : ""
                hint: modelData ? modelData.hint : ""
                armed: PowerService.isArmed(modelData ? modelData.actionId : "")
                separator: index < PowerService.actions.length - 1

                onActivated: PowerService.arm(modelData ? modelData.actionId : "")
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

            onTextChanged: idQuestionSwap.restart()
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
                duration: Math.round(Globals.hoverMs / 2)
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: idPowerQuestion
                property: "opacity"
                to: 1
                duration: Math.round(Globals.hoverMs / 2)
                easing.type: Easing.OutQuad
            }
        }
    }
}
