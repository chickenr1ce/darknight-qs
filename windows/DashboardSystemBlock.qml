pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    component SystemSpec: RowLayout {
        id: idSystemSpec

        property string icon: ""
        property string label: ""
        property string value: ""

        spacing: Globals.fieldPadding

        Icon {
            id: idSystemSpecIcon

            Layout.alignment: Qt.AlignVCenter

            visible: !(idSystemSpec.icon === "")
            text: idSystemSpec.icon
            size: Globals.uiCaptionSize
            color: Colors.accent
        }

        Text {
            id: idSystemSpecLabel

            Layout.alignment: Qt.AlignVCenter

            visible: idSystemSpec.icon === ""
            textFormat: Text.PlainText
            text: idSystemSpec.label
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        Item {
            id: idSystemSpecGap

            Layout.fillWidth: true
        }

        Text {
            id: idSystemSpecValue

            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: idSystemSpec.value
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
            }
        }
    }

    RowLayout {
        id: idSystemRow

        Layout.fillWidth: true
        Layout.fillHeight: true

        spacing: Globals.rowSpacing

        ColumnLayout {
            id: idSystemIdentity

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.fieldPadding

            SystemSpec {
                id: idSystemDistro

                Layout.fillWidth: true

                icon: Icons.distro
                value: !(SystemInfo.distro === "") ? SystemInfo.distro : qsTr("Unknown")
            }

            SystemSpec {
                id: idSystemKernel

                Layout.fillWidth: true

                label: qsTr("KRNL")
                value: !(SystemInfo.kernelText === "") ? SystemInfo.kernelText : qsTr("Unknown")
            }

            SystemSpec {
                id: idSystemCompositor

                Layout.fillWidth: true

                label: qsTr("WM")
                value: !(SystemInfo.compositor === "") ? SystemInfo.compositor : qsTr("Unknown")
            }
        }

        Rectangle {
            id: idSystemDivider

            Layout.preferredWidth: Globals.hairlineHeight
            Layout.fillHeight: true

            color: Colors.border
        }

        ColumnLayout {
            id: idSystemEnvironment

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            spacing: Globals.fieldPadding

            SystemSpec {
                id: idSystemShell

                Layout.fillWidth: true

                label: qsTr("SHELL")
                value: !(SystemInfo.shellText === "") ? SystemInfo.shellText : qsTr("Unknown")
            }

            SystemSpec {
                id: idSystemUptime

                Layout.fillWidth: true

                label: qsTr("UP")
                value: !(SystemInfo.uptimeText === "") ? SystemInfo.uptimeText : qsTr("Unknown")
            }

            SystemSpec {
                id: idSystemPackages

                Layout.fillWidth: true

                label: qsTr("PKGS")
                value: !(SystemInfo.packagesText === "") ? SystemInfo.packagesText : qsTr("Unknown")
            }
        }
    }
}
