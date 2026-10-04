pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string activeKey: SettingsService.sections.length > 0 ? SettingsService.sections[0].key : ""

    readonly property string query: idSettingsSearch.text.trim()
    readonly property var visibleSections: SettingsService.sections.filter(section => root.sectionMatches(section))
    readonly property var currentSection: root.visibleSections.find(section => section.key === root.activeKey) ?? root.visibleSections[0] ?? null
    readonly property bool hasSection: !(root.currentSection === null)
    readonly property bool searching: !(root.query === "")
    readonly property bool titleMatched: root.hasSection && root.searching && root.currentSection.title.toLowerCase().includes(root.query.toLowerCase())
    readonly property string bodyFilter: root.titleMatched ? "" : root.query
    readonly property bool noMatch: root.searching && root.visibleSections.length === 0

    spacing: Globals.spacing

    Connections {
        id: idSettingsTarget

        target: SettingsService

        function onTargetSectionChanged(): void {
            root.activeKey = SettingsService.targetSection !== ""
                ? SettingsService.targetSection
                : (SettingsService.sections.length > 0 ? SettingsService.sections[0].key : "");
        }
    }

    function sectionMatches(section): bool {
        if (root.query === "")
            return true;
        const query = root.query.toLowerCase();
        if (section.title.toLowerCase().includes(query))
            return true;
        return section.options.some(option => option.toLowerCase().includes(query));
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

        spacing: Globals.rowSpacing

        ColumnLayout {
            id: idSettingsRail

            Layout.preferredWidth: Globals.settingsSidebarWidth
            Layout.minimumWidth: Globals.settingsSidebarWidth
            Layout.maximumWidth: Globals.settingsSidebarWidth
            Layout.alignment: Qt.AlignTop

            spacing: Globals.listSpacing

            Repeater {
                id: idSettingsNav

                model: root.visibleSections

                delegate: NavItem {
                    Layout.fillWidth: true

                    required property var modelData

                    text: modelData.title
                    active: root.hasSection && modelData.key === root.currentSection.key
                    disabled: modelData.comingSoon
                    onClicked: SettingsService.requestSection(modelData.key)
                }
            }
        }

        Card {
            id: idSettingsCard

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 0

            Text {
                id: idSettingsSectionTitle

                Layout.fillWidth: true
                Layout.minimumWidth: 0

                visible: root.hasSection

                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: root.hasSection ? root.currentSection.title : ""
                color: Colors.text

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiTitleSize
                    weight: Font.DemiBold
                }
            }

            Flickable {
                id: idSettingsScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Math.min(idSettingsScroll.contentHeight, Globals.settingsBodyMaxHeight)
                Layout.maximumHeight: Globals.settingsBodyMaxHeight

                contentWidth: width
                contentHeight: idSettingsSectionBody.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: idSettingsSectionBody

                    width: idSettingsScroll.width
                    spacing: Globals.spacing

                    CavaSettingsView {
                        id: idCavaSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "cava"
                        filter: root.bodyFilter
                    }

                    CalendarSettingsView {
                        id: idCalendarSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "calendar"
                        filter: root.bodyFilter
                    }

                    NotificationSettingsView {
                        id: idNotificationSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "notifications"
                        filter: root.bodyFilter
                    }

                    MotionSettingsView {
                        id: idMotionSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "motion"
                        filter: root.bodyFilter
                    }

                    LayoutSettingsView {
                        id: idLayoutSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "layout"
                        filter: root.bodyFilter
                    }

                    MonitorSettingsView {
                        id: idMonitorSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "monitors"
                        filter: root.bodyFilter
                    }

                    WeatherSettingsView {
                        id: idWeatherSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "weather"
                        filter: root.bodyFilter
                    }

                    ThemeSettingsView {
                        id: idThemeSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "theme"
                        filter: root.bodyFilter
                    }

                    DashboardSettingsView {
                        id: idDashboardSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "dashboard"
                        filter: root.bodyFilter
                    }

                    AudioSettingsView {
                        id: idAudioSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "audio"
                        filter: root.bodyFilter
                    }

                    FontsSettingsView {
                        id: idFontsSection

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.key === "fonts"
                        filter: root.bodyFilter
                    }

                    Text {
                        id: idComingSoonNote

                        Layout.fillWidth: true

                        visible: root.hasSection && root.currentSection.comingSoon

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

                        visible: root.noMatch

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
