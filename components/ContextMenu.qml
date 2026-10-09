pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import qs.components
import qs.config

// Generic in-card context menu. The caller supplies a descriptor list and a
// header and positions the menu with openAt(). The menu fits itself inside the
// host's bounds: it opens at the anchor, shifts up when it would overflow the
// bottom, and caps its height with a scrollable item column when the content is
// taller than the host. Descriptors:
//   { kind: "item"|"separator"|"label", id, text, hint, danger, enabled,
//     image, actionIndex, submenu: [ ...same shape... ] }
// "image" is a resolved icon source; "glyph" is a font glyph. One submenu
// level is rendered to the side, shifted up and flipped left to stay in bounds.
Item {
    id: root

    property bool opened: false
    property var items: []
    property var header: null
    property real anchorX: 0
    property real anchorY: 0
    property int activeLevel: 0
    property int activeIndex: -1
    property int submenuFor: -1
    property real submenuAnchorY: 0

    readonly property real contentWidth: Globals.menuWidth
    readonly property var submenuItems: {
        if (root.submenuFor < 0 || root.submenuFor >= root.items.length)
            return [];
        const item = root.items[root.submenuFor];
        return item && item.submenu ? item.submenu : [];
    }
    readonly property var mainModel: {
        const out = [];
        for (let i = 0; i < root.items.length; i++)
            out.push({ item: root.items[i], index: i, level: 0 });
        return out;
    }
    readonly property var subModel: {
        const out = [];
        for (let i = 0; i < root.submenuItems.length; i++)
            out.push({ item: root.submenuItems[i], index: i, level: 1 });
        return out;
    }
    readonly property real availableHeight: Math.max(0, root.height - 2 * Globals.menuMargin)
    readonly property real menuHeight: Math.min(root.availableHeight,
        idMenuHeader.height + idMenuContent.implicitHeight + 2 * Globals.menuMargin)
    readonly property real submenuHeight: Math.min(root.availableHeight,
        idSubmenuContent.implicitHeight + 2 * Globals.menuMargin)
    readonly property real contentHeight: root.menuHeight
    readonly property real menuX: Math.max(Globals.menuMargin,
        Math.min(root.anchorX, root.width - root.contentWidth - Globals.menuMargin))
    readonly property real menuY: Math.max(Globals.menuMargin,
        Math.min(root.anchorY, root.height - root.menuHeight - Globals.menuMargin))
    readonly property real submenuX: {
        const right = idMenu.x + idMenu.width + Globals.menuSubmenuGap;
        if (right + root.contentWidth + Globals.menuMargin <= root.width)
            return right;
        return Math.max(Globals.menuMargin, idMenu.x - root.contentWidth - Globals.menuSubmenuGap);
    }
    readonly property real submenuY: Math.max(Globals.menuMargin,
        Math.min(root.submenuAnchorY, root.height - root.submenuHeight - Globals.menuMargin))

    signal closed()
    signal triggered(var item)
    signal typedText(string text)

    focus: root.opened

    Keys.onPressed: event => root.handleKey(event)
    Keys.onShortcutOverride: event => {
        if (root.opened && event.key === Qt.Key_Escape)
            event.accepted = true;
    }

    function openAt(x: real, y: real): void {
        root.anchorX = x;
        root.anchorY = y;
        root.submenuFor = -1;
        root.activeLevel = 0;
        root.activeIndex = -1;
        root.opened = true;
        root.forceActiveFocus();
        Qt.callLater(() => {
            if (root.opened)
                root.forceActiveFocus();
        });
    }

    function closeMenu(): void {
        if (!root.opened)
            return;
        root.opened = false;
        root.submenuFor = -1;
        root.activeLevel = 0;
        root.activeIndex = -1;
        root.closed();
    }

    function actionableIndexes(list): var {
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (item && item.kind === "item" && item.enabled !== false)
                out.push(i);
        }
        return out;
    }

    function rowFor(level: int, index: int): var {
        const column = level === 1 ? idSubmenuContent : idMenuContent;
        for (let i = 0; i < column.children.length; i++) {
            const child = column.children[i];
            if (child.itemIndex !== undefined && child.level === level && child.itemIndex === index)
                return child;
        }
        return null;
    }

    function ensureActiveVisible(level: int, index: int): void {
        idMenuSmoothWheel.stop();
        idSubmenuSmoothWheel.stop();
        const row = root.rowFor(level, index);
        if (!row)
            return;
        const flick = level === 1 ? idSubmenuList : idMenuList;
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        if (row.y < flick.contentY)
            flick.contentY = Math.min(Math.max(0, row.y), maxY);
        else if (row.y + row.height > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, row.y + row.height - flick.height), maxY);
    }

    function updateSubmenuAnchor(index: int): void {
        const row = root.rowFor(0, index);
        if (row)
            root.submenuAnchorY = row.mapToItem(root, 0, 0).y;
    }

    function openSubmenuForIndex(index: int): void {
        const item = root.items[index];
        if (!item || !item.submenu || item.submenu.length === 0) {
            root.submenuFor = -1;
            return;
        }
        root.submenuFor = index;
        root.updateSubmenuAnchor(index);
    }

    function setActive(level: int, index: int): void {
        root.activeLevel = level;
        root.activeIndex = index;
    }

    function hoverItem(level: int, index: int): void {
        const list = level === 1 ? root.submenuItems : root.items;
        const item = list[index];
        if (!item || item.kind !== "item" || item.enabled === false)
            return;
        root.setActive(level, index);
        if (level === 0)
            root.openSubmenuForIndex(index);
    }

    function moveActive(delta: int): void {
        const list = root.activeLevel === 1 ? root.submenuItems : root.items;
        const order = root.actionableIndexes(list);
        if (order.length === 0)
            return;
        const current = order.indexOf(root.activeIndex);
        let next;
        if (current === -1)
            next = delta > 0 ? 0 : order.length - 1;
        else
            next = (current + delta + order.length) % order.length;
        const index = order[next];
        if (root.activeLevel === 1) {
            root.activeIndex = index;
            root.updateSubmenuAnchor(root.submenuFor);
        } else {
            root.setActive(0, index);
            root.openSubmenuForIndex(index);
        }
        root.ensureActiveVisible(root.activeLevel, index);
    }

    function enterSubmenu(): void {
        if (root.activeLevel !== 0)
            return;
        const item = root.items[root.activeIndex];
        if (!item || !item.submenu || item.submenu.length === 0)
            return;
        root.submenuFor = root.activeIndex;
        root.updateSubmenuAnchor(root.activeIndex);
        const order = root.actionableIndexes(root.submenuItems);
        const first = order.length > 0 ? order[0] : -1;
        root.setActive(1, first);
        root.ensureActiveVisible(1, first);
    }

    function leaveSubmenu(): void {
        if (root.activeLevel !== 1)
            return;
        root.setActive(0, root.submenuFor);
    }

    function activateIndex(level: int, index: int): void {
        const list = level === 1 ? root.submenuItems : root.items;
        const item = list[index];
        if (!item || item.kind !== "item" || item.enabled === false)
            return;
        if (item.submenu && item.submenu.length > 0) {
            root.setActive(level, index);
            root.enterSubmenu();
            return;
        }
        root.closeMenu();
        root.triggered(item);
    }

    function activateActive(): void {
        if (root.activeIndex < 0)
            return;
        root.activateIndex(root.activeLevel, root.activeIndex);
    }

    function handleKey(event): void {
        if (!root.opened)
            return;
        if (event.key === Qt.Key_Down) {
            root.moveActive(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.moveActive(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (root.activeLevel === 0)
                root.enterSubmenu();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (root.activeLevel === 1)
                root.leaveSubmenu();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateActive();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (root.activeLevel === 1)
                root.leaveSubmenu();
            else
                root.closeMenu();
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            const order = root.actionableIndexes(root.activeLevel === 1 ? root.submenuItems : root.items);
            if (order.length > 0) {
                root.setActive(root.activeLevel, order[0]);
                root.ensureActiveVisible(root.activeLevel, order[0]);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            const order = root.actionableIndexes(root.activeLevel === 1 ? root.submenuItems : root.items);
            if (order.length > 0) {
                const last = order[order.length - 1];
                root.setActive(root.activeLevel, last);
                root.ensureActiveVisible(root.activeLevel, last);
            }
            event.accepted = true;
        } else if (event.text !== "" && event.text >= " "
            && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            root.closeMenu();
            root.typedText(event.text);
            event.accepted = true;
        }
    }

    MouseArea {
        id: idScrim

        anchors.fill: parent
        visible: root.opened
        enabled: root.opened
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: root.closeMenu()
    }

    Rectangle {
        id: idMenu

        x: root.menuX
        y: root.menuY
        width: root.contentWidth
        height: root.menuHeight
        visible: root.opened || idMenu.opacity > 0
        opacity: root.opened ? 1 : 0
        radius: Globals.cardRadius
        color: Colors.background
        border.width: Globals.hairlineHeight
        border.color: Colors.border

        Behavior on opacity {
            enabled: !Globals.reducedMotion

            NumberAnimation {
                duration: Globals.hoverMs
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: idMenuColumn

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Globals.menuMargin
                leftMargin: Globals.menuMargin
                rightMargin: Globals.menuMargin
            }

            spacing: 0

            Item {
                id: idMenuHeader

                width: parent.width
                height: root.header ? Globals.menuHeaderHeight : 0
                visible: root.header !== null

                Rectangle {
                    id: idMenuHeaderRule

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: Globals.hairlineHeight
                    color: Colors.border
                }

                Item {
                    id: idMenuHeaderSlot

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    width: Globals.menuHeaderHeight - 2 * Globals.fieldPadding
                    height: width

                    Image {
                        id: idMenuHeaderImage

                        anchors.fill: parent
                        visible: root.header && root.header.image !== ""
                        source: root.header ? root.header.image : ""
                        sourceSize.width: idMenuHeaderSlot.width
                        sourceSize.height: idMenuHeaderSlot.height
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Rectangle {
                        id: idMenuHeaderTile

                        anchors.fill: parent
                        visible: !root.header || root.header.image === ""
                        radius: Globals.cardRadius
                        color: root.header ? root.header.color : Colors.cardSecondary

                        Text {
                            id: idMenuHeaderLetter

                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: root.header ? root.header.letter : ""
                            color: Colors.tileInk

                            font {
                                family: Globals.uiFontFamily
                                pixelSize: Globals.uiCaptionSize
                                weight: Font.DemiBold
                            }
                        }
                    }
                }

                Column {
                    id: idMenuHeaderText

                    anchors {
                        left: idMenuHeaderSlot.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Globals.rowSpacing
                    }

                    spacing: 0

                    Text {
                        id: idMenuHeaderName

                        width: parent.width
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: root.header ? root.header.name : ""
                        color: Colors.text

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiBodySize
                            weight: Font.DemiBold
                        }
                    }

                    Text {
                        id: idMenuHeaderDetail

                        width: parent.width
                        visible: root.header && root.header.detail !== ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: root.header ? root.header.detail : ""
                        color: Colors.textSubtle

                        font {
                            family: Globals.uiFontFamily
                            pixelSize: Globals.uiCaptionSize
                        }
                    }
                }
            }

            Item {
                id: idMenuListSlot

                width: parent.width
                height: Math.max(0, root.menuHeight - 2 * Globals.menuMargin - idMenuHeader.height)

                Flickable {
                    id: idMenuList

                    anchors.fill: parent

                    contentHeight: idMenuContent.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    Controls.ScrollBar.vertical: ScrollBar { id: idMenuScrollBar }

                    Column {
                        id: idMenuContent

                        width: idMenuList.width

                        Repeater {
                            id: idMenuRepeater

                            model: root.mainModel
                            delegate: idMenuEntry
                        }
                    }
                }

                SmoothWheel {
                    id: idMenuSmoothWheel

                    flickable: idMenuList
                }
            }
        }
    }

    Rectangle {
        id: idSubmenu

        x: root.submenuX
        y: root.submenuY
        width: root.contentWidth
        height: root.submenuHeight
        visible: root.opened && root.submenuItems.length > 0 && idSubmenu.opacity > 0
        opacity: root.submenuItems.length > 0 ? 1 : 0
        radius: Globals.cardRadius
        color: Colors.background
        border.width: Globals.hairlineHeight
        border.color: Colors.border

        Behavior on opacity {
            enabled: !Globals.reducedMotion

            NumberAnimation {
                duration: Globals.hoverMs
                easing.type: Easing.OutCubic
            }
        }

        Flickable {
            id: idSubmenuList

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Globals.menuMargin
                leftMargin: Globals.menuMargin
                rightMargin: Globals.menuMargin
            }

            height: Math.max(0, root.submenuHeight - 2 * Globals.menuMargin)
            contentHeight: idSubmenuContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Controls.ScrollBar.vertical: ScrollBar { id: idSubmenuScrollBar }

            Column {
                id: idSubmenuContent

                width: idSubmenuList.width

                Repeater {
                    id: idSubmenuRepeater

                    model: root.subModel
                    delegate: idMenuEntry
                }
            }
        }

        SmoothWheel {
            id: idSubmenuSmoothWheel

            flickable: idSubmenuList
        }
    }

    Component {
        id: idMenuEntry

        Item {
            id: idEntryRow

            required property var modelData

            readonly property var descriptor: idEntryRow.modelData ? idEntryRow.modelData.item : ({})
            readonly property int itemIndex: idEntryRow.modelData ? idEntryRow.modelData.index : -1
            readonly property int level: idEntryRow.modelData ? idEntryRow.modelData.level : 0
            readonly property bool isItem: idEntryRow.descriptor.kind === "item"
            readonly property bool isEnabled: idEntryRow.descriptor.enabled !== false
            readonly property bool hasSubmenu: root.hasSubmenu(idEntryRow.descriptor)
            readonly property bool active: root.activeLevel === idEntryRow.level && root.activeIndex === idEntryRow.itemIndex

            width: idEntryRow.parent ? idEntryRow.parent.width : Globals.menuWidth
            height: idEntryRow.descriptor.kind === "separator" ? Globals.menuSeparatorHeight
                : (idEntryRow.descriptor.kind === "label" ? Globals.menuLabelHeight : Globals.menuItemHeight)
            opacity: idEntryRow.isEnabled ? 1 : 0.4

            Rectangle {
                id: idEntryFill

                anchors.fill: parent
                visible: idEntryRow.isItem
                radius: Globals.pillRadius
                color: Colors.selection
                opacity: idEntryRow.active ? 1 : 0

                Behavior on opacity {
                    enabled: !Globals.reducedMotion

                    NumberAnimation {
                        duration: Globals.hoverMs
                    }
                }
            }

            Icon {
                id: idEntryGlyph

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Globals.pillHPadding
                }

                visible: idEntryRow.isItem && idEntryRow.descriptor.image === "" && idEntryRow.descriptor.glyph !== ""
                width: Globals.menuGlyphWidth
                text: idEntryRow.descriptor.glyph || ""
                size: Globals.uiBodySize
                color: idEntryRow.descriptor.danger ? Colors.danger
                    : (idEntryRow.active ? Colors.accent : Colors.textSubtle)
            }

            Image {
                id: idEntryImage

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: Globals.pillHPadding
                }

                visible: idEntryRow.isItem && idEntryRow.descriptor.image !== ""
                width: Globals.menuGlyphWidth
                height: Globals.menuGlyphWidth
                source: idEntryRow.descriptor.image || ""
                sourceSize.width: Globals.menuGlyphWidth
                sourceSize.height: Globals.menuGlyphWidth
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                id: idEntryLabel

                anchors {
                    left: parent.left
                    right: idEntryTrailing.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: idEntryRow.descriptor.kind === "label"
                        ? Globals.pillHPadding
                        : Globals.pillHPadding + Globals.menuGlyphWidth + Globals.rowSpacing
                    rightMargin: Globals.rowSpacing
                }

                visible: idEntryRow.isItem || idEntryRow.descriptor.kind === "label"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                text: idEntryRow.descriptor.kind === "label" ? (idEntryRow.descriptor.text || "").toUpperCase()
                    : (idEntryRow.descriptor.text || "")
                color: idEntryRow.descriptor.danger ? Colors.danger
                    : (idEntryRow.descriptor.kind === "label" ? Colors.textSubtle : Colors.text)

                font {
                    family: Globals.uiFontFamily
                    pixelSize: idEntryRow.descriptor.kind === "label" ? Globals.uiCaptionSize : Globals.uiBodySize
                    weight: idEntryRow.descriptor.kind === "label" ? Font.Medium : Font.Normal
                    letterSpacing: idEntryRow.descriptor.kind === "label" ? Globals.uiLetterSpacing : 0
                }
            }

            Item {
                id: idEntryTrailing

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: Globals.pillHPadding + Globals.scrollbarWidth
                }

                width: idEntryRow.isItem
                    ? Math.max(idEntryHint.visible ? idEntryHint.implicitWidth : 0,
                        idEntryChevron.visible ? idEntryChevron.implicitWidth : 0)
                    : 0

                Text {
                    id: idEntryHint

                    anchors.verticalCenter: parent.verticalCenter
                    visible: idEntryRow.isItem && !idEntryRow.hasSubmenu && idEntryRow.descriptor.hint !== ""
                    textFormat: Text.PlainText
                    text: idEntryRow.descriptor.hint || ""
                    color: Colors.textSubtle

                    font {
                        family: Globals.fontFamily
                        pixelSize: Globals.uiCaptionSize
                    }
                }

                Icon {
                    id: idEntryChevron

                    anchors.verticalCenter: parent.verticalCenter
                    visible: idEntryRow.isItem && idEntryRow.hasSubmenu
                    text: Icons.chevronRight
                    size: Globals.uiCaptionSize
                    color: Colors.textSubtle
                }
            }

            Rectangle {
                id: idEntrySeparator

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Globals.cardPadding
                    rightMargin: Globals.cardPadding
                }

                visible: idEntryRow.descriptor.kind === "separator"
                height: Globals.hairlineHeight
                color: Colors.border
            }

            MouseArea {
                id: idEntryMouse

                anchors.fill: parent
                enabled: idEntryRow.isItem && idEntryRow.isEnabled
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: idEntryRow.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: root.hoverItem(idEntryRow.level, idEntryRow.itemIndex)
                onClicked: root.activateIndex(idEntryRow.level, idEntryRow.itemIndex)
            }
        }
    }

    function hasSubmenu(item): bool {
        return !!(item && item.submenu && item.submenu.length > 0);
    }
}
