pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.components
import qs.config
import qs.dev
import qs.services

// Dashboard Workspaces tab, design 1a: one non-wrapping row of workspace maps
// per enabled monitor, each map drawing its windows at their real positions.
// Clicks switch, a drag moves a window, right click opens its menu, and middle
// click closes it; the dashboard stays open for all of them.
Item {
    id: root

    // "App — title" while a window is hovered, else ""; the address lets the
    // model watch clear a label whose delegate was destroyed (a middle-click
    // close) without onExited.
    property string hoveredLabel: ""
    property string hoveredAddress: ""
    readonly property bool tabVisible: root.visible && DashboardService.dashboardVisible

    // The model the Repeaters draw from. It follows WorkspaceService.model
    // except while a drag is active, so a rebuild (title or urgency updates
    // arrive constantly) cannot destroy the pressed delegate mid-gesture; it
    // catches up to the latest model when the drag ends.
    property var shownModel: []

    // Window-drag state: a ghost of the grabbed window follows the pointer
    // and the map under it is highlighted until the drop decides.
    property bool dragActive: false
    property string dragAddress: ""
    property int dragSourceId: -1
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragGhostWidth: 0
    property real dragGhostHeight: 0
    property color dragGhostColor: Colors.accent
    property point dragGrabOffset: Qt.point(0, 0)
    property int dropHighlightId: -1

    // Menu state: the window record and its descriptors are read at open time
    // and kept, so a model rebuild cannot pull the data out from under it.
    property var menuWindow: null
    property var menuItems: []
    property var menuHeader: null
    // Height of the dashboard window, set by the host; the window menu may
    // hang below the card down to the window's bottom edge.
    property real windowRoom: 0
    // The host panel's slide offset, so a menu opened mid-slide measures
    // against the settled card position.
    property real slideOffset: 0
    readonly property Item menuInputBox: idWorkspacesContextMenu.inputBox

    implicitWidth: idWorkspacesLayout.implicitWidth
    implicitHeight: idWorkspacesLayout.implicitHeight

    Component.onCompleted: root.shownModel = WorkspaceService.model

    onDragActiveChanged: {
        if (!root.dragActive)
            root.shownModel = WorkspaceService.model;
    }

    // A tab switch or a dashboard close must not leave a ghost, a highlight,
    // or an open menu behind, and must not commit a move the pointer never
    // completed.
    onTabVisibleChanged: {
        if (root.tabVisible)
            return;
        if (root.dragActive)
            root.abortDrag();
        idWorkspacesContextMenu.closeMenu();
    }

    Binding {
        id: idVisibleTabBinding

        target: WorkspaceService
        property: "visibleTab"
        value: root.tabVisible
    }

    Connections {
        id: idModelWatch

        target: WorkspaceService

        function onModelChanged(): void {
            if (!root.dragActive)
                root.shownModel = WorkspaceService.model;
            if (idWorkspacesContextMenu.opened && !root.addressInModel(root.menuWindow ? root.menuWindow.address : ""))
                idWorkspacesContextMenu.closeMenu();
            if (root.hoveredAddress !== "" && !root.addressInModel(root.hoveredAddress))
                root.clearHoveredWindow();
        }
    }

    ColumnLayout {
        id: idWorkspacesLayout

        anchors.fill: parent
        spacing: Globals.spacing

        Item {
            id: idWorkspacesScrollSlot

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: idWorkspacesFlick.contentHeight

            Flickable {
                id: idWorkspacesFlick

                anchors.fill: parent

                clip: true
                contentWidth: width
                contentHeight: idWorkspacesContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: ScrollBar { id: idWorkspacesScrollBar }

                Column {
                    id: idWorkspacesContent

                    width: idWorkspacesFlick.width - Globals.scrollbarGutter
                    spacing: Globals.spacing

                    Repeater {
                        id: idMonitorRepeater

                        model: root.shownModel

                        delegate: Column {
                            id: idMonitorSection

                            required property var modelData
                            required property int index

                            readonly property var monitor: idMonitorSection.modelData.monitor
                            readonly property var tiles: idMonitorSection.modelData.tiles
                            readonly property var tileRepeater: idTileRepeater

                            width: parent.width
                            spacing: Globals.listSpacing

                            RowLayout {
                                id: idMonitorHeader

                                width: parent.width
                                spacing: Globals.rowSpacing

                                Text {
                                    id: idMonitorName

                                    Layout.alignment: Qt.AlignVCenter

                                    textFormat: Text.PlainText
                                    text: idMonitorSection.monitor.name
                                    color: Colors.text

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiCaptionSize
                                        weight: Font.Medium
                                        letterSpacing: Globals.uiLetterSpacing
                                    }
                                }

                                Text {
                                    id: idMonitorResolution

                                    Layout.alignment: Qt.AlignVCenter

                                    textFormat: Text.PlainText
                                    text: Math.round(idMonitorSection.monitor.logicalWidth) + "×"
                                        + Math.round(idMonitorSection.monitor.logicalHeight)
                                    color: Colors.textFaint

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiCaptionSize
                                    }
                                }

                                Rectangle {
                                    id: idMonitorHairline

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Globals.hairlineHeight
                                    Layout.alignment: Qt.AlignVCenter

                                    color: Colors.border
                                }

                                Text {
                                    id: idMonitorFocused

                                    Layout.alignment: Qt.AlignVCenter

                                    visible: MonitorService.multiMonitor && idMonitorSection.monitor.focused
                                    textFormat: Text.PlainText
                                    text: qsTr("focused")
                                    color: Colors.accent

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiCaptionSize
                                        weight: Font.Medium
                                        letterSpacing: Globals.uiLetterSpacing
                                    }
                                }
                            }

                            Row {
                                id: idMonitorRow

                                width: parent.width
                                spacing: Globals.rowSpacing

                                Repeater {
                                    id: idTileRepeater

                                    model: idMonitorSection.tiles

                                    delegate: Column {
                                        id: idTile

                                        required property var modelData
                                        required property int index

                                        readonly property bool compact: idTile.width
                                            < Globals.workspaceTileCompactWidth
                                        readonly property bool current: idTile.modelData.state === "current"
                                        readonly property bool shown: idTile.modelData.state === "shown"
                                        readonly property Item mapItem: idTileMap
                                        readonly property int workspaceId: idTile.modelData.id
                                        readonly property real mapHeight: {
                                            const monitor = idMonitorSection.monitor;
                                            const aspect = monitor.logicalHeight > 0
                                                ? monitor.logicalWidth / monitor.logicalHeight : 1;
                                            return idTile.width / aspect;
                                        }

                                        width: WorkspaceService.tileWidth(idMonitorRow.width,
                                            Math.max(1, idMonitorSection.tiles.length), Globals.rowSpacing)
                                        spacing: Globals.listSpacing

                                        Rectangle {
                                            id: idTileMap

                                            readonly property bool dropHovered: root.dropHighlightId === idTile.modelData.id

                                            width: parent.width
                                            height: idTile.mapHeight

                                            radius: Globals.cardRadius
                                            color: idTileMap.dropHovered
                                                ? Colors.accentDim
                                                : idTile.modelData.empty ? "transparent" : Colors.backgroundSecondary
                                            border.width: idTile.current
                                                ? Globals.workspaceTileCurrentBorderWidth
                                                : Globals.hairlineHeight
                                            border.color: idTileMap.dropHovered
                                                ? Colors.accent
                                                : idTile.current
                                                    ? Colors.accent
                                                    : idTile.shown
                                                        ? Colors.mixInto(Colors.border, Colors.accent,
                                                            Globals.workspaceTileShownBorderMix)
                                                        : Colors.border

                                            // Left only: the map background is inert for
                                            // middle and right clicks.
                                            MouseArea {
                                                id: idTileMapInput

                                                anchors.fill: parent
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: Qt.PointingHandCursor

                                                // On press, not release: the background has no
                                                // drag, so nothing waits for the button to lift.
                                                onPressed: WorkspaceService.switchTo(idTile.modelData.id)
                                            }

                                            Icon {
                                                id: idTileEmptyGlyph

                                                anchors.centerIn: parent

                                                visible: idTile.modelData.empty
                                                text: Icons.plus
                                                size: Globals.uiCaptionSize
                                                color: Colors.textFaint
                                            }

                                            Repeater {
                                                id: idWindowRepeater

                                                model: idTile.modelData.windows

                                                delegate: Rectangle {
                                                    id: idWindow

                                                    required property var modelData
                                                    required property int index

                                                    readonly property real gap: idWindow.modelData.fullscreen
                                                        ? 0 : Globals.workspaceWindowGap
                                                    readonly property color appColor: Colors.appColor(idWindow.modelData.cls)
                                                    readonly property string hoverLabel: idWindow.modelData.app
                                                        + " — " + idWindow.modelData.title
                                                    readonly property bool fitsIcon: idWindow.width
                                                            >= Globals.workspaceWindowIconSize
                                                                + 2 * Globals.workspaceWindowIconMargin
                                                        && idWindow.height
                                                            >= Globals.workspaceWindowIconSize
                                                                + 2 * Globals.workspaceWindowIconMargin

                                                    x: Math.round(idWindow.modelData.rect.x * idTileMap.width + idWindow.gap)
                                                    y: Math.round(idWindow.modelData.rect.y * idTileMap.height + idWindow.gap)
                                                    width: Math.max(0, idWindow.modelData.rect.width * idTileMap.width
                                                        - 2 * idWindow.gap)
                                                    height: Math.max(0, idWindow.modelData.rect.height * idTileMap.height
                                                        - 2 * idWindow.gap)

                                                    radius: Globals.radius
                                                    color: Colors.mixInto(Colors.backgroundSecondary, idWindow.appColor,
                                                        Globals.workspaceWindowFillMix)
                                                    border.width: Globals.hairlineHeight
                                                    border.color: idWindow.modelData.focused
                                                        ? Colors.accent
                                                        : Colors.mixInto(Colors.backgroundSecondary, idWindow.appColor,
                                                            Globals.workspaceWindowBorderMix)

                                                    AppIcon {
                                                        id: idWindowIcon

                                                        anchors.centerIn: parent

                                                        visible: idWindow.fitsIcon
                                                        name: idWindow.modelData.cls
                                                        source: idWindow.modelData.icon
                                                        size: Globals.workspaceWindowIconSize
                                                        tileColor: idWindow.appColor
                                                    }

                                                    Rectangle {
                                                        id: idWindowUrgent

                                                        anchors {
                                                            top: parent.top
                                                            right: parent.right
                                                            margins: Globals.hairlineHeight
                                                        }

                                                        visible: idWindow.modelData.urgent === true
                                                        width: Globals.appDotSize
                                                        height: Globals.appDotSize
                                                        radius: Globals.appDotSize / 2
                                                        color: Colors.danger
                                                    }

                                                    // A MouseArea, not a DragHandler, so hover, press,
                                                    // and drag share one item and the action branches
                                                    // per button. Left drags or switches, middle closes,
                                                    // right opens the menu; a drag never starts on a
                                                    // middle or right press.
                                                    MouseArea {
                                                        id: idWindowInput

                                                        property bool dragging: false
                                                        property int pressButton: Qt.NoButton
                                                        property point pressScene: Qt.point(0, 0)

                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        preventStealing: true
                                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                                        cursorShape: Qt.PointingHandCursor

                                                        onEntered: {
                                                            root.hoveredAddress = idWindow.modelData.address;
                                                            root.hoveredLabel = idWindow.hoverLabel;
                                                        }
                                                        onExited: {
                                                            if (root.hoveredLabel === idWindow.hoverLabel)
                                                                root.clearHoveredWindow();
                                                        }
                                                        onPressed: mouse => {
                                                            idWindowInput.dragging = false;
                                                            idWindowInput.pressButton = mouse.button;
                                                            idWindowInput.pressScene = idWindowInput.mapToItem(root, mouse.x, mouse.y);
                                                        }
                                                        onPositionChanged: mouse => {
                                                            if (!pressed || idWindowInput.pressButton !== Qt.LeftButton)
                                                                return;
                                                            const point = idWindowInput.mapToItem(root, mouse.x, mouse.y);
                                                            if (!idWindowInput.dragging) {
                                                                if (Math.abs(point.x - idWindowInput.pressScene.x)
                                                                        < Globals.workspaceDragThreshold
                                                                    && Math.abs(point.y - idWindowInput.pressScene.y)
                                                                        < Globals.workspaceDragThreshold)
                                                                    return;
                                                                idWindowInput.dragging = true;
                                                                root.beginDrag(idWindow.modelData.address, idTile.modelData.id,
                                                                    idWindow.width, idWindow.height, idWindow.appColor,
                                                                    point, Qt.point(mouse.x, mouse.y));
                                                            }
                                                            root.updateDrag(point);
                                                        }
                                                        onReleased: {
                                                            if (idWindowInput.dragging)
                                                                root.endDrag();
                                                        }
                                                        // clicked only fires when press and release are
                                                        // both inside this window; a completed drag keeps
                                                        // dragging set, so it does not also switch. A window
                                                        // switches on click, not press, because a press may
                                                        // start a drag.
                                                        onClicked: mouse => {
                                                            if (idWindowInput.dragging)
                                                                return;
                                                            if (idWindowInput.pressButton === Qt.MiddleButton)
                                                                WorkspaceService.closeWindow(idWindow.modelData.address);
                                                            else if (idWindowInput.pressButton === Qt.RightButton)
                                                                root.openMenuFor(idWindow.modelData, idTile.modelData.id,
                                                                    idWindowInput.mapToItem(root, mouse.x, mouse.y));
                                                            else
                                                                WorkspaceService.switchTo(idTile.modelData.id);
                                                        }
                                                        onCanceled: {
                                                            if (idWindowInput.dragging)
                                                                root.abortDrag();
                                                            idWindowInput.dragging = false;
                                                            idWindowInput.pressButton = Qt.NoButton;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            id: idTileCaption

                                            width: parent.width
                                            implicitHeight: Math.max(idCaptionLayout.implicitHeight,
                                                idCaptionCompact.implicitHeight)

                                            RowLayout {
                                                id: idCaptionLayout

                                                anchors.fill: parent

                                                visible: !idTile.compact
                                                spacing: Globals.listSpacing

                                                Text {
                                                    id: idCaptionNumber

                                                    Layout.alignment: Qt.AlignVCenter

                                                    textFormat: Text.PlainText
                                                    text: idTile.modelData.id
                                                    color: idTile.current ? Colors.accent : Colors.text

                                                    font {
                                                        family: Globals.uiFontFamily
                                                        pixelSize: Globals.uiCaptionSize
                                                        weight: Font.Medium
                                                    }
                                                }

                                                Text {
                                                    id: idCaptionNames

                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    Layout.alignment: Qt.AlignVCenter

                                                    textFormat: Text.PlainText
                                                    elide: Text.ElideRight
                                                    text: idTile.modelData.caption
                                                    color: Colors.textSubtle

                                                    font {
                                                        family: Globals.uiFontFamily
                                                        pixelSize: Globals.uiCaptionSize
                                                    }
                                                }

                                                Rectangle {
                                                    id: idCaptionUrgent

                                                    Layout.alignment: Qt.AlignVCenter
                                                    Layout.preferredWidth: Globals.appDotSize
                                                    Layout.preferredHeight: Globals.appDotSize

                                                    visible: idTile.modelData.urgent === true
                                                    radius: Globals.appDotSize / 2
                                                    color: Colors.danger
                                                }
                                            }

                                            Text {
                                                id: idCaptionCompact

                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter

                                                visible: idTile.compact
                                                textFormat: Text.PlainText
                                                text: idTile.modelData.id
                                                color: idTile.current ? Colors.accent : Colors.text

                                                font {
                                                    family: Globals.uiFontFamily
                                                    pixelSize: Globals.uiCaptionSize
                                                    weight: Font.Medium
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SmoothWheel {
                id: idWorkspacesSmoothWheel

                flickable: idWorkspacesFlick
            }
        }

        Rectangle {
            id: idWorkspacesStatusRule

            Layout.fillWidth: true
            Layout.preferredHeight: Globals.hairlineHeight

            color: Colors.border
        }

        Text {
            id: idWorkspacesStatus

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            // One caption line fixed, so swapping between the hint and the
            // hovered window never reflows the map above it.
            Layout.preferredHeight: idStatusMetrics.height

            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: root.hoveredLabel !== "" ? root.hoveredLabel
                : qsTr("Click a workspace or a window to switch. Drag a window onto another workspace to move it.")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiCaptionSize
            }
        }
    }

    // The window ghost lives above the rows so no tile clips it; it is an
    // overlay, not part of any layout, so it never reflows a tile.
    Rectangle {
        id: idDragGhost

        x: root.dragGhostX
        y: root.dragGhostY
        width: root.dragGhostWidth
        height: root.dragGhostHeight
        visible: root.dragActive
        z: 1
        radius: Globals.radius
        color: Colors.mixInto(Colors.backgroundSecondary, root.dragGhostColor, Globals.workspaceWindowFillMix)
        border.width: Globals.hairlineHeight
        border.color: Colors.accent
        opacity: 0.85
    }

    ContextMenu {
        id: idWorkspacesContextMenu

        anchors.fill: parent
        items: root.menuItems
        header: root.menuHeader
        // openAt() takes focus and ContextMenu handles arrows, Enter, Escape,
        // and the PanelShell Escape shortcut itself; this tab has no search
        // field, so a typed character just closes the menu.
        onClosed: root.onMenuClosed()
        onTriggered: item => WorkspaceService.runMenuItem(item, root.menuWindow)
    }

    FontMetrics {
        id: idStatusMetrics

        font {
            family: Globals.uiFontFamily
            pixelSize: Globals.uiCaptionSize
        }
    }

    function beginDrag(address, sourceId, width, height, color, point, grabOffset): void {
        root.dragAddress = String(address ?? "");
        root.dragSourceId = sourceId;
        root.dragGhostWidth = width;
        root.dragGhostHeight = height;
        root.dragGhostColor = color;
        root.dragGrabOffset = grabOffset;
        root.dragActive = true;
        root.updateDrag(point);
    }

    function updateDrag(point): void {
        root.dragGhostX = point.x - root.dragGrabOffset.x;
        root.dragGhostY = point.y - root.dragGrabOffset.y;
        const target = WorkspaceService.dropTarget(point, root.collectTileRects());
        // The source workspace is not a drop target: no highlight on a move
        // that would be a no-op.
        root.dropHighlightId = WorkspaceService.moveDecision(root.dragSourceId, target) >= 1 ? target : -1;
    }

    function clearDragState(): void {
        root.dragActive = false;
        root.dropHighlightId = -1;
        root.dragAddress = "";
        root.dragSourceId = -1;
        root.dragGrabOffset = Qt.point(0, 0);
    }

    // A real release: the drop decides, and the move commits only when the
    // decision names another workspace.
    function endDrag(): void {
        const decision = WorkspaceService.moveDecision(root.dragSourceId, root.dropHighlightId);
        const address = root.dragAddress;
        root.clearDragState();
        if (decision >= 1)
            WorkspaceService.moveWindow(address, decision);
    }

    // No release: a cancelled input or a hidden view clears the state and
    // commits nothing.
    function abortDrag(): void {
        root.clearDragState();
    }

    // Every tile map's rect in this view's coordinate space, one shared space
    // for both the pointer and the hit test.
    function collectTileRects(): var {
        const rects = [];
        for (let i = 0; i < idMonitorRepeater.count; i++) {
            const section = idMonitorRepeater.itemAt(i);
            if (!section || !section.tileRepeater)
                continue;
            const tiles = section.tileRepeater;
            for (let k = 0; k < tiles.count; k++) {
                const tile = tiles.itemAt(k);
                if (!tile || !tile.mapItem)
                    continue;
                const corner = tile.mapItem.mapToItem(root, 0, 0);
                rects.push({
                    id: tile.workspaceId,
                    x: corner.x,
                    y: corner.y,
                    width: tile.mapItem.width,
                    height: tile.mapItem.height
                });
            }
        }
        return rects;
    }

    function registerProbe(): void {
        DevGeometry.register("dashboard.workspaces", root);
    }

    // The menu reads the live window at open time and keeps a copy, so the
    // descriptors and the header survive a model rebuild.
    function openMenuFor(record, workspaceId, point): void {
        if (!record)
            return;
        root.menuWindow = root.windowRecord(record, workspaceId);
        root.menuItems = WorkspaceService.windowMenuItems(root.menuWindow);
        root.menuHeader = root.menuHeaderFor(root.menuWindow);
        idWorkspacesContextMenu.boundsHeight = root.menuBoundsHeight();
        idWorkspacesContextMenu.openAt(point.x, point.y);
    }

    function windowRecord(record, workspaceId): var {
        return {
            address: record.address,
            cls: record.cls,
            app: record.app,
            title: record.title,
            icon: record.icon,
            floating: record.floating,
            fullscreen: record.fullscreen,
            workspaceId: workspaceId
        };
    }

    // The name is the app name, or the title when the window reports no class;
    // the detail repeats the title only when the app carried the name, and
    // the tint follows the window rectangle's class source.
    function menuHeaderFor(record): var {
        const cls = record && record.cls ? String(record.cls) : "";
        const app = record && record.app ? String(record.app) : cls;
        const title = record && record.title ? String(record.title) : "";
        const name = app !== "" ? app : title;
        return {
            image: record && record.icon ? String(record.icon) : "",
            letter: name !== "" ? name.charAt(0).toUpperCase() : "?",
            color: Colors.appColor(cls),
            name: name,
            detail: app !== "" ? title : ""
        };
    }

    // The menu may extend past the card toward the window's bottom edge, so a
    // short dashboard still shows the whole menu.
    function menuBoundsHeight(): real {
        if (root.windowRoom <= 0)
            return root.height;
        return Math.max(root.height, root.windowRoom - (root.mapToItem(null, 0, 0).y - root.slideOffset));
    }

    // A middle-click close destroys the hovered delegate without onExited, so
    // the status line also clears when the hovered address leaves the model.
    function clearHoveredWindow(): void {
        root.hoveredLabel = "";
        root.hoveredAddress = "";
    }

    function addressInModel(address): bool {
        const target = String(address ?? "").toLowerCase();
        if (target === "")
            return false;
        const model = WorkspaceService.model;
        for (let i = 0; i < model.length; i++) {
            const tiles = model[i].tiles || [];
            for (let k = 0; k < tiles.length; k++) {
                const windows = tiles[k].windows || [];
                for (let w = 0; w < windows.length; w++) {
                    if (String(windows[w].address ?? "").toLowerCase() === target)
                        return true;
                }
            }
        }
        return false;
    }

    function onMenuClosed(): void {
        Qt.callLater(() => {
            if (idWorkspacesContextMenu.opened)
                return;
            root.menuWindow = null;
            root.menuItems = [];
            root.menuHeader = null;
        });
    }
}
