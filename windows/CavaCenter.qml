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

    CavaSettingsView {
        id: idCavaSettings

        Layout.fillWidth: true
    }
}
