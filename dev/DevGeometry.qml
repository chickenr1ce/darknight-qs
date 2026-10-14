pragma Singleton

import QtQuick
import Quickshell

QtObject {
    id: root

    property var targets: ({})

    function register(name: string, item: Item): void {
        if (name === "" || item === null)
            return;
        root.targets[name] = item;
    }

    function unregister(name: string): void {
        if (root.targets[name] === undefined)
            return;
        delete root.targets[name];
    }

    function names(): string {
        return JSON.stringify(Object.keys(root.targets));
    }

    function snapshot(name: string): string {
        const item = root.targets[name];
        if (item === null || item === undefined)
            return JSON.stringify({ name: name, found: false });
        return JSON.stringify({
            name: name,
            found: true,
            x: item.x,
            y: item.y,
            width: item.width,
            height: item.height,
            implicitWidth: item.implicitWidth,
            implicitHeight: item.implicitHeight,
            visible: item.visible,
            screenRect: root.screenRect(item)
        });
    }

    // The item's rectangle in compositor layout coordinates, for `grim -g`.
    // Resolved only for a window anchored top and left (every PanelShell),
    // where the window's origin is its screen plus its margins; null otherwise.
    function screenRect(item: Item): var {
        const window = item.QsWindow ? item.QsWindow.window : null;
        if (!window || !window.screen || !window.anchors || !window.anchors.top || !window.anchors.left)
            return null;
        const origin = item.mapToItem(null, 0, 0);
        return {
            x: Math.round(window.screen.x + window.margins.left + origin.x),
            y: Math.round(window.screen.y + window.margins.top + origin.y),
            width: Math.round(item.width),
            height: Math.round(item.height)
        };
    }
}
