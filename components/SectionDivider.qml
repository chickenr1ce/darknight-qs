import QtQuick
import qs.config

// Hairline between panel sections. Its padding tops the host column's
// Globals.listSpacing up to Globals.spacing on each side, so sections sit
// further apart than the rows inside them.
Item {
    id: root

    implicitHeight: Globals.hairlineHeight + 2 * (Globals.spacing - Globals.listSpacing)

    Rectangle {
        id: idSectionDividerLine

        anchors.verticalCenter: parent.verticalCenter

        width: parent.width
        height: Globals.hairlineHeight
        color: Colors.border
    }
}
