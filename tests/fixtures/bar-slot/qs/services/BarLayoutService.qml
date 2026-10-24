pragma Singleton

import QtQuick

// Records what components/BarSlot.qml asks of the reorder service. The real
// service is covered by the node run in scripts/test-bar-layout.sh; here the
// slot's calls are the subject.
QtObject {
    id: root

    property bool dragging: false
    property bool reorderMotion: false
    property string draggedKey: ""
    property real pointerX: 0
    property real pointerY: 0

    property int begins: 0
    property int updates: 0
    property int ends: 0
    property int cancels: 0
    property real lastUpdateX: 0
    property real lastUpdateY: 0

    function beginDrag(key: string, x: real, y: real): void {
        root.dragging = true;
        root.draggedKey = key;
        root.pointerX = x;
        root.pointerY = y;
        root.begins = root.begins + 1;
    }

    function updateDrag(x: real, y: real, geometry: var): void {
        root.pointerX = x;
        root.pointerY = y;
        root.lastUpdateX = x;
        root.lastUpdateY = y;
        root.updates = root.updates + 1;
    }

    function endDrag(): void {
        root.dragging = false;
        root.ends = root.ends + 1;
    }

    function cancelDrag(): void {
        root.dragging = false;
        root.cancels = root.cancels + 1;
    }

    function reset(): void {
        root.dragging = false;
        root.reorderMotion = false;
        root.draggedKey = "";
        root.pointerX = 0;
        root.pointerY = 0;
        root.begins = 0;
        root.updates = 0;
        root.ends = 0;
        root.cancels = 0;
        root.lastUpdateX = 0;
        root.lastUpdateY = 0;
    }
}
