pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Shared card container: history, toast, group rows, calendar rows share fill and border.
Rectangle {
    id: root

    property bool critical: false

    default property alias content: idCardLayout.data

    implicitWidth: parent ? parent.width : 0
    implicitHeight: idCardLayout.implicitHeight
        + idCardLayout.anchors.topMargin + idCardLayout.anchors.bottomMargin

    radius: Globals.cardRadius
    color: root.critical ? Colors.criticalCard : Colors.card
    border.width: 1
    border.color: root.critical ? Colors.criticalCardBorder : Colors.border

    ColumnLayout {
        id: idCardLayout

        anchors {
            fill: parent
            margins: Globals.cardPadding
            leftMargin: Globals.cardHPadding
            rightMargin: Globals.cardHPadding
        }

        spacing: 6
    }
}
