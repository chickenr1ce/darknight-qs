pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    property string label: ""
    property string glyph: ""
    property string hint: ""
    property bool armed: false
    property bool separator: false
    property int glyphSize: Globals.uiDisplaySize
    property int glyphOpticalNudge: 1
    property real layoutScale: 1

    readonly property int rowHeight: root.glyphSize + 2 * root.px(root.px(Globals.cardPadding))
    readonly property bool hovered: idRowMouseArea.containsMouse
    readonly property bool pressed: idRowMouseArea.containsPress

    signal activated()

    implicitWidth: idRowLayout.implicitWidth + 2 * root.px(root.px(Globals.cardHPadding))
    implicitHeight: root.rowHeight + (root.separator ? root.px(root.px(Globals.hairlineHeight)) : 0)
    scale: idRowPressScale.scale

    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: root.label

    Rectangle {
        id: idRowWash

        anchors.fill: parent

        color: Colors.cardSecondary
        opacity: root.armed || root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.hoverMs
                easing.type: Easing.OutQuad
            }
        }
    }

    Rectangle {
        id: idRowEdge

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        width: root.px(Globals.armedEdgeWidth)
        height: root.rowHeight - 2 * root.px(Globals.cardPadding)

        color: Colors.accent
        opacity: root.armed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Globals.hoverMs
                easing.type: Easing.OutQuad
            }
        }
    }

    RowLayout {
        id: idRowLayout

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: root.px(Globals.cardHPadding)
            rightMargin: root.px(Globals.cardHPadding)
        }

        height: root.rowHeight
        spacing: root.px(Globals.rowSpacing)

        Rectangle {
            id: idRowGlyphBox

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.glyphSize
            Layout.preferredHeight: root.glyphSize

            radius: root.px(Globals.cardRadius)
            color: Colors.cardSecondary
            scale: root.pressed ? Globals.pressScaleModule : (root.armed ? 1.08 : 1.0)

            Behavior on scale {
                NumberAnimation {
                    duration: Globals.reducedMotion ? 0 : (root.pressed ? Globals.pressReleaseMs : Globals.pressMs)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Globals.easeOutCurve
                }
            }

            Rectangle {
                id: idRowGlyphGlow

                anchors.fill: parent

                radius: root.px(Globals.cardRadius)
                color: Colors.surface
                opacity: root.armed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Globals.hoverMs
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Text {
                id: idRowGlyph

                anchors {
                    centerIn: parent
                    horizontalCenterOffset: root.px(root.glyphOpticalNudge)
                }

                textFormat: Text.PlainText
                text: root.glyph
                color: Colors.accent

                font {
                    family: Globals.iconFontFamily
                    pixelSize: root.px(Globals.fontPixelSize)
                    weight: Font.DemiBold
                }
            }
        }

        Text {
            id: idRowLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.label
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: root.px(Globals.uiBodySize)
            }
        }

        Rectangle {
            id: idRowHintChip

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: idRowHintLabel.implicitWidth + 2 * root.px(Globals.fieldPadding)
            Layout.preferredHeight: idRowHintLabel.implicitHeight + 2 * root.px(Globals.hairlineHeight)

            radius: root.px(Globals.pillRadius)
            color: "transparent"
            border.width: root.px(Globals.hairlineHeight)
            border.color: root.armed ? Colors.accent : Colors.border

            Text {
                id: idRowHintLabel

                anchors.centerIn: parent

                textFormat: Text.PlainText
                text: root.hint
                color: root.armed ? Colors.text : Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: root.px(Globals.uiCaptionSize)
                }
            }
        }
    }

    PressScale {
        id: idRowPressScale

        pressed: root.pressed
        pressedScale: Globals.pressScaleRow
    }

    MouseArea {
        id: idRowMouseArea

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Rectangle {
        id: idRowDivider

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.px(Globals.cardHPadding)
            rightMargin: root.px(Globals.cardHPadding)
        }

        height: root.px(Globals.hairlineHeight)
        visible: root.separator
        color: Colors.border
    }

    function px(value): int {
        return Math.round(value * root.layoutScale);
    }
}
