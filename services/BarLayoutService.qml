pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "BarLayoutLogic.js" as BarLayoutLogic
import "StateParsers.js" as StateParsers

Singleton {
    id: root

    readonly property var defaults: ({
        left: ["clock", "workspaces", "tray"],
        right: ["cava", "media", "audio", "notifications", "power"]
    })

    readonly property var keys: {
        const out = [];
        for (let i = 0; i < BarVisibilityService.modules.length; i++)
            out.push(BarVisibilityService.modules[i].key);
        return out;
    }

    readonly property var order: ({ left: root.left, right: root.right })
    readonly property bool isDefaultOrder: BarLayoutLogic.sameOrder(root.order, root.defaults)

    property var left: root.defaults.left.slice()
    property var right: root.defaults.right.slice()

    property bool dragging: false
    property string draggedKey: ""
    property string dragSection: "left"
    property int dragIndex: 0
    property real pointerX: 0
    property real pointerY: 0
    // True while the user is reordering and for one glide after, so slots
    // animate a reorder but snap on startup, layout load and width changes.
    property bool reorderMotion: false

    readonly property bool wouldCancel: root.dragging && BarLayoutLogic.shouldCancelRelease(root.pointerY, Globals.barHeight, Globals.barTopMargin)
    readonly property var previewOrder: root.dragging && !root.wouldCancel
        ? BarLayoutLogic.move(root.order, root.draggedKey, root.dragSection, root.dragIndex)
        : root.order
    readonly property var previewLeft: root.previewOrder.left
    readonly property var previewRight: root.previewOrder.right

    StateFile {
        id: idLayoutState

        name: "bar-layout"
        createDir: true
        onParsed: text => root.applyLayout(text)
    }

    Timer {
        id: idReorderMotionTimer

        interval: Globals.barReorderMs * 2
        onTriggered: root.reorderMotion = false
    }

    IpcHandler {
        target: "bar"

        function order(): string {
            return JSON.stringify(root.order);
        }

        function move(key: string, section: string, index: int): string {
            if (!BarVisibilityService.hasModule(key))
                return "error: unknown key " + key;
            if (!(section === "left") && !(section === "right"))
                return "error: unknown section " + section;
            root.move(key, section, index);
            return "ok";
        }

        function reset(): void {
            root.reset();
        }
    }

    function parseLayout(jsonText: string): var {
        return StateParsers.parseBarLayout(jsonText, root.keys, root.defaults);
    }

    function applyLayout(jsonText: string): void {
        const parsed = root.parseLayout(jsonText);
        if (BarLayoutLogic.sameOrder(root.order, parsed))
            return;
        root.left = parsed.left;
        root.right = parsed.right;
    }

    function move(key: string, section: string, index: int): bool {
        const next = BarLayoutLogic.move(root.order, key, section, index);
        if (BarLayoutLogic.sameOrder(root.order, next))
            return false;
        root.startReorderMotion();
        root.left = next.left;
        root.right = next.right;
        root.saveLayout();
        return true;
    }

    function reset(): void {
        if (BarLayoutLogic.sameOrder(root.order, root.defaults))
            return;
        root.startReorderMotion();
        root.left = root.defaults.left.slice();
        root.right = root.defaults.right.slice();
        root.saveLayout();
    }

    function sectionOf(key: string): string {
        if (root.left.indexOf(key) >= 0)
            return "left";
        if (root.right.indexOf(key) >= 0)
            return "right";
        return "";
    }

    function saveLayout(): void {
        idLayoutState.saveJson(root.order);
    }

    function beginDrag(key: string, pointerX: real, pointerY: real): void {
        if (!BarVisibilityService.hasModule(key))
            return;
        root.draggedKey = key;
        root.dragSection = root.sectionOf(key);
        root.dragIndex = (root.dragSection === "left" ? root.left : root.right).indexOf(key);
        root.pointerX = pointerX;
        root.pointerY = pointerY;
        idReorderMotionTimer.stop();
        root.reorderMotion = true;
        root.dragging = true;
    }

    function updateDrag(pointerX: real, pointerY: real, geometry: var): void {
        if (!root.dragging || !geometry)
            return;
        root.pointerX = pointerX;
        root.pointerY = pointerY;
        const target = BarLayoutLogic.dropTarget(root.order, geometry.widths, geometry.visible, geometry.spacing, geometry.width, root.draggedKey, pointerX);
        root.dragSection = target.section;
        root.dragIndex = target.index;
    }

    function endDrag(): void {
        if (!root.dragging)
            return;
        if (root.wouldCancel) {
            root.cancelDrag();
            return;
        }
        const key = root.draggedKey;
        const section = root.dragSection;
        const index = root.dragIndex;
        root.resetDrag();
        if (root.move(key, section, index)) {
            Panels.closeAll();
            TrayMenuService.dismiss();
        }
    }

    function cancelDrag(): void {
        if (!root.dragging)
            return;
        root.resetDrag();
    }

    function resetDrag(): void {
        root.dragging = false;
        root.draggedKey = "";
        root.dragSection = "left";
        root.dragIndex = 0;
        root.pointerX = 0;
        root.pointerY = 0;
        root.startReorderMotion();
    }

    function startReorderMotion(): void {
        root.reorderMotion = true;
        idReorderMotionTimer.restart();
    }
}
