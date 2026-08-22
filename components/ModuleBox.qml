import QtQuick
import QtQuick.Layouts
import "../config"

// Rounded, translucent container matching waybar's #module styling.
// Emits clicked(mouse) so modules don't need their own MouseArea.
Rectangle {
    id: root

    color: Colors.background
    radius: Globals.radius
    implicitHeight: Globals.barHeight
    implicitWidth: idModuleBoxLayout.implicitWidth + 2 * root.horizontalPadding

    property int horizontalPadding: Globals.modulePadding

    signal clicked(var mouse)
    signal wheelMoved(var wheel)

    // When true (default) the whole box is one click target.
    // Set false for containers with their own interactive children
    // like Workspaces where each button handles its own clicks.
    property bool enableMouseArea: true

    default property alias content: idModuleBoxLayout.data

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
