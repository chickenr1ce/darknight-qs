pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.components
import qs.config
import qs.dev
import qs.services

Item {
    id: root

    property string query: ""
    property var menuRow: null
    property bool menuPinned: false

    readonly property var listRows: {
        const rows = [];
        const sections = AppService.sections(root.query);
        let appIndex = 0;
        let rowIndex = 0;
        for (let s = 0; s < sections.length; s++) {
            const section = sections[s];
            if (section.key !== "results") {
                if (section.items.length === 0)
                    continue;
                rows.push({ kind: "header", key: section.key, count: section.count, rowIndex: rowIndex, appIndex: -1 });
                rowIndex++;
            }
            for (let i = 0; i < section.items.length; i++) {
                rows.push({ kind: "app", entry: section.items[i], rowIndex: rowIndex, appIndex: appIndex });
                rowIndex++;
                appIndex++;
            }
        }
        if (appIndex === 0 && root.query.trim() !== "")
            rows.push({ kind: "run", query: root.query.trim(), rowIndex: rowIndex, appIndex: 0 });
        return rows;
    }

    readonly property int appCount: {
        let count = 0;
        for (let i = 0; i < root.listRows.length; i++) {
            if (root.listRows[i].kind !== "header")
                count++;
        }
        return count;
    }

    readonly property var menuItems: {
        const out = [];
        const row = root.menuRow;
        if (!row)
            return out;
        const source = AppService.menuItems(row.entry, root.menuPinned, row.kind === "run",
            row.entry ? AppService.runningCount(row.entry) : 0);
        for (let i = 0; i < source.length; i++) {
            const item = source[i];
            if (item.kind === "item") {
                item.glyph = root.menuGlyph(item.id);
                if (item.image !== "")
                    item.image = AppService.iconForName(item.image);
                for (let j = 0; j < item.submenu.length; j++)
                    item.submenu[j].glyph = root.submenuGlyph(item.submenu[j]);
            }
            out.push(item);
        }
        return out;
    }

    readonly property var menuHeader: {
        const row = root.menuRow;
        if (!row || !row.entry)
            return null;
        const entry = row.entry;
        return {
            image: AppService.iconFor(entry),
            letter: entry.name ? entry.name.charAt(0).toUpperCase() : "?",
            color: Colors.appColor(entry.name),
            name: entry.name,
            detail: entry.genericName
        };
    }

    implicitWidth: idAppsLayout.implicitWidth
    implicitHeight: idAppsLayout.implicitHeight

    onVisibleChanged: {
        if (root.visible)
            root.resetSearch();
        else
            idAppsContextMenu.closeMenu();
    }
    Component.onCompleted: {
        DevGeometry.register("dashboard.apps.list", idAppsList);
        if (root.visible)
            root.focusSearch();
    }
    onQueryChanged: {
        idAppsList.selectedIndex = 0;
        root.clampSelection();
    }
    onListRowsChanged: root.clampSelection()

    Connections {
        id: idAppsDashboardWatch

        target: DashboardService

        function onDashboardVisibleChanged(): void {
            if (DashboardService.dashboardVisible)
                root.resetSearch();
        }
    }

    ColumnLayout {
        id: idAppsLayout

        anchors.fill: parent

        spacing: Globals.spacing

        Rectangle {
            id: idAppsSearchField

            Layout.fillWidth: true
            Layout.preferredHeight: idAppsSearch.implicitHeight + 2 * Globals.fieldPadding

            radius: Globals.pillRadius
            color: Colors.cardSecondary
            border.width: Globals.hairlineHeight
            border.color: idAppsSearch.activeFocus ? Colors.accent : Colors.border

            TextInput {
                id: idAppsSearch

                anchors.fill: parent
                anchors.margins: Globals.fieldPadding

                clip: true
                color: Colors.text
                selectByMouse: true

                font {
                    family: Globals.uiFontFamily
                    pixelSize: Globals.uiBodySize
                }

                onTextChanged: root.query = text
                Keys.onPressed: event => root.handleKey(event)
                Keys.onShortcutOverride: event => {
                    if (event.key === Qt.Key_Escape && root.query !== "")
                        event.accepted = true;
                }

                Text {
                    id: idAppsSearchPlaceholder

                    anchors.fill: parent

                    verticalAlignment: Text.AlignVCenter
                    visible: idAppsSearch.text === "" && !idAppsSearch.activeFocus

                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: qsTr("Search apps…")
                    color: Colors.textSubtle

                    font {
                        family: Globals.uiFontFamily
                        pixelSize: Globals.uiBodySize
                    }
                }
            }
        }

        Item {
            id: idAppsListSlot

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: idAppsList.contentHeight

            ListView {
                id: idAppsList

                property int selectedIndex: 0

                anchors.fill: parent

                model: root.listRows
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: ScrollBar { id: idAppsScrollBar }

                delegate: Item {
                    id: idAppRow

                    required property int index
                    required property var modelData

                    readonly property var info: idAppRow.modelData || ({})
                    readonly property bool isHeader: idAppRow.info.kind === "header"
                    readonly property bool isRun: idAppRow.info.kind === "run"
                    readonly property var entry: idAppRow.info.entry ? idAppRow.info.entry : null
                    readonly property string iconSource: idAppRow.entry ? AppService.iconFor(idAppRow.entry) : ""
                    readonly property bool pinned: idAppRow.entry ? AppService.isPinned(idAppRow.entry.id) : false
                    readonly property bool selected: !idAppRow.isHeader && idAppRow.info.appIndex === idAppsList.selectedIndex
                    readonly property int runningCount: idAppRow.entry ? AppService.runningCount(idAppRow.entry) : 0
                    readonly property bool actionsActive: !idAppRow.isHeader && idAppRow.entry !== null
                        && (idAppRow.selected || idAppRowMouse.containsMouse)

                    property bool killTipShown: false

                    width: idAppsList.width
                    height: idAppRow.isHeader
                        ? idAppRowHeader.implicitHeight + Globals.listSpacing
                        : idAppRowContent.implicitHeight + 2 * Globals.cardPadding

                    Accessible.role: idAppRow.isHeader ? Accessible.StaticText : Accessible.ListItem
                    Accessible.name: idAppRow.isHeader
                        ? idAppRowHeaderTitle.text
                        : (idAppRow.entry ? idAppRow.entry.name : (idAppRow.info.query || ""))

                    RowLayout {
                        id: idAppRowHeader

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding + Globals.scrollbarWidth
                        }

                        visible: idAppRow.isHeader
                        spacing: Globals.listSpacing

                        Text {
                            id: idAppRowHeaderTitle

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter

                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: idAppRow.isHeader ? root.sectionTitle(idAppRow.info.key).toUpperCase() : ""
                            color: Colors.textSubtle

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                                weight: Font.Medium
                                letterSpacing: Globals.uiLetterSpacing
                            }
                        }

                        Text {
                            id: idAppRowHeaderCount

                            Layout.alignment: Qt.AlignVCenter

                            visible: idAppRow.isHeader && idAppRow.info.key === "all"
                            textFormat: Text.PlainText
                            text: idAppRow.info.count || 0
                            color: Colors.textFaint

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                                weight: Font.Medium
                            }
                        }
                    }

                    Rectangle {
                        id: idAppRowWash

                        anchors.fill: parent

                        radius: Globals.cardRadius
                        color: Colors.selection
                        opacity: idAppRow.selected ? 1 : 0

                        Behavior on opacity {
                            enabled: !Globals.reducedMotion

                            NumberAnimation {
                                duration: Globals.hoverMs
                            }
                        }
                    }

                    Rectangle {
                        id: idAppRowRail

                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            topMargin: Globals.cardPadding
                            bottomMargin: Globals.cardPadding
                        }

                        width: Globals.appRailWidth
                        visible: idAppRow.selected

                        radius: Globals.appRailWidth / 2
                        color: Colors.accent
                    }

                    RowLayout {
                        id: idAppRowContent

                        anchors {
                            fill: parent
                            leftMargin: Globals.cardHPadding
                            rightMargin: Globals.cardHPadding + Globals.scrollbarWidth
                            topMargin: Globals.cardPadding
                            bottomMargin: Globals.cardPadding
                        }

                        visible: !idAppRow.isHeader
                        spacing: Globals.rowSpacing

                        AppIcon {
                            id: idAppRowIcon

                            Layout.preferredWidth: Globals.appIconSize
                            Layout.preferredHeight: Globals.appIconSize
                            Layout.alignment: Qt.AlignVCenter

                            source: idAppRow.iconSource
                            name: idAppRow.entry ? idAppRow.entry.name : (idAppRow.info.query || "")
                            glyph: idAppRow.isRun ? Icons.terminal : ""
                            tileColor: idAppRow.isRun ? Colors.cardSecondary : Colors.appColor(idAppRow.entry ? idAppRow.entry.name : "")
                        }

                        ColumnLayout {
                            id: idAppRowText

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0

                            spacing: 0

                            Text {
                                id: idAppRowName

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0

                                textFormat: Text.StyledText
                                elide: Text.ElideRight
                                text: idAppRow.isRun
                                    ? AppService.escapeHtml(qsTr("Run “%1”").arg(idAppRow.info.query))
                                    : (idAppRow.entry ? AppService.markup(idAppRow.entry.name, root.query, Colors.accent) : "")
                                color: Colors.text

                                font {
                                    family: Globals.uiFontFamily
                                    pixelSize: Globals.uiBodySize
                                }
                            }

                            Text {
                                id: idAppRowGeneric

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0

                                visible: idAppRow.isRun || (idAppRow.entry !== null && idAppRow.entry.genericName !== "")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                text: idAppRow.isRun ? qsTr("Run as a shell command") : (idAppRow.entry ? idAppRow.entry.genericName : "")
                                color: Colors.textSubtle

                                font {
                                    family: Globals.uiFontFamily
                                    pixelSize: Globals.uiCaptionSize
                                }
                            }
                        }

                        Item {
                            id: idAppRowTrailing

                            Layout.preferredWidth: idAppRowActions.implicitWidth
                            Layout.preferredHeight: idAppRowActions.implicitHeight
                            Layout.alignment: Qt.AlignVCenter

                            visible: idAppRow.entry !== null

                            RowLayout {
                                id: idAppRowRest

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                spacing: Globals.listSpacing
                                opacity: idAppRow.actionsActive ? 0 : 1

                                Rectangle {
                                    id: idAppRowDot

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: Globals.appDotSize
                                    Layout.preferredHeight: Globals.appDotSize

                                    visible: idAppRow.runningCount > 0
                                    radius: Globals.appDotSize / 2
                                    color: Colors.accent
                                }

                                Text {
                                    id: idAppRowCount

                                    Layout.alignment: Qt.AlignVCenter

                                    visible: idAppRow.runningCount > 0
                                    textFormat: Text.PlainText
                                    text: idAppRow.runningCount
                                    color: Colors.textSubtle

                                    font {
                                        family: Globals.uiFontFamily
                                        pixelSize: Globals.uiCaptionSize
                                        weight: Font.Medium
                                        features: ({ "tnum": 1 })
                                    }
                                }

                                Icon {
                                    id: idAppRowPin

                                    Layout.alignment: Qt.AlignVCenter

                                    visible: idAppRow.pinned
                                    text: Icons.star
                                    size: Globals.uiCaptionSize
                                    color: Colors.accent
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: idAppRowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        RowLayout {
                            id: idAppRowActions

                            anchors {
                                right: parent.right
                                rightMargin: Globals.cardHPadding + Globals.scrollbarWidth
                                verticalCenter: parent.verticalCenter
                            }

                            spacing: Globals.listSpacing
                            opacity: idAppRow.actionsActive ? 1 : 0

                            IconButton {
                                id: idFocusButton

                                Layout.alignment: Qt.AlignVCenter

                                glyph: Icons.focus
                                glyphSize: Globals.uiCaptionSize
                                disabled: !idAppRow.actionsActive || idAppRow.runningCount === 0
                                accessibleName: idAppRow.entry ? qsTr("Focus %1").arg(idAppRow.entry.name) : ""
                                onClicked: AppService.focusWindows(idAppRow.entry)
                            }

                            IconButton {
                                id: idKillButton

                                Layout.alignment: Qt.AlignVCenter

                                glyph: Icons.close
                                glyphSize: Globals.uiCaptionSize
                                disabled: !idAppRow.actionsActive || idAppRow.runningCount === 0
                                hoverColor: Colors.danger
                                accessibleName: idAppRow.entry ? qsTr("Kill %1").arg(idAppRow.entry.name) : ""
                                onClicked: AppService.killWindows(idAppRow.entry)
                            }

                            Rectangle {
                                id: idAppRowActionSeparator

                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: Globals.hairlineHeight
                                Layout.preferredHeight: Globals.appInlineSeparatorHeight

                                color: Colors.border
                            }

                            IconButton {
                                id: idPinButton

                                Layout.alignment: Qt.AlignVCenter

                                glyph: idAppRow.pinned ? Icons.star : Icons.starOutline
                                glyphSize: Globals.uiCaptionSize
                                disabled: !idAppRow.actionsActive
                                restColor: idAppRow.pinned ? Colors.accent : Colors.textSecondary
                                accessibleName: idAppRow.pinned
                                    ? qsTr("Unpin %1").arg(idAppRow.entry ? idAppRow.entry.name : "")
                                    : qsTr("Pin %1").arg(idAppRow.entry ? idAppRow.entry.name : "")
                                onClicked: {
                                    if (idAppRow.entry)
                                        AppService.togglePin(idAppRow.entry.id);
                                }
                            }

                            IconButton {
                                id: idMoreButton

                                Layout.alignment: Qt.AlignVCenter

                                glyph: Icons.more
                                glyphSize: Globals.uiCaptionSize
                                disabled: !idAppRow.actionsActive
                                accessibleName: idAppRow.entry
                                    ? qsTr("More actions for %1").arg(idAppRow.entry.name) : ""
                                onClicked: root.openMenuAt(idAppRow.info,
                                    idMoreButton.mapToItem(root, 0, idMoreButton.height))
                            }
                        }

                        onEntered: {
                            if (!idAppRow.isHeader)
                                idAppsList.selectedIndex = idAppRow.info.appIndex;
                        }
                        onClicked: mouse => {
                            if (idAppRow.isHeader)
                                return;
                            if (idAppRow.actionsActive && mouse.x >= idAppRowActions.x) {
                                if (mouse.button === Qt.RightButton)
                                    root.openMenuAt(idAppRow.info, idAppRowMouse.mapToItem(root, mouse.x, mouse.y));
                                return;
                            }
                            idAppsList.selectedIndex = idAppRow.info.appIndex;
                            if (mouse.button === Qt.RightButton)
                                root.openMenuAt(idAppRow.info, idAppRowMouse.mapToItem(root, mouse.x, mouse.y));
                            else
                                root.activateRow(idAppRow.info, mouse.button === Qt.MiddleButton);
                        }
                    }

                    Timer {
                        id: idKillTooltipTimer

                        running: idKillButton.hovered
                        interval: Globals.tooltipDelayMs
                        onTriggered: idAppRow.killTipShown = true
                        onRunningChanged: {
                            if (!idKillTooltipTimer.running)
                                idAppRow.killTipShown = false;
                        }
                    }

                    Rectangle {
                        id: idKillTooltip

                        readonly property point anchorPoint: idKillButton.mapToItem(idAppRow, 0, 0)

                        x: Math.max(0, Math.min(idAppRow.width - width,
                            idKillTooltip.anchorPoint.x + idKillButton.width / 2 - width / 2))
                        y: Math.max(0, idKillTooltip.anchorPoint.y - height - Globals.listSpacing)
                        width: idKillTooltipText.implicitWidth + 2 * Globals.pillHPadding
                        height: idKillTooltipText.implicitHeight + 2 * Globals.pillVPadding
                        visible: idAppRow.killTipShown && idAppRow.runningCount > 0
                        z: 10
                        radius: Globals.pillRadius
                        color: Colors.panel
                        border.width: Globals.hairlineHeight
                        border.color: Colors.panelBorder

                        Text {
                            id: idKillTooltipText

                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: idAppRow.runningCount === 1
                                ? qsTr("Kill %1 (1 window)").arg(idAppRow.entry ? idAppRow.entry.name : "")
                                : qsTr("Kill %1 (%2 windows)").arg(idAppRow.entry ? idAppRow.entry.name : "").arg(idAppRow.runningCount)
                            color: Colors.text

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                            }
                        }
                    }
                }
            }

            SmoothWheel {
                id: idAppsSmoothWheel

                flickable: idAppsList
            }
        }

        Text {
            id: idAppsEmptyNote

            Layout.fillWidth: true

            visible: root.appCount === 0 && root.query.trim() === ""

            textFormat: Text.PlainText
            text: qsTr("No apps found")
            color: Colors.textSubtle

            font {
                family: Globals.uiFontFamily
                pixelSize: Globals.uiBodySize
            }
        }
    }

    ContextMenu {
        id: idAppsContextMenu

        anchors.fill: parent
        items: root.menuItems
        header: root.menuHeader
        onClosed: root.focusSearch()
        onTriggered: item => root.runMenuItem(item)
        onTypedText: text => root.forwardTypedText(text)
    }

    function sectionTitle(key: string): string {
        if (key === "pinned")
            return qsTr("Pinned");
        if (key === "recent")
            return qsTr("Recent");
        return qsTr("All apps");
    }

    function menuGlyph(id: string): string {
        if (id === "open")
            return Icons.open;
        if (id === "open-keep")
            return Icons.openInApp;
        if (id === "pin")
            return Icons.starOutline;
        if (id === "unpin")
            return Icons.star;
        if (id === "hide")
            return Icons.eyeOff;
        if (id === "copy-command")
            return Icons.copy;
        if (id === "run")
            return Icons.terminal;
        if (id === "focus-window")
            return Icons.focus;
        if (id === "kill")
            return Icons.close;
        if (id === "open-workspace")
            return Icons.workspace;
        return "";
    }

    function submenuGlyph(item): string {
        if (!item)
            return "";
        if (item.id === "workspace-new")
            return Icons.plus;
        if (item.id === "workspace") {
            if (item.current)
                return Icons.circle;
            if (item.occupied)
                return Icons.circleOutline;
        }
        return "";
    }

    function clampSelection(): void {
        if (root.appCount === 0) {
            idAppsList.selectedIndex = 0;
            return;
        }
        idAppsList.selectedIndex = Math.max(0, Math.min(idAppsList.selectedIndex, root.appCount - 1));
    }

    function selectedRow(): var {
        const rows = root.listRows;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind !== "header" && rows[i].appIndex === idAppsList.selectedIndex)
                return rows[i];
        }
        return null;
    }

    function moveSelection(delta: int): void {
        if (root.appCount === 0)
            return;
        const next = Math.max(0, Math.min(idAppsList.selectedIndex + delta, root.appCount - 1));
        idAppsList.selectedIndex = next;
        root.ensureVisible(next);
    }

    function ensureVisible(appIndex: int): void {
        idAppsSmoothWheel.stop();
        const rows = root.listRows;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind !== "header" && rows[i].appIndex === appIndex) {
                idAppsList.positionViewAtIndex(rows[i].rowIndex, ListView.Contain);
                return;
            }
        }
    }

    function activateRow(row, keep: bool): void {
        if (!row)
            return;
        if (row.kind === "run")
            AppService.runQuery(row.query);
        else if (row.entry)
            AppService.launch(row.entry, keep);
    }

    function openMenuAt(row, point): void {
        if (!row)
            return;
        root.menuRow = row;
        root.menuPinned = row.entry ? AppService.isPinned(row.entry.id) : false;
        idAppsContextMenu.openAt(point.x, point.y);
    }

    function openMenuForSelection(): void {
        const row = root.selectedRow();
        if (!row)
            return;
        idAppsSmoothWheel.stop();
        idAppsList.positionViewAtIndex(row.rowIndex, ListView.Contain);
        Qt.callLater(() => {
            const delegate = idAppsList.itemAtIndex(row.rowIndex);
            if (!delegate)
                return;
            root.openMenuAt(row, delegate.mapToItem(root, Globals.cardHPadding, delegate.height));
        });
    }

    function runMenuItem(item): void {
        const row = root.menuRow;
        if (!item || !row)
            return;
        if (item.id === "open")
            AppService.launch(row.entry, false);
        else if (item.id === "open-keep")
            AppService.launchKeep(row.entry);
        else if (item.id === "workspace" || item.id === "workspace-new")
            AppService.launchOnWorkspace(row.entry, item.workspace, false);
        else if (item.id === "pin" || item.id === "unpin")
            AppService.togglePin(row.entry.id);
        else if (item.id === "hide")
            AppService.hide(row.entry.id);
        else if (item.id === "run")
            AppService.runQuery(row.query);
        else if (item.id === "focus-window")
            AppService.focusWindows(row.entry);
        else if (item.id === "kill")
            AppService.killWindows(row.entry);
        else if (item.id === "copy-command") {
            if (row.kind === "run")
                AppService.copyText(row.query);
            else
                AppService.copyCommand(row.entry);
        } else if (item.id.indexOf("action:") === 0)
            AppService.launchAction(row.entry, item.actionIndex);
    }

    function forwardTypedText(text: string): void {
        idAppsSearch.insert(idAppsSearch.length, text);
        idAppsSearch.cursorPosition = idAppsSearch.length;
        root.focusSearch();
    }

    function handleKey(event): void {
        if (event.key === Qt.Key_Up) {
            root.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.moveSelection(-5);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.moveSelection(5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
            root.moveSelection(back ? -1 : 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateRow(root.selectedRow(), (event.modifiers & Qt.AltModifier) !== 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            const row = root.selectedRow();
            if (row && row.entry)
                AppService.togglePin(row.entry.id);
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) !== 0
            && event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            const slot = event.key - Qt.Key_0;
            const row = root.selectedRow();
            if (slot >= 1 && row && row.entry)
                AppService.launchOnWorkspace(row.entry, AppService.workspaceFor(slot), false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Menu
            || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            root.openMenuForSelection();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.query !== "")
                idAppsSearch.clear();
            else
                DashboardService.close();
            event.accepted = true;
        }
    }

    function resetSearch(): void {
        idAppsContextMenu.closeMenu();
        if (idAppsSearch.text !== "")
            idAppsSearch.clear();
        idAppsList.selectedIndex = 0;
        root.focusSearch();
    }

    function focusSearch(): void {
        Qt.callLater(() => idAppsSearch.forceActiveFocus());
    }
}
