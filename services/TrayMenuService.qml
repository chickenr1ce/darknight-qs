pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import "TrayMenuLogic.js" as TrayMenuLogic

Singleton {
    id: root

    readonly property PanelState panelState: idPanelState

    property SystemTrayItem item: null
    property bool menuShown: false

    readonly property var items: {
        const top = root.entryList(idRootOpener);
        const children = [];
        for (let i = 0; i < idChildOpeners.count; i++)
            children.push(root.entryList(idChildOpeners.objectAt(i)));
        return TrayMenuLogic.describe(top, children);
    }

    PanelState {
        id: idPanelState
    }

    QsMenuOpener {
        id: idRootOpener

        menu: (idPanelState.visible || root.menuShown) && root.item ? root.item.menu : null
    }

    Instantiator {
        id: idChildOpeners

        model: idRootOpener.children

        delegate: QsMenuOpener {
            required property var modelData

            menu: modelData && modelData.hasChildren ? modelData : null
        }
    }

    function toggleFor(trayItem, screen, centerX: real): void {
        if (root.item === trayItem) {
            Panels.toggleAt(idPanelState, screen, centerX);
            return;
        }
        root.item = trayItem;
        Panels.openAt(idPanelState, screen, centerX);
    }

    function dismiss(): void {
        idPanelState.closeFromOutside();
    }

    function entryList(opener): var {
        return opener && opener.children ? opener.children.values : [];
    }
}
