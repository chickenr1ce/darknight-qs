pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property var options: []
    property int currentIndex: -1
    property bool open: false
    property string accessibleName: ""

    signal selected(int index)

    readonly property string currentText: root.currentIndex >= 0 && root.currentIndex < root.options.length ? root.options[root.currentIndex] : ""
    readonly property int triggerHeight: 28

    implicitWidth: 120
    implicitHeight: root.triggerHeight + (root.open ? idDropdownList.implicitHeight + 4 : 0)
    activeFocusOnTab: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: root.accessibleName

    Keys.onSpacePressed: root.open = !root.open
    Keys.onReturnPressed: root.open = !root.open
    Keys.onEnterPressed: root.open = !root.open
    Keys.onEscapePressed: root.open = false
    Keys.onDownPressed: root.nudge(1)
    Keys.onUpPressed: root.nudge(-1)

    Rectangle {
        id: idDropdownTrigger

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: root.triggerHeight

        radius: Globals.pillRadius
        color: Colors.cardSecondary
        border.width: Globals.hairlineHeight
        border.color: root.open || idDropdownTriggerMouseArea.containsMouse ? Colors.accent : Colors.border

        Text {
            id: idDropdownCurrent

            anchors {
                left: parent.left
                right: idDropdownChev.left
                verticalCenter: parent.verticalCenter
                leftMargin: Globals.pillHPadding
                rightMargin: Globals.rowSpacing
            }

            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.currentText
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Text {
            id: idDropdownChev

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: Globals.pillHPadding
            }

            textFormat: Text.PlainText
            text: root.open ? "▴" : "▾"
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        MouseArea {
            id: idDropdownTriggerMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.open = !root.open;
                if (root.open)
                    root.forceActiveFocus();
            }
        }
    }

    Column {
        id: idDropdownList

        anchors {
            top: idDropdownTrigger.bottom
            left: parent.left
            right: parent.right
            topMargin: 4
        }

        visible: root.open
        spacing: 2

        Repeater {
            id: idDropdownRepeater

            model: root.options

            delegate: Item {
                id: idDropdownOption

                width: idDropdownList.width
                height: root.triggerHeight

                required property string modelData
                required property int index

                Rectangle {
                    id: idDropdownOptionBg

                    anchors.fill: parent

                    radius: Globals.pillRadius
                    color: Colors.cardSecondary
                    opacity: idDropdownOptionMouseArea.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Globals.hoverMs
                        }
                    }
                }

                Text {
                    id: idDropdownTick

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: Globals.pillHPadding
                    }

                    width: 12
                    textFormat: Text.PlainText
                    text: root.currentIndex === index ? "✓" : ""
                    color: Colors.accent

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                Text {
                    id: idDropdownLabel

                    anchors {
                        left: idDropdownTick.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Globals.rowSpacing
                        rightMargin: Globals.pillHPadding
                    }

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: modelData
                    color: root.currentIndex === index ? Colors.accent : Colors.text

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }

                MouseArea {
                    id: idDropdownOptionMouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.open = false;
                        root.selected(index);
                    }
                }
            }
        }
    }

    function nudge(dir: int): void {
        if (root.options.length === 0)
            return;
        if (!root.open) {
            root.open = true;
            root.forceActiveFocus();
            return;
        }
        const next = Math.max(0, Math.min(root.options.length - 1, root.currentIndex + dir));
        if (!(next === root.currentIndex))
            root.selected(next);
    }
}
