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
