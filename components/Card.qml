pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Shared card container: history, toast, group rows, calendar rows share fill and border.
Rectangle {
    id: root

    property bool critical: false
    property bool clickable: false
    property string accessibleName: ""

    default property alias content: idCardLayout.data

    signal clicked()

    implicitWidth: parent ? parent.width : 0
    implicitHeight: idCardLayout.implicitHeight
        + idCardLayout.anchors.topMargin + idCardLayout.anchors.bottomMargin

    radius: Globals.cardRadius
    color: root.critical ? Colors.criticalCard : Colors.card
    border.width: 1
    border.color: root.critical ? Colors.criticalCardBorder : Colors.border

    MouseArea {
        id: idCardClick

        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor

        Accessible.role: root.clickable ? Accessible.Button : Accessible.NoRole
        Accessible.name: root.accessibleName

        onClicked: root.clicked()
    }

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
