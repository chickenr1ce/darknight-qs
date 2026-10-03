pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

Card {
    id: root

    readonly property string activeThemeLabel: ThemeService.activeTheme === "" ? qsTr("No theme") : (ThemeService.activeDisplayName !== "" ? ThemeService.activeDisplayName : ThemeService.activeTheme)
    readonly property int backgroundPageSize: 4
    readonly property int backgroundPageCount: Math.max(1, Math.ceil(ThemeService.backgroundList.length / root.backgroundPageSize))
    readonly property var backgroundEntries: ThemeService.backgroundList
    readonly property var backgroundPageItems: root.backgroundEntries.slice(root.backgroundPage * root.backgroundPageSize, root.backgroundPage * root.backgroundPageSize + root.backgroundPageSize)

    property int backgroundPage: 0

    clickable: true
    accessibleName: qsTr("Open theme settings")

    onClicked: DashboardService.openSettings("theme")
    onBackgroundEntriesChanged: {
        if (root.backgroundEntries.length === 0)
            return;
        root.backgroundPage = root.pageForBackground(ThemeService.currentBackgroundName);
    }

    ColumnLayout {
        id: idThemeColumn

        Layout.fillWidth: true

        spacing: Globals.listSpacing

        Text {
            id: idThemeCaption

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Theme")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
                weight: Font.Medium
                letterSpacing: Globals.uiLetterSpacing
            }
        }

        Text {
            id: idThemeName

            Layout.fillWidth: true
            Layout.minimumWidth: 0

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.activeThemeLabel
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
                weight: Font.DemiBold
            }
        }

        RowLayout {
            id: idThemeSwatches

            Layout.fillWidth: true
            Layout.preferredHeight: Globals.uiDisplaySize

            spacing: Globals.fieldPadding

            Repeater {
                id: idThemeSwatchRepeater

                model: Colors.themeSwatches

                delegate: Rectangle {
                    id: idThemeSwatch

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1

                    required property color modelData

                    radius: Globals.pillRadius
                    color: idThemeSwatch.modelData
                    border.width: Globals.hairlineHeight
                    border.color: Colors.border
                }
            }
        }

        RowLayout {
            id: idBackgroundHeader

            Layout.fillWidth: true

            visible: ThemeService.backgroundList.length > 0
            spacing: Globals.fieldPadding

            Text {
                id: idBackgroundCaption

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: qsTr("Background")
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                    weight: Font.Medium
                    letterSpacing: Globals.uiLetterSpacing
                }
            }

            IconButton {
                id: idBackgroundPrevious

                Layout.alignment: Qt.AlignVCenter

                visible: root.backgroundPageCount > 1
                enabled: root.backgroundPage > 0
                glyph: Icons.chevronLeft
                glyphSize: Globals.uiCaptionSize
                restColor: Colors.textSubtle
                accessibleName: qsTr("Previous backgrounds")
                opacity: root.backgroundPage > 0 ? 1 : 0.4
                onClicked: root.stepBackgroundPage(-1)
            }

            Text {
                id: idBackgroundPageLabel

                Layout.alignment: Qt.AlignVCenter

                visible: root.backgroundPageCount > 1
                textFormat: Text.PlainText
                text: (root.backgroundPage + 1) + qsTr("/") + root.backgroundPageCount
                color: Colors.textSubtle

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiCaptionSize
                }
            }

            IconButton {
                id: idBackgroundNext

                Layout.alignment: Qt.AlignVCenter

                visible: root.backgroundPageCount > 1
                enabled: root.backgroundPage < root.backgroundPageCount - 1
                glyph: Icons.chevronRight
                glyphSize: Globals.uiCaptionSize
                restColor: Colors.textSubtle
                accessibleName: qsTr("Next backgrounds")
                opacity: root.backgroundPage < root.backgroundPageCount - 1 ? 1 : 0.4
                onClicked: root.stepBackgroundPage(1)
            }
        }

        GridLayout {
            id: idBackgroundGrid

            Layout.fillWidth: true

            visible: ThemeService.backgroundList.length > 0
            columns: 2
            columnSpacing: Globals.fieldPadding
            rowSpacing: Globals.fieldPadding

            Repeater {
                id: idBackgroundRepeater

                model: root.backgroundPageItems

                delegate: BackgroundTile {
                    id: idBackgroundTile

                    Layout.fillWidth: true
                    Layout.preferredHeight: Globals.backgroundTileHeight

                    required property var modelData

                    source: modelData.url
                    active: modelData.name === ThemeService.currentBackgroundName
                    accessibleName: modelData.name
                    onClicked: ThemeService.selectBackground(modelData.name)
                }
            }

            WheelHandler {
                id: idBackgroundWheel

                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y < 0)
                        root.stepBackgroundPage(1);
                    else if (event.angleDelta.y > 0)
                        root.stepBackgroundPage(-1);
                }
            }
        }
    }

    function pageForBackground(name: string): int {
        const entries = root.backgroundEntries;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].name === name)
                return Math.floor(i / root.backgroundPageSize);
        }
        return 0;
    }

    function stepBackgroundPage(delta: int): void {
        const next = root.backgroundPage + delta;
        if (next < 0 || next >= root.backgroundPageCount)
            return;
        root.backgroundPage = next;
    }
}
