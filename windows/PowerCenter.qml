pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    panel: PowerService.panelState
    geometryName: "power.panel"

    PowerKeys {
        id: idPowerKeys

        active: root.panelVisible
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
        text: PowerService.headerSub
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
                armed: PowerService.isArmed(modelData ? modelData.id : "")
                separator: index < PowerService.actions.length - 1

                onActivated: PowerService.arm(modelData ? modelData.id : "")
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
            text: PowerService.question
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
