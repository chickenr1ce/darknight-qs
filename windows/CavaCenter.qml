pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    anchorScreen: CavaService.anchorScreen
    anchorCenterX: CavaService.anchorCenterX
    panelVisible: CavaService.cavaVisible
    onOutsideClicked: CavaService.closeCavaFromOutside()

    PanelHeader {
        id: idCavaHeader

        title: qsTr("Cava")
        showBadge: false
    }

    Dropdown {
        id: idCavaStyleDropdown

        Layout.fillWidth: true

        options: CavaService.styleNames
        currentIndex: CavaService.styleMode
        accessibleName: qsTr("Style")
        onSelected: index => CavaService.setStyleMode(index)
    }

    Rectangle {
        id: idCavaSectionDivider

        Layout.fillWidth: true
        Layout.preferredHeight: Globals.hairlineHeight

        color: Colors.border
    }

    RowLayout {
        id: idCavaSensitivityRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idCavaSensitivityLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Sensitivity")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Text {
            id: idCavaSensitivityValue

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idCavaSensitivityMetrics.width

            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: CavaService.sensitivity
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        TextMetrics {
            id: idCavaSensitivityMetrics

            text: "5000"

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }
    }

    Slider {
        id: idCavaSensitivitySlider

        Layout.fillWidth: true

        from: CavaService.minSensitivity
        to: CavaService.maxSensitivity
        stepSize: 50
        value: CavaService.sensitivity
        disabled: CavaService.autoSensitivity
        accessibleName: qsTr("Sensitivity")
        onMoved: newValue => CavaService.sensitivity = Math.round(newValue)
    }

    RowLayout {
        id: idCavaAutoRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idCavaAutoLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Auto sensitivity")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        PillButton {
            id: idCavaAutoButton

            Layout.alignment: Qt.AlignVCenter

            text: qsTr("Auto")
            highlighted: CavaService.autoSensitivity
            onClicked: CavaService.autoSensitivity = !CavaService.autoSensitivity
        }
    }

    RowLayout {
        id: idCavaBarsRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idCavaBarsLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Bars")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        IconButton {
            id: idCavaBarsMinus

            Layout.alignment: Qt.AlignVCenter

            glyph: "−"
            accessibleName: qsTr("Fewer bars")
            onClicked: CavaService.barCount = Math.max(CavaService.minBarCount, CavaService.barCount - 1)
        }

        Text {
            id: idCavaBarsValue

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idCavaBarsMetrics.width

            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: CavaService.barCount
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        TextMetrics {
            id: idCavaBarsMetrics

            text: "32"

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        IconButton {
            id: idCavaBarsPlus

            Layout.alignment: Qt.AlignVCenter

            glyph: "+"
            accessibleName: qsTr("More bars")
            onClicked: CavaService.barCount = Math.min(CavaService.maxBarCount, CavaService.barCount + 1)
        }
    }

    RowLayout {
        id: idCavaMaxHeightRow

        Layout.fillWidth: true

        spacing: Globals.rowSpacing

        Text {
            id: idCavaMaxHeightLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Max height")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Text {
            id: idCavaMaxHeightValue

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idCavaMaxHeightMetrics.width

            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            text: CavaService.maxHeight
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }

        TextMetrics {
            id: idCavaMaxHeightMetrics

            text: "20"

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.Medium
            }
        }
    }

    Slider {
        id: idCavaMaxHeightSlider

        Layout.fillWidth: true

        from: CavaService.minMaxHeight
        to: CavaService.maxMaxHeight
        stepSize: 1
        value: CavaService.maxHeight
        accessibleName: qsTr("Max height")
        onMoved: newValue => CavaService.maxHeight = Math.round(newValue)
    }
}
