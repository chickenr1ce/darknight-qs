pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

Loader {
    id: root

    readonly property string settingsWindowTitle: "Settings"

    active: SettingsService.visible
    sourceComponent: idSettingsPanel

    Connections {
        id: idSettingsPlacement

        target: Hyprland

        function onRawEvent(event): void {
            if (!(event.name === "openwindow"))
                return;
            const parts = event.parse(4);
            if (!((parts[2] ?? "") === "org.quickshell") || !((parts[3] ?? "") === root.settingsWindowTitle))
                return;
            const monitor = SettingsService.anchorScreen ? SettingsService.anchorScreen.name : "";
            if (monitor === "")
                return;
            const selector = "title:^" + root.settingsWindowTitle + "$";
            Hyprland.dispatch("hl.dsp.window.move({ monitor = \"" + monitor + "\", window = \"" + selector + "\" })");
            Hyprland.dispatch("hl.dsp.window.center({ window = \"" + selector + "\" })");
        }
    }

    Component {
        id: idSettingsPanel

        FloatingWindow {
            id: idSettingsWindow

            property string activeKey: SettingsService.sections.length > 0 ? SettingsService.sections[0].key : ""

            readonly property string query: idSettingsSearch.text.trim()
            readonly property var visibleSections: SettingsService.sections.filter(section => idSettingsWindow.sectionMatches(section))
            readonly property var currentSection: idSettingsWindow.visibleSections.find(section => section.key === idSettingsWindow.activeKey) ?? idSettingsWindow.visibleSections[0] ?? null
            readonly property bool hasSection: !(idSettingsWindow.currentSection === null)
            readonly property bool searching: !(idSettingsWindow.query === "")
            readonly property bool titleMatched: idSettingsWindow.hasSection && idSettingsWindow.searching && idSettingsWindow.currentSection.title.toLowerCase().includes(idSettingsWindow.query.toLowerCase())
            readonly property string bodyFilter: idSettingsWindow.titleMatched ? "" : idSettingsWindow.query
            readonly property bool noMatch: idSettingsWindow.searching && idSettingsWindow.visibleSections.length === 0

            title: root.settingsWindowTitle
            color: Colors.panel
            implicitWidth: Globals.settingsWidth
            implicitHeight: Globals.settingsHeight

            onClosed: Qt.callLater(() => SettingsService.close())

            function sectionMatches(section): bool {
                if (idSettingsWindow.query === "")
                    return true;
                const query = idSettingsWindow.query.toLowerCase();
                if (section.title.toLowerCase().includes(query))
                    return true;
                return section.options.some(option => option.toLowerCase().includes(query));
            }

            Shortcut {
                id: idSettingsEscape

                sequence: "Escape"
                onActivated: SettingsService.close()
            }

            ColumnLayout {
                id: idSettingsLayout

                spacing: Globals.spacing

                anchors {
                    fill: parent
                    margins: Globals.panelPadding
                }

                PanelHeader {
                    id: idSettingsHeader

                    title: qsTr("Settings")
                    showBadge: false

                    IconButton {
                        id: idSettingsClose

                        Layout.alignment: Qt.AlignVCenter

                        accessibleName: qsTr("Close settings")
                        onClicked: SettingsService.close()
                    }
                }

                Rectangle {
                    id: idSearchField

                    Layout.fillWidth: true
                    Layout.preferredHeight: idSettingsSearch.implicitHeight + 2 * Globals.fieldPadding

                    radius: Globals.pillRadius
                    color: Colors.cardSecondary
                    border.width: Globals.hairlineHeight
                    border.color: idSettingsSearch.activeFocus ? Colors.accent : Colors.border

                    TextInput {
                        id: idSettingsSearch

                        anchors.fill: parent
                        anchors.margins: Globals.fieldPadding

                        clip: true
                        color: Colors.text
                        selectByMouse: true

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                        }

                        Text {
                            anchors.fill: parent

                            verticalAlignment: Text.AlignVCenter
                            visible: idSettingsSearch.text === "" && !idSettingsSearch.activeFocus

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: qsTr("Search settings…")
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiBodySize
                            }
                        }
                    }
                }

                RowLayout {
                    id: idSettingsBody

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    spacing: Globals.rowSpacing

                    ColumnLayout {
                        id: idSettingsSidebar

                        Layout.preferredWidth: Globals.settingsSidebarWidth
                        Layout.minimumWidth: Globals.settingsSidebarWidth
                        Layout.maximumWidth: Globals.settingsSidebarWidth
                        Layout.alignment: Qt.AlignTop

                        spacing: Globals.listSpacing

                        Repeater {
                            id: idSettingsNav

                            model: idSettingsWindow.visibleSections

                            delegate: NavItem {
                                Layout.fillWidth: true

                                required property var modelData

                                text: modelData.title
                                active: idSettingsWindow.hasSection && modelData.key === idSettingsWindow.currentSection.key
                                disabled: modelData.comingSoon
                                onClicked: idSettingsWindow.activeKey = modelData.key
                            }
                        }
                    }

                    ColumnLayout {
                        id: idSettingsContent

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0

                        spacing: Globals.spacing

                        Flickable {
                            id: idSettingsScroll

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 0

                            contentWidth: width
                            contentHeight: idSettingsSectionBody.implicitHeight
                            clip: true
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: idSettingsSectionBody

                                width: idSettingsScroll.width
                                spacing: Globals.spacing

                                Text {
                                    id: idSettingsSectionTitle

                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0

                                    visible: idSettingsWindow.hasSection

                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    text: idSettingsWindow.hasSection ? idSettingsWindow.currentSection.title : ""
                                    color: Colors.text

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiTitleSize
                                        weight: Font.DemiBold
                                    }
                                }

                                CavaSettingsView {
                                    id: idCavaSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "cava"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                CalendarSettingsView {
                                    id: idCalendarSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "calendar"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                NotificationSettingsView {
                                    id: idNotificationSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "notifications"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                MotionSettingsView {
                                    id: idMotionSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "motion"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                LayoutSettingsView {
                                    id: idLayoutSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "layout"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                WeatherSettingsView {
                                    id: idWeatherSection

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.key === "weather"
                                    filter: idSettingsWindow.bodyFilter
                                }

                                Text {
                                    id: idComingSoonNote

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.hasSection && idSettingsWindow.currentSection.comingSoon

                                    textFormat: Text.PlainText
                                    text: qsTr("Coming soon")
                                    color: Colors.textSubtle

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiBodySize
                                    }
                                }

                                Text {
                                    id: idNoMatchNote

                                    Layout.fillWidth: true

                                    visible: idSettingsWindow.noMatch

                                    textFormat: Text.PlainText
                                    text: qsTr("No match")
                                    color: Colors.textSubtle

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiBodySize
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
