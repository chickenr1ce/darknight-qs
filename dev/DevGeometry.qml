pragma Singleton

import QtQuick

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
            visible: item.visible
        });
    }
}
