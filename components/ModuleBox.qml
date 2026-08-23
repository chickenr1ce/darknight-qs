import QtQuick
import QtQuick.Layouts
import qs.config

// Rounded, translucent container matching waybar's #module styling.
// Emits clicked(mouse) so modules don't need their own MouseArea.
Rectangle {
    id: root

    property int horizontalPadding: Globals.modulePadding
    property int maxWidth: 0
    property int minWidth: 0

    // When true (default) the whole box is one click target.
    // Set false for containers with their own interactive children
    // like Workspaces where each button handles its own clicks.
    property bool enableMouseArea: true

    default property alias content: idModuleBoxLayout.data

    signal clicked(var mouse)
    signal wheelMoved(var wheel)

    implicitHeight: Globals.barHeight
    implicitWidth: {
        let w = idModuleBoxLayout.implicitWidth + 2 * root.horizontalPadding;
        if (root.minWidth != 0)
            w = Math.max(w, root.minWidth);
        if (root.maxWidth != 0)
            w = Math.min(w, root.maxWidth);
        return w;
    }

    color: Colors.background
    radius: Globals.radius

    RowLayout {
        id: idModuleBoxLayout

        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        spacing: Globals.spacing
    }

    MouseArea {
        id: idModuleBoxMouseArea

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent
        enabled: root.enableMouseArea
        z: 1

        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheelMoved(wheel)
    }
}
