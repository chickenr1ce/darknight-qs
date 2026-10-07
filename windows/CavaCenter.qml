pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services

PanelShell {
    id: root

    panel: CavaService.panelState

    PanelHeader {
        id: idCavaHeader

        title: qsTr("Cava")
        showBadge: false
    }

    CavaSettingsView {
        id: idCavaSettings

        Layout.fillWidth: true
    }
}
