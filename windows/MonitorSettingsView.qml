pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

ColumnLayout {
    id: root

    property string filter: ""

    readonly property var primaryOptions: [qsTr("Auto")].concat(MonitorService.screenNames)
    readonly property int primaryIndex: {
        const override = Globals.primaryMonitorOverride;
        if (override === "")
            return 0;
        const index = MonitorService.screenNames.indexOf(override);
        return index === -1 ? 0 : index + 1;
    }
    readonly property bool primaryVisible: SettingsFilter.matches(root.filter, qsTr("Primary monitor"))
        || MonitorService.screenNames.some(name => SettingsFilter.matches(root.filter, name))
    readonly property bool displaysRelevant: SettingsFilter.matches(root.filter, qsTr("Displays"))

    spacing: Globals.spacing

    RowLayout {
        id: idPrimaryRow

        Layout.fillWidth: true

        visible: root.primaryVisible
        spacing: Globals.rowSpacing

        Text {
            id: idPrimaryLabel

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: qsTr("Primary monitor")
            color: Colors.text

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }

        Dropdown {
            id: idPrimaryDropdown

            Layout.alignment: Qt.AlignVCenter

            options: root.primaryOptions
            currentIndex: root.primaryIndex
            accessibleName: qsTr("Primary monitor")
            onSelected: index => root.selectPrimary(index)
        }
    }

    Text {
        id: idDisplaysHint

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.displaysRelevant
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("Turn a display off to remove it from the layout, or back on to restore its mode and position. The last display stays on, and a reboot or config reload turns everything back on.")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    Repeater {
        id: idMonitorToggles

        model: MonitorService.monitorNames

        delegate: SettingsToggleRow {
            id: idMonitorToggle

            Layout.fillWidth: true

            required property string modelData

            readonly property var row: MonitorService.rowState(idMonitorToggle.modelData)
            readonly property var monitor: idMonitorToggle.row?.monitor ?? null
            readonly property bool monitorRelevant: root.displaysRelevant
                || SettingsFilter.matches(root.filter, idMonitorToggle.modelData)
                || SettingsFilter.matches(root.filter, idMonitorToggle.monitor?.model ?? "")
                || SettingsFilter.matches(root.filter, idMonitorToggle.monitor?.description ?? "")
            readonly property bool lastDisplay: idMonitorToggle.row?.lastDisplay ?? false

            visible: idMonitorToggle.monitorRelevant && idMonitorToggle.monitor !== null
            label: idMonitorToggle.modelData
            hint: idMonitorToggle.lastDisplay ? qsTr("Last display, stays on") : ((idMonitorToggle.monitor?.model ?? "") !== "" ? idMonitorToggle.monitor.model : (idMonitorToggle.monitor?.description ?? ""))
            value: !(idMonitorToggle.monitor?.disabled ?? true)
            locked: MonitorService.toggleBusy || idMonitorToggle.lastDisplay
            onToggled: MonitorService.setEnabled(idMonitorToggle.modelData, idMonitorToggle.monitor?.disabled ?? false)
        }
    }

    Text {
        id: idDisplaysEmpty

        Layout.fillWidth: true
        Layout.minimumWidth: 0

        visible: root.displaysRelevant && MonitorService.monitorsLoaded && MonitorService.monitors.length === 0
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: qsTr("No displays detected")
        color: Colors.textSubtle

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiBodySize
        }
    }

    SettingsSliderRow {
        id: idWorkspacesRow

        Layout.fillWidth: true

        visible: SettingsFilter.matches(root.filter, qsTr("Workspaces per monitor"))
        label: qsTr("Workspaces per monitor")
        from: 1
        to: 20
        stepSize: 1
        value: MonitorService.workspacesPerMonitor
        onMoved: newValue => MonitorService.setWorkspacesPerMonitor(newValue)
    }

    function selectPrimary(index: int): void {
        if (index <= 0) {
            MonitorService.setPrimary("");
            return;
        }
        if (index - 1 < MonitorService.screenNames.length)
            MonitorService.setPrimary(MonitorService.screenNames[index - 1]);
    }
}
